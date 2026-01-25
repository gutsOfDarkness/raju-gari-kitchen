// Package usecase implements business logic layer (application services).
// Payment usecase handles Razorpay integration with strict idempotency controls.
package usecase

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/google/uuid"
	razorpay "github.com/razorpay/razorpay-go"

	"fooddelivery/internal/config"
	"fooddelivery/internal/domain"
	"fooddelivery/internal/repository"
	"fooddelivery/pkg/logger"
	"fooddelivery/pkg/redis"
)

// Payment-related errors
var (
	ErrInvalidCart        = errors.New("invalid cart: no items or invalid quantities")
	ErrItemNotAvailable   = errors.New("one or more items are not available")
	ErrPaymentFailed      = errors.New("payment verification failed")
	ErrInvalidSignature   = errors.New("invalid webhook signature")
	ErrOrderAlreadyPaid   = errors.New("order has already been paid")
	ErrDuplicateRequest   = errors.New("duplicate request detected")
)

// PaymentUsecase handles all payment-related business logic
type PaymentUsecase struct {
	orderRepo   *repository.OrderRepository
	menuRepo    *repository.MenuRepository
	razorpay    *razorpay.Client
	redisClient *redis.Client
	config      config.RazorpayConfig
	log         *logger.Logger
}

// NewPaymentUsecase creates a new payment usecase
func NewPaymentUsecase(
	orderRepo *repository.OrderRepository,
	menuRepo *repository.MenuRepository,
	cfg config.RazorpayConfig,
	log *logger.Logger,
) *PaymentUsecase {
	// Initialize Razorpay client
	razorpayClient := razorpay.NewClient(cfg.KeyID, cfg.KeySecret)

	return &PaymentUsecase{
		orderRepo:   orderRepo,
		menuRepo:    menuRepo,
		razorpay:    razorpayClient,
		config:      cfg,
		log:         log,
	}
}

// SetRedisClient sets the Redis client (for dependency injection)
func (u *PaymentUsecase) SetRedisClient(client *redis.Client) {
	u.redisClient = client
}

// InitiateOrderRequest contains the data needed to create an order
type InitiateOrderRequest struct {
	UserID uuid.UUID            `json:"user_id"`
	Items  []domain.CartItem    `json:"items"`
}

// InitiateOrderResponse contains the Razorpay order details for client
type InitiateOrderResponse struct {
	ID              uuid.UUID `json:"id"`
	RazorpayOrderID string    `json:"razorpay_order_id"`
	KeyID           string    `json:"key_id"`
	Amount          int64     `json:"amount"` // Amount in paisa
	Currency        string    `json:"currency"`
	Receipt         string    `json:"receipt"`
	Name            string    `json:"name"`
	Description     string    `json:"description"`
}

// InitiateOrder creates a new order and Razorpay payment order.
// Implements idempotency using cart hash to prevent duplicate orders.
func (u *PaymentUsecase) InitiateOrder(ctx context.Context, req InitiateOrderRequest) (*InitiateOrderResponse, error) {
	log := u.log.WithFields(map[string]interface{}{
		"user_id": req.UserID.String(),
	})

	// Validate cart
	if len(req.Items) == 0 {
		return nil, ErrInvalidCart
	}

	for _, item := range req.Items {
		if item.Quantity <= 0 {
			return nil, ErrInvalidCart
		}
	}

	// Generate cart hash for idempotency check
	// Same cart contents within 1 minute = same order
	cartHash := u.generateCartHash(req.UserID, req.Items)
	idempotencyKey := redis.IdempotencyPrefix + cartHash

	// Check for existing order with same cart (idempotency)
	if u.redisClient != nil {
		var existingResponse InitiateOrderResponse
		found, err := u.redisClient.GetJSON(ctx, idempotencyKey, &existingResponse)
		if err != nil {
			log.Warn("Failed to check idempotency cache", "error", err)
			// Continue without cache - not critical
		} else if found {
			log.Info("Returning cached order (idempotent request)", "razorpay_order_id", existingResponse.RazorpayOrderID)
			return &existingResponse, nil
		}
	}

	// Extract menu item IDs
	menuItemIDs := make([]uuid.UUID, len(req.Items))
	quantityMap := make(map[uuid.UUID]int)
	for i, item := range req.Items {
		menuItemIDs[i] = item.MenuItemID
		quantityMap[item.MenuItemID] = item.Quantity
	}

	// Fetch menu items from database (NEVER trust client prices)
	menuItems, err := u.menuRepo.GetByIDs(ctx, menuItemIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch menu items: %w", err)
	}

	// Validate all items exist and are available
	if len(menuItems) != len(req.Items) {
		return nil, ErrItemNotAvailable
	}

	// Calculate total server-side (critical for security)
	var totalAmount int64
	orderItems := make([]domain.OrderItem, 0, len(menuItems))

	for _, menuItem := range menuItems {
		if !menuItem.IsAvailable {
			return nil, ErrItemNotAvailable
		}

		quantity := quantityMap[menuItem.ID]
		itemTotal := menuItem.Price * int64(quantity)
		totalAmount += itemTotal

		orderItems = append(orderItems, domain.OrderItem{
			MenuItemID: menuItem.ID,
			Name:       menuItem.Name,
			Price:      menuItem.Price,
			Quantity:   quantity,
		})
	}

	// Create order in database with PENDING status
	order := &domain.Order{
		UserID:      req.UserID,
		Status:      domain.OrderStatusPending,
		TotalAmount: totalAmount,
		Items:       orderItems,
	}

	if err := u.orderRepo.Create(ctx, order); err != nil {
		return nil, fmt.Errorf("failed to create order: %w", err)
	}

	log = log.WithFields(map[string]interface{}{
		"order_id": order.ID.String(),
		"amount":   totalAmount,
	})

	// Create Razorpay order
	razorpayData := map[string]interface{}{
		"amount":          totalAmount, // Already in paisa
		"currency":        "INR",
		"receipt":         order.ID.String(),
		"payment_capture": 1, // Auto-capture payment
		"notes": map[string]interface{}{
			"order_id": order.ID.String(),
			"user_id":  req.UserID.String(),
		},
	}

	razorpayOrder, err := u.razorpay.Order.Create(razorpayData, nil)
	if err != nil {
		log.Error("Failed to create Razorpay order", "error", err)
		// Mark order as failed
		_ = u.orderRepo.UpdateStatus(ctx, order.ID, domain.OrderStatusPaymentFailed, order.Version)
		return nil, fmt.Errorf("failed to create payment order: %w", err)
	}

	razorpayOrderID := razorpayOrder["id"].(string)

	// Update order with Razorpay order ID
	if err := u.orderRepo.SetRazorpayOrderID(ctx, order.ID, razorpayOrderID, order.Version); err != nil {
		log.Error("Failed to update order with Razorpay ID", "error", err)
		return nil, fmt.Errorf("failed to update order: %w", err)
	}

	log.Info("Order created successfully", "razorpay_order_id", razorpayOrderID)

	response := &InitiateOrderResponse{
		ID:              order.ID,
		RazorpayOrderID: razorpayOrderID,
		KeyID:           u.config.KeyID,
		Amount:          totalAmount,
		Currency:        "INR",
		Receipt:         order.ID.String(),
		Name:            "Food Delivery",
		Description:     fmt.Sprintf("Order #%s", order.ID.String()[:8]),
	}

	// Cache response for idempotency (1 minute TTL)
	if u.redisClient != nil {
		if err := u.redisClient.SetJSON(ctx, idempotencyKey, response, redis.IdempotencyTTL); err != nil {
			log.Warn("Failed to cache order for idempotency", "error", err)
			// Non-critical, continue
		}
	}

	return response, nil
}

// VerifyPaymentRequest contains the payment verification data from client
type VerifyPaymentRequest struct {
	OrderID           uuid.UUID `json:"order_id"`
	RazorpayOrderID   string    `json:"razorpay_order_id"`
	RazorpayPaymentID string    `json:"razorpay_payment_id"`
	RazorpaySignature string    `json:"razorpay_signature"`
}

// VerifyPaymentResponse contains the verification result
type VerifyPaymentResponse struct {
	Success bool           `json:"success"`
	OrderID uuid.UUID      `json:"order_id"`
	Status  string         `json:"status"`
	Message string         `json:"message"`
}

// VerifyPayment verifies the payment signature and updates order status.
// Called by client after Razorpay checkout success callback.
// This is a secondary verification - webhook is the primary source of truth.
func (u *PaymentUsecase) VerifyPayment(ctx context.Context, req VerifyPaymentRequest) (*VerifyPaymentResponse, error) {
	log := u.log.WithFields(map[string]interface{}{
		"order_id":           req.OrderID.String(),
		"razorpay_order_id":  req.RazorpayOrderID,
		"razorpay_payment_id": req.RazorpayPaymentID,
	})

	// Fetch order
	order, err := u.orderRepo.GetByID(ctx, req.OrderID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, repository.ErrNotFound
		}
		return nil, fmt.Errorf("failed to fetch order: %w", err)
	}

	// Check if already paid (idempotent success)
	if order.Status == domain.OrderStatusPaid || order.Status == domain.OrderStatusAccepted || order.Status == domain.OrderStatusDelivered {
		log.Info("Order already paid, returning success")
		return &VerifyPaymentResponse{
			Success: true,
			OrderID: order.ID,
			Status:  string(order.Status),
			Message: "Payment already verified",
		}, nil
	}

	// Verify Razorpay signature
	// Signature = HMAC_SHA256(razorpay_order_id + "|" + razorpay_payment_id, key_secret)
	data := req.RazorpayOrderID + "|" + req.RazorpayPaymentID
	expectedSignature := u.generateHMAC(data, u.config.KeySecret)

	if !hmac.Equal([]byte(req.RazorpaySignature), []byte(expectedSignature)) {
		log.Warn("Invalid payment signature")
		return &VerifyPaymentResponse{
			Success: false,
			OrderID: order.ID,
			Status:  string(order.Status),
			Message: "Invalid signature",
		}, ErrInvalidSignature
	}

	// Update order status to PAID
	err = u.orderRepo.UpdatePaymentStatus(ctx, order.ID, domain.OrderStatusPaid, req.RazorpayPaymentID, order.Version)
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			// Concurrent update - fetch latest status
			order, _ = u.orderRepo.GetByID(ctx, req.OrderID)
			if order != nil && order.Status == domain.OrderStatusPaid {
				return &VerifyPaymentResponse{
					Success: true,
					OrderID: order.ID,
					Status:  string(order.Status),
					Message: "Payment verified",
				}, nil
			}
		}
		log.Error("Failed to update payment status", "error", err)
		return nil, fmt.Errorf("failed to update payment status: %w", err)
	}

	log.Info("Payment verified successfully")

	return &VerifyPaymentResponse{
		Success: true,
		OrderID: order.ID,
		Status:  string(domain.OrderStatusPaid),
		Message: "Payment verified successfully",
	}, nil
}

// WebhookPayload represents the Razorpay webhook payload structure
type WebhookPayload struct {
	Entity    string          `json:"entity"`
	AccountID string          `json:"account_id"`
	Event     string          `json:"event"`
	Contains  []string        `json:"contains"`
	Payload   json.RawMessage `json:"payload"`
	CreatedAt int64           `json:"created_at"`
}

// PaymentEntity represents the payment data in webhook
type PaymentEntity struct {
	Payment struct {
		Entity struct {
			ID            string `json:"id"`
			Amount        int64  `json:"amount"`
			Currency      string `json:"currency"`
			Status        string `json:"status"`
			OrderID       string `json:"order_id"`
			Method        string `json:"method"`
			Captured      bool   `json:"captured"`
			ErrorCode     string `json:"error_code,omitempty"`
			ErrorDesc     string `json:"error_description,omitempty"`
		} `json:"entity"`
	} `json:"payment"`
}

// HandleWebhook processes Razorpay webhook events.
// This is the PRIMARY source of truth for payment status.
// Always logs the attempt for audit trails.
func (u *PaymentUsecase) HandleWebhook(ctx context.Context, payload []byte, signature string) error {
	log := u.log.WithFields(map[string]interface{}{
		"source": "razorpay_webhook",
	})

	// Verify webhook signature using HMAC SHA256
	// This prevents attackers from sending fake webhook events
	expectedSignature := u.generateHMAC(string(payload), u.config.WebhookSecret)
	signatureValid := hmac.Equal([]byte(signature), []byte(expectedSignature))

	// Parse webhook payload
	var webhookData WebhookPayload
	if err := json.Unmarshal(payload, &webhookData); err != nil {
		log.Error("Failed to parse webhook payload", "error", err)
		// Still log the attempt
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", "parse_error", payload, signatureValid, nil, err.Error())
		return fmt.Errorf("invalid webhook payload: %w", err)
	}

	log = log.WithFields(map[string]interface{}{
		"event":      webhookData.Event,
		"account_id": webhookData.AccountID,
	})

	// Log all webhook attempts (success or failure) for audit
	defer func() {
		// This runs after processing, capturing the final state
	}()

	if !signatureValid {
		log.Warn("Invalid webhook signature")
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, false, nil, "invalid signature")
		return ErrInvalidSignature
	}

	log.Info("Processing webhook event")

	// Handle different event types
	switch webhookData.Event {
	case "payment.captured":
		return u.handlePaymentCaptured(ctx, webhookData, payload, log)
	case "payment.failed":
		return u.handlePaymentFailed(ctx, webhookData, payload, log)
	default:
		log.Info("Unhandled webhook event type")
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, "")
		return nil
	}
}

// handlePaymentCaptured processes successful payment webhooks
func (u *PaymentUsecase) handlePaymentCaptured(ctx context.Context, webhookData WebhookPayload, payload []byte, log *logger.Logger) error {
	var paymentData PaymentEntity
	if err := json.Unmarshal(webhookData.Payload, &paymentData); err != nil {
		log.Error("Failed to parse payment entity", "error", err)
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, err.Error())
		return fmt.Errorf("invalid payment entity: %w", err)
	}

	payment := paymentData.Payment.Entity
	log = log.WithFields(map[string]interface{}{
		"payment_id":        payment.ID,
		"razorpay_order_id": payment.OrderID,
		"amount":            payment.Amount,
	})

	// Find order by Razorpay order ID
	order, err := u.orderRepo.GetByRazorpayOrderID(ctx, payment.OrderID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			log.Warn("Order not found for webhook")
			_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, "order not found")
			return nil // Don't return error - might be from different system
		}
		log.Error("Failed to find order", "error", err)
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, err.Error())
		return err
	}

	log = log.WithFields(map[string]interface{}{
		"order_id": order.ID.String(),
	})

	// Update order status using serializable transaction
	err = u.orderRepo.UpdatePaymentStatus(ctx, order.ID, domain.OrderStatusPaid, payment.ID, order.Version)
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			// Already processed by another request (client verification)
			log.Info("Order already processed (version conflict - idempotent)")
			_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, &order.ID, "")
			return nil
		}
		log.Error("Failed to update order status", "error", err)
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, &order.ID, err.Error())
		return err
	}

	log.Info("Payment captured successfully via webhook")
	_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, &order.ID, "")

	return nil
}

// handlePaymentFailed processes failed payment webhooks
func (u *PaymentUsecase) handlePaymentFailed(ctx context.Context, webhookData WebhookPayload, payload []byte, log *logger.Logger) error {
	var paymentData PaymentEntity
	if err := json.Unmarshal(webhookData.Payload, &paymentData); err != nil {
		log.Error("Failed to parse payment entity", "error", err)
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, err.Error())
		return nil // Don't fail on parse errors for failed payments
	}

	payment := paymentData.Payment.Entity
	log = log.WithFields(map[string]interface{}{
		"payment_id":        payment.ID,
		"razorpay_order_id": payment.OrderID,
		"error_code":        payment.ErrorCode,
		"error_desc":        payment.ErrorDesc,
	})

	// Find order
	order, err := u.orderRepo.GetByRazorpayOrderID(ctx, payment.OrderID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			log.Warn("Order not found for failed payment webhook")
			_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, nil, "order not found")
			return nil
		}
		return err
	}

	// Update order status to PAYMENT_FAILED
	err = u.orderRepo.UpdateStatus(ctx, order.ID, domain.OrderStatusPaymentFailed, order.Version)
	if err != nil && !errors.Is(err, repository.ErrVersionConflict) {
		log.Error("Failed to update order status to failed", "error", err)
		_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, &order.ID, err.Error())
		return err
	}

	log.Info("Payment failure recorded")
	_ = u.orderRepo.LogWebhook(ctx, "razorpay", webhookData.Event, payload, true, &order.ID, "")

	return nil
}

// generateCartHash creates a deterministic hash for cart contents
// Used for idempotency detection
func (u *PaymentUsecase) generateCartHash(userID uuid.UUID, items []domain.CartItem) string {
	// Sort items by ID for deterministic ordering
	sortedItems := make([]domain.CartItem, len(items))
	copy(sortedItems, items)
	sort.Slice(sortedItems, func(i, j int) bool {
		return sortedItems[i].MenuItemID.String() < sortedItems[j].MenuItemID.String()
	})

	// Build hash input
	var sb strings.Builder
	sb.WriteString(userID.String())
	for _, item := range sortedItems {
		sb.WriteString(fmt.Sprintf(":%s:%d", item.MenuItemID.String(), item.Quantity))
	}

	// Generate SHA256 hash
	hash := sha256.Sum256([]byte(sb.String()))
	return hex.EncodeToString(hash[:])
}

// generateHMAC creates HMAC SHA256 signature
func (u *PaymentUsecase) generateHMAC(data, secret string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(data))
	return hex.EncodeToString(h.Sum(nil))
}

// Package handlers implements the HTTP delivery layer (controllers).
// Handles request parsing, validation, and response formatting.
package handlers

import (
	"errors"
	"io"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"fooddelivery/internal/domain"
	"fooddelivery/internal/repository"
	"fooddelivery/internal/usecase"
	"fooddelivery/pkg/logger"
)

// Handlers aggregates all HTTP handlers
type Handlers struct {
	menuUsecase    *usecase.MenuUsecase
	orderUsecase   *usecase.OrderUsecase
	paymentUsecase *usecase.PaymentUsecase
	userUsecase    *usecase.UserUsecase
	log            *logger.Logger
}

// NewHandlers creates a new handlers instance
func NewHandlers(
	menuUsecase *usecase.MenuUsecase,
	orderUsecase *usecase.OrderUsecase,
	paymentUsecase *usecase.PaymentUsecase,
	userUsecase *usecase.UserUsecase,
	log *logger.Logger,
) *Handlers {
	return &Handlers{
		menuUsecase:    menuUsecase,
		orderUsecase:   orderUsecase,
		paymentUsecase: paymentUsecase,
		userUsecase:    userUsecase,
		log:            log,
	}
}

// ContextKeyUserID is the key for storing user ID in Fiber context
const ContextKeyUserID = "user_id"
const ContextKeyIsAdmin = "is_admin"

// Response helpers
type ErrorResponse struct {
	Error     string `json:"error"`
	RequestID string `json:"request_id,omitempty"`
}

type SuccessResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
}

// CustomErrorHandler returns a custom error handler for Fiber
func CustomErrorHandler(log *logger.Logger) fiber.ErrorHandler {
	return func(c *fiber.Ctx, err error) error {
		code := fiber.StatusInternalServerError
		message := "Internal Server Error"

		var e *fiber.Error
		if errors.As(err, &e) {
			code = e.Code
			message = e.Message
		}

		requestID := logger.GetRequestID(c)

		if code >= 500 {
			log.Error("Request error", "status", code, "error", err.Error(), "request_id", requestID)
		}

		return c.Status(code).JSON(ErrorResponse{
			Error:     message,
			RequestID: requestID,
		})
	}
}

// HealthCheck handles GET /health
func (h *Handlers) HealthCheck(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
	})
}

// AuthMiddleware validates JWT token and extracts user info
func (h *Handlers) AuthMiddleware(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "Missing authorization header")
	}

	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return fiber.NewError(fiber.StatusUnauthorized, "Invalid authorization header format")
	}

	token := parts[1]
	claims, err := h.userUsecase.ValidateToken(token)
	if err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "Invalid or expired token")
	}

	c.Locals(ContextKeyUserID, claims.UserID)
	c.Locals(ContextKeyIsAdmin, claims.IsAdmin)

	return c.Next()
}

// AdminMiddleware checks if user is admin
func (h *Handlers) AdminMiddleware(c *fiber.Ctx) error {
	isAdmin, ok := c.Locals(ContextKeyIsAdmin).(bool)
	if !ok || !isAdmin {
		return fiber.NewError(fiber.StatusForbidden, "Admin access required")
	}
	return c.Next()
}

// getUserID extracts user ID from context
func getUserID(c *fiber.Ctx) (uuid.UUID, error) {
	userID, ok := c.Locals(ContextKeyUserID).(uuid.UUID)
	if !ok {
		return uuid.Nil, fiber.NewError(fiber.StatusUnauthorized, "User not authenticated")
	}
	return userID, nil
}

// Register handles POST /auth/register (email/password)
func (h *Handlers) Register(c *fiber.Ctx) error {
	var req usecase.RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	// Validate required fields
	if req.Email == "" || req.Password == "" || req.Name == "" || req.PhoneNumber == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Email, password, name, and phone number are required")
	}

	resp, err := h.userUsecase.Register(c.Context(), req)
	if err != nil {
		if errors.Is(err, usecase.ErrUserExists) {
			return fiber.NewError(fiber.StatusConflict, "User already exists")
		}
		if errors.Is(err, usecase.ErrWeakPassword) {
			return fiber.NewError(fiber.StatusBadRequest, "Password must be at least 8 characters")
		}
		h.log.Error("Registration failed", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Registration failed")
	}

	return c.Status(fiber.StatusCreated).JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// EmailLogin handles POST /auth/login/email (email/password login)
func (h *Handlers) EmailLogin(c *fiber.Ctx) error {
	var req usecase.EmailLoginRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.Email == "" || req.Password == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Email and password are required")
	}

	resp, err := h.userUsecase.EmailLogin(c.Context(), req)
	if err != nil {
		if errors.Is(err, usecase.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "User not found")
		}
		if errors.Is(err, usecase.ErrInvalidPassword) {
			return fiber.NewError(fiber.StatusUnauthorized, "Invalid password")
		}
		h.log.Error("Login failed", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Login failed")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// SendOTP handles POST /auth/login/phone (phone-based OTP login)
func (h *Handlers) SendOTP(c *fiber.Ctx) error {
	var req usecase.PhoneLoginRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.PhoneNumber == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Phone number is required")
	}

	resp, err := h.userUsecase.SendOTP(c.Context(), req)
	if err != nil {
		if errors.Is(err, usecase.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "User not found")
		}
		h.log.Error("Send OTP failed", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to send OTP")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// VerifyOTP handles POST /auth/verify-otp
func (h *Handlers) VerifyOTP(c *fiber.Ctx) error {
	var req usecase.VerifyOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.PhoneNumber == "" || req.OTP == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Phone number and OTP are required")
	}

	resp, err := h.userUsecase.VerifyOTP(c.Context(), req)
	if err != nil {
		if errors.Is(err, usecase.ErrInvalidOTP) {
			return fiber.NewError(fiber.StatusUnauthorized, "Invalid or expired OTP")
		}
		if errors.Is(err, usecase.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "User not found")
		}
		h.log.Error("OTP verification failed", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Verification failed")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// GetMenu handles GET /menu
func (h *Handlers) GetMenu(c *fiber.Ctx) error {
	h.log.Info("GetMenu request received", "request_id", logger.GetRequestID(c))
	menu, err := h.menuUsecase.GetMenu(c.Context())
	if err != nil {
		h.log.Error("Failed to fetch menu", "error", err, "request_id", logger.GetRequestID(c))
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch menu")
	}
	h.log.Info("Menu fetched successfully", "count", len(menu.Items), "request_id", logger.GetRequestID(c))

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    menu,
	})
}

// GetMenuItem handles GET /menu/:id
func (h *Handlers) GetMenuItem(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid menu item ID")
	}

	item, err := h.menuUsecase.GetMenuItem(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Menu item not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch menu item")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    item,
	})
}

// CreateMenuItem handles POST /admin/menu
func (h *Handlers) CreateMenuItem(c *fiber.Ctx) error {
	var item domain.MenuItem
	if err := c.BodyParser(&item); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if item.Name == "" || item.Price <= 0 || item.Category == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Name, price, and category are required")
	}

	item.CreatedAt = time.Now()
	item.UpdatedAt = time.Now()
	item.IsAvailable = true

	if err := h.menuUsecase.CreateMenuItem(c.Context(), &item); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to create menu item")
	}

	return c.Status(fiber.StatusCreated).JSON(SuccessResponse{
		Success: true,
		Data:    item,
	})
}

// UpdateMenuItem handles PUT /admin/menu/:id
func (h *Handlers) UpdateMenuItem(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid menu item ID")
	}

	var item domain.MenuItem
	if err := c.BodyParser(&item); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	item.ID = id
	item.UpdatedAt = time.Now()

	if err := h.menuUsecase.UpdateMenuItem(c.Context(), &item); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Menu item not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to update menu item")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    item,
	})
}

// DeleteMenuItem handles DELETE /admin/menu/:id
func (h *Handlers) DeleteMenuItem(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid menu item ID")
	}

	if err := h.menuUsecase.DeleteMenuItem(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Menu item not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to delete menu item")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Message: "Menu item deleted",
	})
}

// InvalidateMenuCache handles POST /admin/menu/invalidate-cache
func (h *Handlers) InvalidateMenuCache(c *fiber.Ctx) error {
	if err := h.menuUsecase.InvalidateMenuCache(c.Context()); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to invalidate cache")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Message: "Menu cache invalidated",
	})
}

// CreateOrderRequest for order creation
type CreateOrderRequest struct {
	Items []domain.CartItem `json:"items"`
}

// CreateOrder handles POST /orders/create
func (h *Handlers) CreateOrder(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req CreateOrderRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if len(req.Items) == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "Cart is empty")
	}

	paymentReq := usecase.InitiateOrderRequest{
		UserID: userID,
		Items:  req.Items,
	}

	resp, err := h.paymentUsecase.InitiateOrder(c.Context(), paymentReq)
	if err != nil {
		if errors.Is(err, usecase.ErrInvalidCart) {
			return fiber.NewError(fiber.StatusBadRequest, "Invalid cart")
		}
		if errors.Is(err, usecase.ErrItemNotAvailable) {
			return fiber.NewError(fiber.StatusBadRequest, "One or more items are not available")
		}
		h.log.Error("Failed to create order", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to create order")
	}

	return c.Status(fiber.StatusCreated).JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// GetUserOrders handles GET /orders
func (h *Handlers) GetUserOrders(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	orders, err := h.orderUsecase.GetUserOrders(c.Context(), userID)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch orders")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    orders,
	})
}

// GetOrder handles GET /orders/:id
func (h *Handlers) GetOrder(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	orderID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid order ID")
	}

	order, err := h.orderUsecase.GetOrder(c.Context(), orderID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Order not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch order")
	}

	// Ensure user owns the order (unless admin)
	isAdmin, _ := c.Locals(ContextKeyIsAdmin).(bool)
	if order.UserID != userID && !isAdmin {
		return fiber.NewError(fiber.StatusForbidden, "Access denied")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    order,
	})
}

// VerifyPayment handles POST /orders/verify
func (h *Handlers) VerifyPayment(c *fiber.Ctx) error {
	var req usecase.VerifyPaymentRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	resp, err := h.paymentUsecase.VerifyPayment(c.Context(), req)
	if err != nil {
		if errors.Is(err, usecase.ErrInvalidSignature) {
			return fiber.NewError(fiber.StatusBadRequest, "Invalid payment signature")
		}
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Order not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Payment verification failed")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    resp,
	})
}

// GetAllOrders handles GET /admin/orders
func (h *Handlers) GetAllOrders(c *fiber.Ctx) error {
	limit := c.QueryInt("limit", 50)
	offset := c.QueryInt("offset", 0)

	orders, err := h.orderUsecase.GetAllOrders(c.Context(), limit, offset)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch orders")
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Data:    orders,
	})
}

// UpdateOrderStatusRequest for admin order status update
type UpdateOrderStatusRequest struct {
	Status string `json:"status"`
}

// UpdateOrderStatus handles PUT /admin/orders/:id/status
func (h *Handlers) UpdateOrderStatus(c *fiber.Ctx) error {
	orderID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid order ID")
	}

	var req UpdateOrderStatusRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	status := domain.OrderStatus(req.Status)
	if err := h.orderUsecase.UpdateOrderStatus(c.Context(), orderID, status); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "Order not found")
		}
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	}

	return c.JSON(SuccessResponse{
		Success: true,
		Message: "Order status updated",
	})
}

// RazorpayWebhook handles POST /webhooks/razorpay
func (h *Handlers) RazorpayWebhook(c *fiber.Ctx) error {
	signature := c.Get("X-Razorpay-Signature")
	if signature == "" {
		h.log.Warn("Webhook received without signature")
		return fiber.NewError(fiber.StatusBadRequest, "Missing signature")
	}

	body, err := io.ReadAll(c.Request().BodyStream())
	if err != nil {
		h.log.Error("Failed to read webhook body", "error", err)
		return fiber.NewError(fiber.StatusBadRequest, "Failed to read body")
	}

	if err := h.paymentUsecase.HandleWebhook(c.Context(), body, signature); err != nil {
		if errors.Is(err, usecase.ErrInvalidSignature) {
			return fiber.NewError(fiber.StatusUnauthorized, "Invalid signature")
		}
		h.log.Error("Webhook processing failed", "error", err)
		return fiber.NewError(fiber.StatusInternalServerError, "Webhook processing failed")
	}

	return c.JSON(fiber.Map{"status": "ok"})
}
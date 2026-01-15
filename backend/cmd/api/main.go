// Package main is the entry point for the Food Delivery API server.
// Architecture: Modular Monolith following Clean Architecture principles.
// Layers: Handlers (Delivery) -> Usecases -> Repositories
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"fooddelivery/internal/config"
	"fooddelivery/internal/handlers"
	"fooddelivery/internal/repository"
	"fooddelivery/internal/usecase"
	"fooddelivery/pkg/database"
	"fooddelivery/pkg/logger"
	"fooddelivery/pkg/redis"
)

func main() {
	// Initialize structured logger first - all subsequent logs will be JSON formatted
	log := logger.NewLogger()
	defer log.Sync() // Flush any buffered log entries on shutdown

	log.Info("Starting Food Delivery API Server...")

	// Load configuration from environment variables
	cfg, err := config.Load()
	if err != nil {
		log.Fatal("Failed to load configuration", "error", err)
	}

	// Initialize PostgreSQL connection pool with auto-reconnect
	// Using singleton pattern to ensure single connection pool across the app
	dbPool, err := database.NewPostgresPool(context.Background(), cfg.DatabaseURL, log)
	if err != nil {
		log.Fatal("Failed to connect to PostgreSQL", "error", err)
	}
	defer dbPool.Close()

	// Initialize Redis client for caching and session management
	redisClient, err := redis.NewClient(cfg.RedisURL, log)
	if err != nil {
		log.Fatal("Failed to connect to Redis", "error", err)
	}
	defer redisClient.Close()

	// Initialize repositories (Data Access Layer)
	userRepo := repository.NewUserRepository(dbPool)
	menuRepo := repository.NewMenuRepository(dbPool)
	orderRepo := repository.NewOrderRepository(dbPool)

	// Initialize usecases (Business Logic Layer)
	menuUsecase := usecase.NewMenuUsecase(menuRepo, redisClient, log)
	paymentUsecase := usecase.NewPaymentUsecase(orderRepo, menuRepo, cfg.Razorpay, log)
	orderUsecase := usecase.NewOrderUsecase(orderRepo, paymentUsecase, log)
	userUsecase := usecase.NewUserUsecase(userRepo, log)

	// Initialize Fiber with optimized settings for low-latency
	app := fiber.New(fiber.Config{
		// Prefork enables multiple Go processes to handle requests
		// Disabled for easier debugging; enable in production for max throughput
		Prefork: false,

		// Strict routing distinguishes between /foo and /foo/
		StrictRouting: true,

		// Case sensitive routing
		CaseSensitive: true,

		// Read timeout prevents slow client attacks
		ReadTimeout: 10 * time.Second,

		// Write timeout for response
		WriteTimeout: 10 * time.Second,

		// Idle timeout for keep-alive connections
		IdleTimeout: 120 * time.Second,

		// Custom error handler with structured logging
		ErrorHandler: handlers.CustomErrorHandler(log),
	})

	// Global middleware stack
	// Order matters: Recovery -> CORS -> Request Logging -> Routes

	// Recovery middleware catches panics and converts to 500 errors
	// Prevents server crash from unhandled panics
	app.Use(recover.New(recover.Config{
		EnableStackTrace: true,
	}))

	// CORS middleware for Flutter web/mobile clients
	app.Use(cors.New(cors.Config{
		AllowOrigins:     cfg.AllowedOrigins,
		AllowMethods:     "GET,POST,PUT,DELETE,PATCH",
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization,X-Request-ID",
		AllowCredentials: true,
		MaxAge:           3600,
	}))

	// Custom request logging middleware with Request-ID generation
	app.Use(logger.FiberMiddleware(log))

	// Setup routes
	setupRoutes(app, handlers.NewHandlers(
		menuUsecase,
		orderUsecase,
		paymentUsecase,
		userUsecase,
		log,
	))

	// Graceful shutdown handling
	// Captures SIGINT/SIGTERM and cleanly closes connections
	shutdownChan := make(chan os.Signal, 1)
	signal.Notify(shutdownChan, os.Interrupt, syscall.SIGTERM)

	// Start server in goroutine
	go func() {
		addr := fmt.Sprintf(":%d", cfg.Port)
		log.Info("Server listening", "address", addr)
		if err := app.Listen(addr); err != nil {
			log.Fatal("Server failed to start", "error", err)
		}
	}()

	// Wait for shutdown signal
	<-shutdownChan
	log.Info("Shutdown signal received, gracefully stopping server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := app.ShutdownWithContext(ctx); err != nil {
		log.Error("Server forced to shutdown", "error", err)
	}

	log.Info("Server stopped gracefully")
}

// setupRoutes configures all API routes following RESTful conventions
func setupRoutes(app *fiber.App, h *handlers.Handlers) {
	// Health check endpoint for load balancer/k8s probes
	app.Get("/health", h.HealthCheck)

	// API v1 routes
	api := app.Group("/api/v1")

	// Public routes (no auth required)
	api.Post("/auth/register", h.Register)
	api.Post("/auth/login", h.Login)
	api.Post("/auth/verify-otp", h.VerifyOTP)

	// Menu routes (public read, admin write)
	// Register directly on API group without creating a subgroup
	api.Get("/menu", h.GetMenu)
	api.Get("/menu/:id", h.GetMenuItem)

	// Protected routes (require authentication)
	// Using JWT middleware for authentication
	// Use specific paths instead of "/" to avoid catching public routes
	orders := api.Group("/orders", h.AuthMiddleware)
	orders.Post("/create", h.CreateOrder)
	orders.Get("/", h.GetUserOrders)
	orders.Get("/:id", h.GetOrder)
	orders.Post("/verify", h.VerifyPayment)

	// Admin routes (require admin role)
	admin := api.Group("/admin", h.AuthMiddleware, h.AdminMiddleware)
	admin.Post("/menu", h.CreateMenuItem)
	admin.Put("/menu/:id", h.UpdateMenuItem)
	admin.Delete("/menu/:id", h.DeleteMenuItem)
	admin.Post("/menu/invalidate-cache", h.InvalidateMenuCache)
	admin.Get("/orders", h.GetAllOrders)
	admin.Put("/orders/:id/status", h.UpdateOrderStatus)

	// Webhook routes (Razorpay callbacks)
	// These bypass normal auth but use signature verification
	webhooks := app.Group("/webhooks")
	webhooks.Post("/razorpay", h.RazorpayWebhook)
}

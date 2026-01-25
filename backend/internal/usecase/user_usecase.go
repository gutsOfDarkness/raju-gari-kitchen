// Package usecase implements user business logic
package usecase

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"fooddelivery/internal/domain"
	"fooddelivery/internal/repository"
	"fooddelivery/pkg/logger"
)

// User-related errors
var (
	ErrUserExists       = errors.New("user with this email or phone already exists")
	ErrUserNotFound     = errors.New("user not found")
	ErrInvalidOTP       = errors.New("invalid or expired OTP")
	ErrUnauthorized     = errors.New("unauthorized")
	ErrInvalidPassword  = errors.New("invalid password")
	ErrWeakPassword     = errors.New("password must be at least 8 characters")
	ErrInvalidEmail     = errors.New("invalid email address")
)

// UserUsecase handles user-related business logic
type UserUsecase struct {
	userRepo  *repository.UserRepository
	jwtSecret string
	jwtExpiry time.Duration
	log       *logger.Logger
}

// NewUserUsecase creates a new user usecase
func NewUserUsecase(userRepo *repository.UserRepository, log *logger.Logger) *UserUsecase {
	return &UserUsecase{
		userRepo:  userRepo,
		jwtSecret: "", // Set via SetJWTConfig
		jwtExpiry: 24 * time.Hour,
		log:       log,
	}
}

// SetJWTConfig sets JWT configuration
func (u *UserUsecase) SetJWTConfig(secret string, expiryHours int) {
	u.jwtSecret = secret
	u.jwtExpiry = time.Duration(expiryHours) * time.Hour
}

// RegisterRequest contains registration data
type RegisterRequest struct {
	PhoneNumber string `json:"phone_number"`
	Name        string `json:"name"`
	Email       string `json:"email"`
	Password    string `json:"password"`
}

// RegisterResponse contains registration result
type RegisterResponse struct {
	UserID      uuid.UUID `json:"user_id"`
	Token       string    `json:"token"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number"`
	Message     string    `json:"message"`
}

// Register creates a new user account with password
func (u *UserUsecase) Register(ctx context.Context, req RegisterRequest) (*RegisterResponse, error) {
	// ... (validations)
	// (hashing)
	// (user creation)
	
	// I'll need to re-read carefully to not mess up the edit.
}

// Register creates a new user account with password
func (u *UserUsecase) Register(ctx context.Context, req RegisterRequest) (*RegisterResponse, error) {
	// Validate password
	if len(req.Password) < 8 {
		return nil, ErrWeakPassword
	}

	// Check if user with email exists
	existingEmail, err := u.userRepo.GetByEmail(ctx, req.Email)
	if err == nil && existingEmail != nil {
		return nil, ErrUserExists
	}
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, fmt.Errorf("failed to check existing email: %w", err)
	}

	// Check if user with phone exists
	existingPhone, err := u.userRepo.GetByPhoneNumber(ctx, req.PhoneNumber)
	if err == nil && existingPhone != nil {
		return nil, ErrUserExists
	}
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, fmt.Errorf("failed to check existing phone: %w", err)
	}

	// Hash password
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	now := time.Now()
	user := &domain.User{
		PhoneNumber:   req.PhoneNumber,
		Name:          req.Name,
		Email:         req.Email,
		PasswordHash:  string(passwordHash),
		EmailVerified: false,
		IsAdmin:       false,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	if err := u.userRepo.Create(ctx, user); err != nil {
		if errors.Is(err, repository.ErrDuplicateKey) {
			return nil, ErrUserExists
		}
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Generate JWT token
	expiresAt := time.Now().Add(u.jwtExpiry)
	token, err := u.generateJWT(user, expiresAt)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	u.log.Info("User registered", "user_id", user.ID.String(), "email", req.Email)

	return &RegisterResponse{
		UserID:      user.ID,
		Token:       token,
		Name:        user.Name,
		Email:       user.Email,
		PhoneNumber: user.PhoneNumber,
		Message:     "Registration successful",
	}, nil
}

// EmailLoginRequest contains email/password login data
type EmailLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginResponse contains login result with JWT token
type LoginResponse struct {
	Token       string    `json:"token"`
	UserID      uuid.UUID `json:"user_id"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number"`
	ExpiresAt   time.Time `json:"expires_at"`
}

// EmailLogin performs email/password authentication
func (u *UserUsecase) EmailLogin(ctx context.Context, req EmailLoginRequest) (*LoginResponse, error) {
	// ... (implementation)
	
	u.log.Info("User logged in via email", "user_id", user.ID.String())

	return &LoginResponse{
		Token:       token,
		UserID:      user.ID,
		Name:        user.Name,
		Email:       user.Email,
		PhoneNumber: user.PhoneNumber,
		ExpiresAt:   expiresAt,
	}, nil
}


// EmailLogin performs email/password authentication
func (u *UserUsecase) EmailLogin(ctx context.Context, req EmailLoginRequest) (*LoginResponse, error) {
	// Find user by email
	user, err := u.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidPassword
	}

	// Generate JWT token
	expiresAt := time.Now().Add(u.jwtExpiry)
	tokenID := uuid.New().String()
	token, err := u.generateJWTWithID(user, expiresAt, tokenID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	// Create session record
	session := &domain.Session{
		UserID:         user.ID,
		TokenID:        tokenID,
		ExpiresAt:      expiresAt,
		IsRevoked:      false,
		LastActivityAt: time.Now(),
		CreatedAt:      time.Now(),
	}

	if err := u.userRepo.CreateSession(ctx, session); err != nil {
		u.log.Error("Failed to create session", "error", err)
		// Don't fail login if session creation fails
	}

	u.log.Info("User logged in via email", "user_id", user.ID.String())

	return &LoginResponse{
		Token:     token,
		UserID:    user.ID,
		Name:      user.Name,
		Email:     user.Email,
		ExpiresAt: expiresAt,
	}, nil
}

// VerifyOTPRequest contains OTP verification data
type VerifyOTPRequest struct {
	PhoneNumber string `json:"phone_number"`
	OTP         string `json:"otp"`
}

// VerifyOTPResponse contains verification result with JWT token
type VerifyOTPResponse struct {
	Token       string    `json:"token"`
	UserID      uuid.UUID `json:"user_id"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number"`
	ExpiresAt   time.Time `json:"expires_at"`
}

// VerifyOTP verifies OTP and returns JWT token
func (u *UserUsecase) VerifyOTP(ctx context.Context, req VerifyOTPRequest) (*VerifyOTPResponse, error) {
	// ... (implementation)
	
	u.log.Info("User logged in via OTP", "user_id", user.ID.String())

	return &VerifyOTPResponse{
		Token:       token,
		UserID:      user.ID,
		Name:        user.Name,
		Email:       user.Email,
		PhoneNumber: user.PhoneNumber,
		ExpiresAt:   expiresAt,
	}, nil
}


// VerifyOTP verifies OTP and returns JWT token
func (u *UserUsecase) VerifyOTP(ctx context.Context, req VerifyOTPRequest) (*VerifyOTPResponse, error) {
	// Get valid OTP from database
	otp, err := u.userRepo.GetValidOTP(ctx, req.PhoneNumber, domain.OTPPurposeLogin)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrInvalidOTP
		}
		return nil, fmt.Errorf("failed to get OTP: %w", err)
	}

	// Verify OTP code
	if otp.OTPCode != req.OTP {
		// Increment failed attempts
		if err := u.userRepo.IncrementOTPAttempts(ctx, otp.ID); err != nil {
			u.log.Error("Failed to increment OTP attempts", "error", err)
		}
		return nil, ErrInvalidOTP
	}

	// Mark OTP as verified
	if err := u.userRepo.MarkOTPVerified(ctx, otp.ID); err != nil {
		u.log.Error("Failed to mark OTP as verified", "error", err)
	}

	// Get user
	user, err := u.userRepo.GetByPhoneNumber(ctx, req.PhoneNumber)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	// Generate JWT token with session tracking
	expiresAt := time.Now().Add(u.jwtExpiry)
	tokenID := uuid.New().String()
	token, err := u.generateJWTWithID(user, expiresAt, tokenID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	// Create session record
	session := &domain.Session{
		UserID:         user.ID,
		TokenID:        tokenID,
		ExpiresAt:      expiresAt,
		IsRevoked:      false,
		LastActivityAt: time.Now(),
		CreatedAt:      time.Now(),
	}

	if err := u.userRepo.CreateSession(ctx, session); err != nil {
		u.log.Error("Failed to create session", "error", err)
	}

	u.log.Info("User logged in via OTP", "user_id", user.ID.String())

	return &VerifyOTPResponse{
		Token:     token,
		UserID:    user.ID,
		Name:      user.Name,
		Email:     user.Email,
		ExpiresAt: expiresAt,
	}, nil
}

// JWTClaims contains JWT payload
type JWTClaims struct {
	UserID  uuid.UUID `json:"user_id"`
	IsAdmin bool      `json:"is_admin"`
	TokenID string    `json:"jti,omitempty"`
	jwt.RegisteredClaims
}

// generateJWT creates a new JWT token
func (u *UserUsecase) generateJWT(user *domain.User, expiresAt time.Time) (string, error) {
	claims := JWTClaims{
		UserID:  user.ID,
		IsAdmin: user.IsAdmin,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   user.ID.String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(u.jwtSecret))
}

// generateJWTWithID creates a new JWT token with token ID for session tracking
func (u *UserUsecase) generateJWTWithID(user *domain.User, expiresAt time.Time, tokenID string) (string, error) {
	claims := JWTClaims{
		UserID:  user.ID,
		IsAdmin: user.IsAdmin,
		TokenID: tokenID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   user.ID.String(),
			ID:        tokenID,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(u.jwtSecret))
}

// generateOTP generates a 6-digit OTP
func generateOTP() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// PhoneLoginRequest contains phone-based OTP login request
type PhoneLoginRequest struct {
	PhoneNumber string `json:"phone_number"`
}

// SendOTPResponse contains OTP send result
type SendOTPResponse struct {
	Message string `json:"message"`
}

// SendOTP generates and sends OTP to phone number
func (u *UserUsecase) SendOTP(ctx context.Context, req PhoneLoginRequest) (*SendOTPResponse, error) {
	// Check if user exists
	user, err := u.userRepo.GetByPhoneNumber(ctx, req.PhoneNumber)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	// Generate OTP
	otpCode, err := generateOTP()
	if err != nil {
		return nil, fmt.Errorf("failed to generate OTP: %w", err)
	}

	// Store OTP in database
	otp := &domain.OTP{
		UserID:      &user.ID,
		PhoneNumber: &req.PhoneNumber,
		OTPCode:     otpCode,
		Purpose:     domain.OTPPurposeLogin,
		ExpiresAt:   time.Now().Add(10 * time.Minute),
		IsVerified:  false,
		Attempts:    0,
		CreatedAt:   time.Now(),
	}

	if err := u.userRepo.CreateOTP(ctx, otp); err != nil {
		return nil, fmt.Errorf("failed to store OTP: %w", err)
	}

	// In production: Send OTP via SMS service (Twilio, AWS SNS, etc.)
	u.log.Info("OTP generated", "user_id", user.ID.String(), "phone", req.PhoneNumber, "otp", otpCode)

	return &SendOTPResponse{
		Message: "OTP sent to your phone number",
	}, nil
}

// ValidateToken validates JWT token and returns claims
func (u *UserUsecase) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(u.jwtSecret), nil
	})

	if err != nil {
		return nil, ErrUnauthorized
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, ErrUnauthorized
}

// GetUser retrieves user by ID
func (u *UserUsecase) GetUser(ctx context.Context, userID uuid.UUID) (*domain.User, error) {
	user, err := u.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return user, nil
}
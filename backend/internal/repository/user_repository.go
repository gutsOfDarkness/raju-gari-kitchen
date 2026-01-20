// Package repository implements the data access layer using pgx.
// All database operations are encapsulated here, keeping business logic clean.
package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"fooddelivery/internal/domain"
	"fooddelivery/pkg/database"
)

// Common repository errors
var (
	ErrNotFound      = errors.New("record not found")
	ErrDuplicateKey  = errors.New("duplicate key violation")
	ErrVersionConflict = errors.New("version conflict - record was modified")
)

// UserRepository handles user data persistence
type UserRepository struct {
	db *database.Pool
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *database.Pool) *UserRepository {
	return &UserRepository{db: db}
}

// Create inserts a new user into the database
func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	query := `
		INSERT INTO users (id, phone_number, name, email, password_hash, email_verified, is_admin, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	user.ID = uuid.New()
	_, err := r.db.Exec(ctx, query,
		user.ID,
		user.PhoneNumber,
		user.Name,
		user.Email,
		user.PasswordHash,
		user.EmailVerified,
		user.IsAdmin,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		if isDuplicateKeyError(err) {
			return ErrDuplicateKey
		}
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

// GetByID retrieves a user by their UUID
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	query := `
		SELECT id, phone_number, name, email, password_hash, email_verified, is_admin, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	user := &domain.User{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.PhoneNumber,
		&user.Name,
		&user.Email,
		&user.PasswordHash,
		&user.EmailVerified,
		&user.IsAdmin,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

// GetByPhoneNumber retrieves a user by phone number
func (r *UserRepository) GetByPhoneNumber(ctx context.Context, phoneNumber string) (*domain.User, error) {
	query := `
		SELECT id, phone_number, name, email, password_hash, email_verified, is_admin, created_at, updated_at
		FROM users
		WHERE phone_number = $1
	`

	user := &domain.User{}
	err := r.db.QueryRow(ctx, query, phoneNumber).Scan(
		&user.ID,
		&user.PhoneNumber,
		&user.Name,
		&user.Email,
		&user.PasswordHash,
		&user.EmailVerified,
		&user.IsAdmin,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get user by phone: %w", err)
	}

	return user, nil
}

// GetByEmail retrieves a user by email address
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	query := `
		SELECT id, phone_number, name, email, password_hash, email_verified, is_admin, created_at, updated_at
		FROM users
		WHERE email = $1
	`

	user := &domain.User{}
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.PhoneNumber,
		&user.Name,
		&user.Email,
		&user.PasswordHash,
		&user.EmailVerified,
		&user.IsAdmin,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}

	return user, nil
}

// Update modifies an existing user
func (r *UserRepository) Update(ctx context.Context, user *domain.User) error {
	query := `
		UPDATE users
		SET name = $2, email = $3, is_admin = $4, updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.Exec(ctx, query,
		user.ID,
		user.Name,
		user.Email,
		user.IsAdmin,
	)

	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	if result.RowsAffected() == 0 {
		return ErrNotFound
	}

	return nil
}

// isDuplicateKeyError checks if the error is a unique constraint violation
func isDuplicateKeyError(err error) bool {
	// PostgreSQL error code 23505 is unique_violation
	return err != nil && (contains(err.Error(), "23505") || contains(err.Error(), "duplicate key"))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// CreateOTP inserts a new OTP record
func (r *UserRepository) CreateOTP(ctx context.Context, otp *domain.OTP) error {
	query := `
		INSERT INTO otps (id, user_id, phone_number, email, otp_code, purpose, expires_at, is_verified, attempts, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	otp.ID = uuid.New()
	_, err := r.db.Exec(ctx, query,
		otp.ID,
		otp.UserID,
		otp.PhoneNumber,
		otp.Email,
		otp.OTPCode,
		otp.Purpose,
		otp.ExpiresAt,
		otp.IsVerified,
		otp.Attempts,
		otp.CreatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create OTP: %w", err)
	}

	return nil
}

// GetValidOTP retrieves a valid (not expired, not verified) OTP
func (r *UserRepository) GetValidOTP(ctx context.Context, contact string, purpose domain.OTPPurpose) (*domain.OTP, error) {
	query := `
		SELECT id, user_id, phone_number, email, otp_code, purpose, expires_at, is_verified, verified_at, attempts, created_at
		FROM otps
		WHERE (phone_number = $1 OR email = $1)
		AND purpose = $2
		AND is_verified = FALSE
		AND expires_at > NOW()
		AND attempts < 5
		ORDER BY created_at DESC
		LIMIT 1
	`

	otp := &domain.OTP{}
	err := r.db.QueryRow(ctx, query, contact, purpose).Scan(
		&otp.ID,
		&otp.UserID,
		&otp.PhoneNumber,
		&otp.Email,
		&otp.OTPCode,
		&otp.Purpose,
		&otp.ExpiresAt,
		&otp.IsVerified,
		&otp.VerifiedAt,
		&otp.Attempts,
		&otp.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get OTP: %w", err)
	}

	return otp, nil
}

// IncrementOTPAttempts increments the failed attempt counter
func (r *UserRepository) IncrementOTPAttempts(ctx context.Context, otpID uuid.UUID) error {
	query := `
		UPDATE otps
		SET attempts = attempts + 1
		WHERE id = $1
	`

	_, err := r.db.Exec(ctx, query, otpID)
	if err != nil {
		return fmt.Errorf("failed to increment OTP attempts: %w", err)
	}

	return nil
}

// MarkOTPVerified marks an OTP as verified
func (r *UserRepository) MarkOTPVerified(ctx context.Context, otpID uuid.UUID) error {
	query := `
		UPDATE otps
		SET is_verified = TRUE, verified_at = NOW()
		WHERE id = $1
	`

	_, err := r.db.Exec(ctx, query, otpID)
	if err != nil {
		return fmt.Errorf("failed to mark OTP as verified: %w", err)
	}

	return nil
}

// CreateSession inserts a new session record
func (r *UserRepository) CreateSession(ctx context.Context, session *domain.Session) error {
	query := `
		INSERT INTO sessions (id, user_id, token_id, device_info, ip_address, user_agent, expires_at, is_revoked, last_activity_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	session.ID = uuid.New()
	_, err := r.db.Exec(ctx, query,
		session.ID,
		session.UserID,
		session.TokenID,
		session.DeviceInfo,
		session.IPAddress,
		session.UserAgent,
		session.ExpiresAt,
		session.IsRevoked,
		session.LastActivityAt,
		session.CreatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create session: %w", err)
	}

	return nil
}

// GetSessionByTokenID retrieves a session by token ID
func (r *UserRepository) GetSessionByTokenID(ctx context.Context, tokenID string) (*domain.Session, error) {
	query := `
		SELECT id, user_id, token_id, device_info, ip_address, user_agent, expires_at, is_revoked, revoked_at, last_activity_at, created_at
		FROM sessions
		WHERE token_id = $1
	`

	session := &domain.Session{}
	err := r.db.QueryRow(ctx, query, tokenID).Scan(
		&session.ID,
		&session.UserID,
		&session.TokenID,
		&session.DeviceInfo,
		&session.IPAddress,
		&session.UserAgent,
		&session.ExpiresAt,
		&session.IsRevoked,
		&session.RevokedAt,
		&session.LastActivityAt,
		&session.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	return session, nil
}

// RevokeSession marks a session as revoked
func (r *UserRepository) RevokeSession(ctx context.Context, tokenID string) error {
	query := `
		UPDATE sessions
		SET is_revoked = TRUE, revoked_at = NOW()
		WHERE token_id = $1
	`

	_, err := r.db.Exec(ctx, query, tokenID)
	if err != nil {
		return fmt.Errorf("failed to revoke session: %w", err)
	}

	return nil
}
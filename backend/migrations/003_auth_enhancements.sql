-- Migration: 003_auth_enhancements
-- Description: Add authentication fields and OTP storage for login/signup
-- Date: 2024-01-20

-- Add password hash field to users table for email/password authentication
ALTER TABLE users ADD COLUMN password_hash VARCHAR(255);

-- Add email verification flag
ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Make email required and unique for proper authentication
-- Note: This assumes existing users have email. If not, add migration to populate default emails first
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- ============================================================================
-- OTP TABLE for phone and email verification
-- ============================================================================

CREATE TABLE otps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- User reference (optional - can be null for signup OTP before user creation)
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Contact information - either phone or email
    phone_number VARCHAR(15),
    email VARCHAR(255),
    
    -- OTP code (6 digits)
    otp_code VARCHAR(6) NOT NULL,
    
    -- Purpose of OTP (login, signup, password_reset, etc.)
    purpose VARCHAR(20) NOT NULL,
    
    -- Expiration timestamp (typically 5-10 minutes from creation)
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Verification status
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Track attempts to prevent brute force
    attempts INT NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT otps_contact_check CHECK (
        (phone_number IS NOT NULL AND email IS NULL) OR 
        (phone_number IS NULL AND email IS NOT NULL)
    ),
    CONSTRAINT otps_otp_format CHECK (otp_code ~ '^[0-9]{6}$'),
    CONSTRAINT otps_attempts_limit CHECK (attempts <= 5)
);

-- Index for fast OTP lookups by phone number
CREATE INDEX idx_otps_phone_number ON otps(phone_number) WHERE phone_number IS NOT NULL;

-- Index for fast OTP lookups by email
CREATE INDEX idx_otps_email ON otps(email) WHERE email IS NOT NULL;

-- Index for cleanup queries (delete expired OTPs)
CREATE INDEX idx_otps_expires_at ON otps(expires_at);

-- Index for user OTP history
CREATE INDEX idx_otps_user_id ON otps(user_id) WHERE user_id IS NOT NULL;

-- ============================================================================
-- SESSION TABLE for managing active user sessions
-- ============================================================================

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- User reference
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- JWT token identifier (jti claim)
    token_id VARCHAR(100) NOT NULL UNIQUE,
    
    -- Device/client information
    device_info TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Session expiration
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Revocation flag for logout
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    
    -- Last activity timestamp
    last_activity_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT sessions_token_id_not_empty CHECK (LENGTH(TRIM(token_id)) > 0)
);

-- Index for fast session lookups by user
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- Index for token validation
CREATE INDEX idx_sessions_token_id ON sessions(token_id);

-- Index for cleanup queries (delete expired sessions)
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE otps IS 'Stores OTP codes for phone and email verification';
COMMENT ON COLUMN otps.purpose IS 'Purpose: login, signup, password_reset, email_verify';
COMMENT ON COLUMN otps.attempts IS 'Number of failed verification attempts (max 5)';

COMMENT ON TABLE sessions IS 'Stores active user sessions for JWT token management';
COMMENT ON COLUMN sessions.token_id IS 'JWT token identifier (jti claim) for token revocation';
COMMENT ON COLUMN sessions.is_revoked IS 'Set to true on logout to invalidate token';

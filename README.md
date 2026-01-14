# raju-gari-kitchen

High-performance, low-latency food delivery system designed for 50-500 concurrent users.

## Architecture

**Modular Monolith** with Clean Architecture (Delivery → Usecase → Repository)

```
MY_APP/
├── backend/           # Go API server
│   ├── cmd/api/       # Entry point
│   ├── internal/      # Application code
│   ├── pkg/           # Shared packages
│   └── migrations/    # SQL migrations
└── flutter_app/       # Mobile application
    └── lib/           # Dart source code
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Go 1.22+ (Fiber) |
| Database | PostgreSQL (pgx) |
| Cache | Redis |
| Logging | Uber Zap |
| Payments | Razorpay |
| Frontend | Flutter (Riverpod) |

## Quick Start

### 1. Database Setup

```bash
# Start PostgreSQL & Redis (example with Docker)
docker run -d --name postgres -e POSTGRES_PASSWORD=password -p 5432:5432 postgres:14
docker run -d --name redis -p 6379:6379 redis:7

# Create database
createdb fooddelivery

# Run migrations
psql -d fooddelivery -f backend/migrations/001_initial_schema.sql
```

### 2. Backend Setup

```bash
cd backend
cp .env.example .env
# Edit .env with your credentials

go mod download
go run cmd/api/main.go
```

### 3. Flutter App Setup

```bash
cd flutter_app
flutter pub get
flutter run
```

## Key Features

### Payment Security
- **Server-side price calculation** - Never trust client prices
- **Idempotent order creation** - Prevents duplicate charges
- **Webhook signature verification** - HMAC SHA256 validation
- **Optimistic locking** - Prevents race conditions

### Performance
- **Redis caching** - 1-hour TTL for menu items
- **Connection pooling** - PostgreSQL pgx pool
- **Structured logging** - JSON with request tracing

### Flutter UX
- **Optimistic updates** - Instant UI feedback
- **Payment verification** - Backend confirmation required

## Environment Variables

```bash
# Required for backend
DATABASE_URL=postgres://user:pass@localhost:5432/fooddelivery
REDIS_URL=redis://localhost:6379/0
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx
JWT_SECRET=your-secret-key
```

## API Documentation

See `backend/README.md` for full API reference.

## License

MIT

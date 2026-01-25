# Agent Guidelines: Crave Delivery

This document provides essential information for agentic coding agents working on the Crave Delivery repository. Adhere to these patterns to maintain consistency across the Go backend and Flutter frontend.

## 🛠 Build, Lint, and Test Commands

### Backend (Go)
- **Install Dependencies:** `go mod download`
- **Build:** `go build -o server ./backend/cmd/api`
- **Run Locally:** `go run ./backend/cmd/api/main.go`
- **Test All:** `go test ./backend/...`
- **Run Single Test:** `go test -v -run <TestName> ./backend/<path-to-package>`
- **Lint:** `go vet ./backend/...` (or `golangci-lint run` if available)

### Frontend (Flutter)
- **Install Dependencies:** `flutter pub get`
- **Run Web:** `flutter run -d chrome --dart-define=API_URL=http://localhost:8080`
- **Test All:** `flutter test`
- **Run Single Test:** `flutter test flutter_app/test/widget_test.dart`
- **Lint:** `flutter analyze`

---

## 🏗 Backend Architecture & Style (Go)

### Clean Architecture
Follow the modular monolith structure:
1. **Domain (`internal/domain`):** Core business entities (e.g., `User`, `MenuItem`, `Order`). Database agnostic.
2. **UseCase (`internal/usecase`):** Business logic and application services. Orchestrates repositories.
3. **Repository (`internal/repository`):** Data access layer. Implementation of persistence interfaces (Postgres/Redis).
4. **Handlers (`internal/handlers`):** HTTP delivery layer using the Fiber framework. Request parsing and response mapping.
5. **Pkg (`pkg/`):** Infrastructure utilities like `logger`, `database` connection, and `redis` client.

### Project Directory Structure
- `backend/cmd/api/main.go`: Application entry point.
- `backend/migrations/`: SQL migration files (001_initial_schema.sql, etc.).
- `flutter_app/lib/screens/`: UI pages.
- `flutter_app/lib/providers/`: Riverpod state providers.
- `flutter_app/lib/services/`: External service integrations (API, Logger, Payment).

### Naming & Types
- **Packages:** Always lowercase (e.g., `package handlers`).
- **Exported Types/Funcs:** PascalCase.
- **Private Types/Funcs:** camelCase.
- **Currency:** Store all prices as `int64` in **paisa** (1/100 of a Rupee) to avoid floating-point errors.
- **UUIDs:** Use `github.com/google/uuid` for all IDs.

### Error Handling & Logging
- Use `errors.Is(err, TargetErr)` for error checking.
- Return descriptive errors from UseCases; map them to Fiber status codes in Handlers.
- **Logging:** Use the structured logger in `pkg/logger`. Include `request_id` in handler logs.
- Never log sensitive data (passwords, OTPs, JWT secrets).

---

## 🎨 Frontend Architecture & Style (Flutter/Dart)

### State Management
- **Riverpod:** Use `ConsumerWidget` or `ConsumerStatefulWidget`.
- **Providers:** Define providers in `lib/providers/`.
- **Optimistic UI:** Update local state immediately for cart actions; rollback on API failure.

### Code Style
- **Formatting:** Follow `dart format`.
- **Naming:** `PascalCase` for classes, `camelCase` for variables and functions.
- **Widgets:** Prefer composition over deep inheritance. Use `const` constructors where possible.
- **Imports:** Order: `dart:`, `package:`, then relative local imports.

### Error Handling & Networking
- **API Client:** Use `ApiService` in `lib/services/`.
- **Global Errors:** Handled via `runZonedGuarded` in `main.dart`.
- **Payment Safety:** Never trust client-side payment success. Always verify with the backend `/orders/verify` endpoint using the Razorpay signature.

---

## 🔒 Security & Data Integrity
- **JWT:** Tokens are stored in `SharedPrefernces` on the client and validated in backend middleware.
- **Optimistic Locking:** The `Order` model uses a `Version` field. Include the version in updates to prevent race conditions during payment processing.
- **Secrets:** Never commit `.env` files. Use environment variables for `DATABASE_URL`, `REDIS_URL`, `RAZORPAY_KEY_*`, and `JWT_SECRET`.

---

## 📝 General Rules
- **Comments:** Focus on *why*, not *what*.
- **Consistency:** When adding a new feature, mirror the existing pattern (e.g., if adding `User`, look at `MenuItem` repository/usecase/handler flow).
- **Tooling:** Always run `flutter analyze` or `go vet` after making changes.

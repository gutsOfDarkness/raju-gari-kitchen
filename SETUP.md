# Crave Delivery - Setup & Contribution Guide

Welcome to the **Crave Delivery** project! This is a comprehensive food delivery application built with a **Go (Fiber)** backend and a **Flutter** frontend, orchestrating **PostgreSQL** and **Redis** for data management.

## Quick Start (Docker)

The easiest way to run the entire stack is using Docker Compose.

### Prerequisitess
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.

### Application URL
- **Frontend**: [http://localhost:3000](http://localhost:3000)
- **Backend API**: [http://localhost:8080](http://localhost:8080)

### Run Command

```bash
# Start all services (Backend, Frontend, DB, Redis, Migrator)
docker-compose up --build
```

- The **Migrator** service will automatically set up the database schema and seed initial data.
- The **Backend** will wait for the database to be ready.

### Stop Command

```bash
docker-compose down
```

---

## Local Development

If you want to contribute or run services individually:

### Backend (Go)

1.  **Navigate**: `cd backend`
2.  **Dependencies**: `go mod download`
3.  **Environment**: Ensure PostgreSQL and Redis are running (e.g., via Docker) and update `.env`.
4.  **Run**: `go run cmd/api/main.go`

### Frontend (Flutter)

1.  **Navigate**: `cd flutter_app`
2.  **Dependencies**: `flutter pub get`
3.  **Run (Web)**:
    ```bash
    flutter run -d chrome --dart-define=API_URL=http://localhost:8080
    ```
    *Note: The `API_URL` environment variable tells the app where to find the backend.*

## Project Structure

- **`backend/`**: Go Fiber API application.
    - `cmd/api`: Entry point.
    - `migrations/`: SQL files for schema and seed data.
- **`flutter_app/`**: Flutter cross-platform application (Mobile + Web).
- **`docker-compose.yml`**: Orchestration for the full stack.

## Design Guidelines

- **Theme**: Dark, minimalist, dynamic.
- **Components**: Card-based layouts, responsive styling.

---
*Happy Coding!*

# Raju Gari Kitchen

A full-stack food delivery application featuring a Flutter web frontend and Go backend API.

## Project Structure

```
raju-gari-kitchen/
  backend/           # Go API server (Fiber framework)
  flutter_app/       # Flutter web application
  docker-compose.yml # Container orchestration
```

## Features

- Menu browsing with category filtering
- In-place cart management (add/remove items without navigation)
- Razorpay payment integration
- Order tracking and confirmation
- Responsive design for desktop and mobile web

## Tech Stack

### Frontend
- Flutter Web (Dart)
- Riverpod for state management
- Optimistic UI updates for smooth UX

### Backend
- Go with Fiber HTTP framework
- PostgreSQL database
- Redis caching
- Structured JSON logging (slog)

## Local Development

### Prerequisites
- Docker and Docker Compose
- Flutter SDK (3.0+)
- Go 1.22+

### Running with Docker

```bash
# Start all services
docker-compose up -d

# View logs
docker logs food_delivery_backend
docker logs food_delivery_frontend
```

Services will be available at:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- PostgreSQL: localhost:5432
- Redis: localhost:6379

### Running Frontend Locally (Development)

```bash
cd flutter_app
flutter pub get
flutter run -d chrome
```

### Running Backend Locally

```bash
cd backend
go mod download
go run cmd/api/main.go
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Health check |
| GET | /api/v1/menu | Get all menu items |
| GET | /api/v1/menu/:id | Get single menu item |
| POST | /api/v1/orders/create | Create new order |
| POST | /api/v1/orders/verify | Verify payment |

## Environment Variables

### Backend

| Variable | Description | Default |
|----------|-------------|---------|
| PORT | Server port | 8080 |
| DATABASE_URL | PostgreSQL connection string | Required |
| REDIS_URL | Redis connection string | Required |
| RAZORPAY_KEY_ID | Razorpay API key | Required for payments |
| RAZORPAY_KEY_SECRET | Razorpay secret | Required for payments |
| JWT_SECRET | JWT signing secret | Required |
| ALLOWED_ORIGINS | CORS allowed origins | * |

### Frontend Build

| Variable | Description |
|----------|-------------|
| API_URL | Backend API base URL |

## Logging

### Frontend Logging

Logs are output to browser console. Open DevTools (F12) to view logs including:
- Cart operations (add, remove, update)
- Route navigation
- API requests
- Error traces

### Backend Logging

Structured JSON logs to stdout:

```json
{"time":"2026-01-17T12:00:00Z","level":"INFO","msg":"GetMenu request received","request_id":"abc-123"}
```

Log levels: DEBUG, INFO, WARN, ERROR

## Deployment

See [VERCEL_DEPLOYMENT.md](./VERCEL_DEPLOYMENT.md) for detailed deployment instructions.

## Troubleshooting

### Cart not updating in-place

1. Open browser DevTools console
2. Click ADD button
3. Check for log messages like:
   - `[MenuItemCard] ADD button pressed for...`
   - `[CartNotifier] addItem() called for...`
   - `[CartNotifier] State updated. New state:...`

If logs appear but UI does not update, the issue is with state binding.
If no logs appear, check for JavaScript errors in console.

### Images not loading

- Ensure image files exist in `flutter_app/assets/images/`
- Check `pubspec.yaml` has correct asset paths
- For local assets, use path starting with `assets/images/`

### Backend connection errors

- Verify backend container is running: `docker ps`
- Check backend logs: `docker logs food_delivery_backend`
- Verify API URL matches frontend configuration

## License

MIT License


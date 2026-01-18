# Vercel Deployment Guide for Crave Delivery

This guide explains how to deploy the Crave Delivery food delivery application to Vercel.

## Architecture Overview

The application consists of two main components:

1. **Backend (Go API)** - REST API server built with Fiber
2. **Frontend (Flutter Web)** - Single-page web application

For Vercel deployment, the backend can be deployed as serverless functions or run on a separate server/container service.

## Prerequisites

- Vercel account (https://vercel.com)
- GitHub repository connected to Vercel
- PostgreSQL database (Vercel Postgres, Neon, or Supabase)
- Redis instance (Upstash Redis recommended for serverless)
- Razorpay account for payments (optional)

---

## Option 1: Automatic Builds (Recommended)

This method allows you to push code to GitHub and have Vercel automatically build and deploy your Flutter app.

### Step 1: Push Build Scripts

Ensured `flutter_app/vercel.json` and `flutter_app/vercel_build.sh` are in your repository.

### Step 2: Configure Vercel Project

1. Import your Git repository in Vercel.
2. Select **Framework Preset**: `Other`.
3. Set **Root Directory** to `flutter_app` (if your app is in a subdirectory).
4. **Build Command**: `bash vercel_build.sh` (should be auto-detected from `vercel.json`).
5. **Output Directory**: `build/web` (should be auto-detected from `vercel.json`).
6. Deploy!

### How it works
The `vercel_build.sh` script installs Flutter in the Vercel environment and builds your app on every push.

---

## Option 2: Frontend-Only Deployment (Manual/Static)

Deploy the Flutter web app to Vercel and host the backend separately (Railway, Render, or Docker container).

### Step 1: Build Flutter Web App

```bash
cd flutter_app
flutter build web --release --dart-define=API_URL=https://your-backend-url.com
```

### Step 2: Configure Vercel Project

Create `vercel.json` in `flutter_app/` directory:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "build/web/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/build/web/$1"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=0, must-revalidate"
        }
      ]
    }
  ]
}
```

### Step 3: Deploy to Vercel

```bash
cd flutter_app
vercel --prod
```

Or connect your GitHub repository to Vercel for automatic deployments.

---

## Option 2: Full-Stack on Vercel (Experimental)

Deploy both frontend and backend to Vercel using serverless functions.

### Backend Configuration

Create `api/` directory in project root for Go serverless functions.

Note: Go serverless functions on Vercel have cold start limitations. For production, Option 1 is recommended.

---

## Environment Variables

Configure these environment variables in Vercel dashboard:

### Backend Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/db?sslmode=require` |
| `REDIS_URL` | Redis connection string | `redis://default:token@host:6379` |
| `RAZORPAY_KEY_ID` | Razorpay API key ID | `rzp_live_xxxxx` |
| `RAZORPAY_KEY_SECRET` | Razorpay API secret | `secret_xxxxx` |
| `RAZORPAY_WEBHOOK_SECRET` | Webhook signature secret | `webhook_secret` |
| `JWT_SECRET` | Secret for JWT tokens | `your-secure-secret` |
| `PORT` | Server port | `8080` |
| `ALLOWED_ORIGINS` | CORS origins | `https://your-frontend.vercel.app` |

### Frontend Build Arguments

| Variable | Description | Example |
|----------|-------------|---------|
| `API_URL` | Backend API base URL | `https://api.yourdomain.com` |

---

## Database Setup

### Using Vercel Postgres

1. Go to Vercel Dashboard > Storage > Create Database
2. Select PostgreSQL
3. Copy the connection string
4. Run migrations:

```bash
psql $DATABASE_URL -f backend/migrations/001_initial_schema.sql
psql $DATABASE_URL -f backend/migrations/002_seed_data.sql
```

### Using External PostgreSQL (Neon, Supabase)

1. Create a database on your provider
2. Copy the connection string
3. Add to Vercel environment variables
4. Run migrations from local machine or CI/CD

---

## Redis Setup (Upstash)

1. Create account at https://upstash.com
2. Create a new Redis database
3. Copy the REST URL and token
4. Add `REDIS_URL` to Vercel environment variables

---

## Deployment Commands

### Manual Deployment

```bash
# Build frontend
cd flutter_app
flutter build web --release --dart-define=API_URL=https://your-api.com

# Deploy to Vercel
vercel --prod
```

### Automatic Deployment (GitHub Integration)

1. Connect repository to Vercel
2. Configure build settings:
   - Framework: Other
   - Build Command: `cd flutter_app && flutter build web --release`
   - Output Directory: `flutter_app/build/web`
3. Add environment variables
4. Deploy

---

## Logging and Monitoring

### Frontend Logs

- Browser console logs are available in browser DevTools
- For production monitoring, integrate with a service like Sentry or LogRocket

### Backend Logs

Structured JSON logs are output to stdout. On Vercel:

1. Go to Project > Logs
2. Filter by function name or time range
3. Logs are retained for 1 hour on free tier, longer on paid plans

Log format example:
```json
{"time":"2026-01-17T12:00:00Z","level":"INFO","msg":"GetMenu request received","request_id":"abc-123"}
```

---

## Troubleshooting

### Common Issues

**Issue: API requests fail with CORS errors**
- Ensure `ALLOWED_ORIGINS` includes your Vercel frontend URL
- Check that backend CORS middleware is configured correctly

**Issue: Database connection timeout**
- Use `?sslmode=require` in connection string for external databases
- Check database firewall rules allow Vercel IP ranges

**Issue: Images not loading**
- Ensure image assets are included in Flutter build
- Check asset paths in `pubspec.yaml`

**Issue: Cold starts on serverless functions**
- Consider using a dedicated backend host for production
- Use connection pooling for database connections

---

## Production Checklist

- [ ] All environment variables configured
- [ ] Database migrations applied
- [ ] Redis cache working
- [ ] CORS configured for production domain
- [ ] SSL/HTTPS enabled
- [ ] Razorpay webhooks configured with correct URL
- [ ] Error tracking/monitoring enabled
- [ ] Performance monitoring enabled

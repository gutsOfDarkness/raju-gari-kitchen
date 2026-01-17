# Build stage
FROM ghcr.io/cirruslabs/flutter:3.22.2 AS builder

WORKDIR /app

# Optimizing: Copy only dependencies first to cache this layer
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Enable web support
RUN flutter config --enable-web

# Build for web
RUN flutter build web --release

# Runtime stage
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port (default nginx)
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

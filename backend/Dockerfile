# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies first (caching)
COPY go.mod go.sum ./
RUN go mod download

# Install dependencies for the final image
RUN apk --no-cache add ca-certificates tzdata

# Copy source
COPY . .

# Build static binary
# -s: disable symbol table
# -w: disable DWARF generation
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o api cmd/api/main.go

# Runtime stage - SCRATCH (empty image)
FROM scratch

WORKDIR /app

# Copy binary
COPY --from=builder /app/api .

# Copy timezone info (often needed)
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy SSL certificates (needed for HTTPS calls, e.g., Razorpay)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Expose port
EXPOSE 8080

# Run binary directly
ENTRYPOINT ["./api"]

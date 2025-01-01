# Build stage
FROM alpine:3.21.0 as builder

# Install zig and build dependencies from Alpine repositories
RUN apk add --no-cache \
    zig \
    musl-dev \
    gcc \
    git

# Create non-root user for build
RUN adduser -D builder

# Create and set working directory with proper permissions
WORKDIR /build
RUN chown builder:builder /build && \
    mkdir -p /build/public /build/config && \
    chown -R builder:builder /build/public /build/config

# Switch to non-root user
USER builder

# Clone Zap dependency
RUN git clone https://github.com/zigzap/zap.git /build/zap

# Copy only necessary build files with correct ownership
COPY --chown=builder:builder build.zig ./
COPY --chown=builder:builder build.zig.zon ./
COPY --chown=builder:builder src/ ./src/
COPY --chown=builder:builder zapped.json ./
COPY --chown=builder:builder public/ ./public/
COPY --chown=builder:builder config/ ./config/

# Build the application with static linking
RUN zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl

# Production stage
FROM alpine:3.21.0

# Install certbot for optional SSL
RUN apk add --no-cache \
    certbot \
    openssl \
    bash

# Create non-root user
RUN adduser -D appuser

# Set working directory and create necessary directories
WORKDIR /app
RUN mkdir -p uploads logs certs public config && \
    chown -R appuser:appuser /app

# Copy the binary and configs with correct ownership
COPY --from=builder --chown=appuser:appuser /build/zig-out/bin/zapped-starter ./
COPY --from=builder --chown=appuser:appuser /build/zapped.json ./
COPY --from=builder --chown=appuser:appuser /build/public/ ./public/
COPY --from=builder --chown=appuser:appuser /build/config/ ./config/

# Copy static assets with correct ownership
COPY --chown=appuser:appuser assets/ ./assets/

# Set environment variables
ENV PORT=3000
ENV HOST=0.0.0.0
ENV USE_SSL=false
ENV DOMAIN=""
ENV EMAIL=""

# Expose internal ports
EXPOSE 3000
EXPOSE 3443

# Copy and setup startup script
COPY --chown=appuser:appuser start.sh ./
RUN chmod +x start.sh

USER appuser
CMD ["./start.sh"]

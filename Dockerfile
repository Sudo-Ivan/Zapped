FROM alpine:3.21.0 as builder

RUN apk add --no-cache \
    zig \
    musl-dev \
    gcc \
    git

RUN adduser -D builder

WORKDIR /build
RUN chown builder:builder /build && \
    mkdir -p /build/public /build/config && \
    chown -R builder:builder /build/public /build/config

USER builder

RUN git clone https://github.com/zigzap/zap.git /build/zap

COPY --chown=builder:builder build.zig ./
COPY --chown=builder:builder build.zig.zon ./
COPY --chown=builder:builder src/ ./src/
COPY --chown=builder:builder zapped.json ./
COPY --chown=builder:builder public/ ./public/
COPY --chown=builder:builder config/ ./config/

RUN zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl

FROM alpine:3.21.0

RUN apk add --no-cache \
    openssl \
    bash

RUN adduser -D appuser && \
    mkdir -p /etc/letsencrypt && \
    chown -R appuser:appuser /etc/letsencrypt && \
    chmod 755 /etc/letsencrypt

WORKDIR /app
RUN mkdir -p uploads logs certs public config && \
    mkdir -p /app/certs/live && \
    chmod 755 /app/certs && \
    chmod 755 /app/certs/live && \
    chown -R appuser:appuser /app

VOLUME ["/app/certs"]

COPY --from=builder --chown=appuser:appuser /build/zig-out/bin/zapped-starter ./
COPY --from=builder --chown=appuser:appuser /build/zapped.json ./
COPY --from=builder --chown=appuser:appuser /build/public/ ./public/
COPY --from=builder --chown=appuser:appuser /build/config/ ./config/

COPY --chown=appuser:appuser assets/ ./assets/

ENV PORT=3000 \
    HOST=0.0.0.0 \
    USE_SSL=false \
    DOMAIN="" \
    EMAIL=""

EXPOSE 3000

COPY --chown=appuser:appuser start.sh ./
RUN chmod +x start.sh

USER appuser
CMD ["./start.sh"]

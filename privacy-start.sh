#!/bin/bash

# Create I2P tunnel config
echo "[zapped-http]
type = http
host = 127.0.0.1
port = 3000
inport = 80
keys = /app/i2p_service/zapped-keys.dat" > /etc/i2pd/tunnels.conf

# Start Tor
tor --runasdaemon 1

# Wait for Tor
until [ -f /app/hidden_service/hostname ]; do
    sleep 1
done
echo "Tor hidden service: $(cat /app/hidden_service/hostname)"

# Start I2P
i2pd --daemon

# Wait for I2P
sleep 5
echo "I2P ready - HTTP proxy on port 4444"

# SSL certificate setup
if [ "$USE_SSL" = "true" ] && [ ! -z "$DOMAIN" ] && [ ! -z "$EMAIL" ]; then
    echo "Setting up SSL certificate for $DOMAIN"
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domain "$DOMAIN" \
        --cert-path "/app/certs"
fi

# Start the Zap server
if [ "$USE_SSL" = "true" ] && [ -d "/app/certs/live/$DOMAIN" ]; then
    ./zapped-starter --ssl \
        --cert "/app/certs/live/$DOMAIN/fullchain.pem" \
        --key "/app/certs/live/$DOMAIN/privkey.pem"
else
    ./zapped-starter
fi 
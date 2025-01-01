#!/bin/bash

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
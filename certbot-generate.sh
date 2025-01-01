#!/bin/sh

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Error: DOMAIN and EMAIL must be set"
    exit 1
fi

certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domain "$DOMAIN" \
    --cert-path "/certs" 
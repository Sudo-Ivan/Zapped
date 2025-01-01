#!/bin/bash

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a service is running
check_service() {
    pgrep -f "$1" >/dev/null
    return $?
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Create Tor configuration
cat > /etc/tor/torrc << EOL || handle_error "Failed to create torrc"
SocksPort 127.0.0.1:9050
ControlPort 127.0.0.1:9051

HiddenServiceDir /app/hidden_service
HiddenServicePort 80 127.0.0.1:3000
EOL

# Create I2P tunnel config
cat > /etc/i2pd/tunnels.conf << EOL || handle_error "Failed to create tunnels.conf"
[zapped-http]
type = http
host = 127.0.0.1
port = 3000
inport = 80
keys = /var/lib/i2pd/zapped-keys.dat
EOL

# Create I2P main config
cat > /etc/i2pd/i2pd.conf << EOL || handle_error "Failed to create i2pd.conf"
datadir = /var/lib/i2pd
logfile = /var/log/i2pd/i2pd.log
loglevel = info

[sam]
enabled = true
address = 0.0.0.0
port = 7656

[httpproxy]
enabled = true
address = 0.0.0.0
port = 4444

[ntcp2]
enabled = true
port = 9000

[limits]
transittunnels = 1000
EOL

# Ensure hidden service directory exists with correct permissions
mkdir -p /app/hidden_service
chmod 700 /app/hidden_service
chown -R privacyuser:privacyuser /app/hidden_service

# Start Tor
log_message "Starting Tor..."
tor --runasdaemon 1 || handle_error "Failed to start Tor"

# Wait for Tor with timeout
log_message "Waiting for Tor to initialize..."
TOR_TIMEOUT=30
TOR_COUNTER=0
until [ -f /app/hidden_service/hostname ] || [ $TOR_COUNTER -eq $TOR_TIMEOUT ]; do
    sleep 1
    let TOR_COUNTER++
    
    if ! check_service "tor"; then
        handle_error "Tor process died during startup"
    fi
    
    if [ $((TOR_COUNTER % 5)) -eq 0 ]; then
        log_message "Still waiting for Tor... ($TOR_COUNTER seconds)"
    fi
done

if [ -f /app/hidden_service/hostname ]; then
    ONION_ADDRESS=$(cat /app/hidden_service/hostname)
    log_message "Tor hidden service: $ONION_ADDRESS"
else
    handle_error "Tor failed to create hidden service after ${TOR_TIMEOUT} seconds"
fi

# Start I2P in background
log_message "Starting I2P in background..."
i2pd --daemon --conf=/etc/i2pd/i2pd.conf --tunconf=/etc/i2pd/tunnels.conf &

# Start the Zap server
log_message "Starting Zap server..."
if [ "$USE_SSL" = "true" ] && [ -d "/app/certs/live/$DOMAIN" ]; then
    ./zapped-starter --ssl \
        --cert "/app/certs/live/$DOMAIN/fullchain.pem" \
        --key "/app/certs/live/$DOMAIN/privkey.pem" || handle_error "Failed to start Zap server with SSL"
else
    ./zapped-starter || handle_error "Failed to start Zap server"
fi
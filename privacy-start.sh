#!/bin/bash

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_service() {
    pgrep -f "$1" >/dev/null
    return $?
}

handle_error() {
    log_message "ERROR: $1"
    exit 1
}

cat > /etc/tor/torrc << EOL || handle_error "Failed to create torrc"
SocksPort 127.0.0.1:9050

# Hidden service configuration
HiddenServiceDir /app/hidden_service
HiddenServicePort 80 127.0.0.1:3000

# Security settings
DataDirectory /var/lib/tor
RunAsDaemon 1
CookieAuthentication 1
EOL

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

# Start I2P only if enabled
if [ "$USE_I2P" = "true" ]; then
    cat > /etc/i2pd/tunnels.conf << EOL || handle_error "Failed to create tunnels.conf"
[zapped-http]
type = http
host = 127.0.0.1
port = 3000
inport = 80
keys = /var/lib/i2pd/zapped-keys.dat
EOL

    cat > /etc/i2pd/i2pd.conf << EOL || handle_error "Failed to create i2pd.conf"
datadir = /var/lib/i2pd
logfile = /var/log/i2pd/i2pd.log
loglevel = info

[sam]
enabled = true
address = 0.0.0.0
port = 7656

[ntcp2]
enabled = true
port = 9000

[limits]
transittunnels = 1000
EOL

    # Start I2P in background
    log_message "Starting I2P in background..."
    i2pd --daemon --conf=/etc/i2pd/i2pd.conf --tunconf=/etc/i2pd/tunnels.conf &
else
    log_message "I2P disabled, skipping..."
fi

log_message "Starting Zap server..."
./zapped-starter || handle_error "Failed to start Zap server"
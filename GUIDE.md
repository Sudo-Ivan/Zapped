# Privacy Services Guide

This guide covers setup and troubleshooting for Tor and I2P services in Zapped.

## Tor Setup

### Checking Tor Status
```bash
# View Tor service status
podman exec zapped-privacy ps aux | grep tor

# Check Tor hidden service address
podman exec zapped-privacy cat /app/hidden_service/hostname

# View Tor logs
podman exec zapped-privacy cat /var/log/tor/notices.log
```

### Accessing .onion Services

1. **Using Tor Browser**
   - Download [Tor Browser](https://www.torproject.org/download/)
   - Launch Tor Browser
   - Copy your .onion address from hostname file
   - Visit `http://[your-onion-address].onion`

2. **Using SOCKS Proxy**
   ```bash
   # Test connection via curl
   curl --socks5-hostname localhost:9050 http://[your-onion-address].onion
   
   # Configure Firefox manually:
   # 1. Open Settings -> Network Settings
   # 2. Configure Proxy Access
   # 3. Select: Manual proxy configuration
   # 4. SOCKS Host: 127.0.0.1
   # 5. Port: 9050
   # 6. Select SOCKS v5
   ```

## I2P Setup

### Checking I2P Status
```bash
# View I2P service status
podman exec zapped-privacy ps aux | grep i2pd

# Check I2P tunnel configuration
podman exec zapped-privacy cat /etc/i2pd/tunnels.conf

# View I2P logs
podman exec zapped-privacy cat /var/log/i2pd/i2pd.log
```

### Accessing .i2p Services

1. **Using HTTP Proxy (Recommended)**
   - Port: 4444
   - Firefox Setup:
     1. Open Settings -> Network Settings
     2. Configure Proxy Access
     3. Select: Manual proxy configuration
     4. HTTP Proxy: 127.0.0.1
     5. Port: 4444
     6. No proxy for: localhost, 127.0.0.1
   
2. **Using I2P Browser Profile**
   ```bash
   # Create a dedicated Firefox profile for I2P
   firefox -P "I2P Profile" -no-remote
   
   # Configure the profile to use HTTP proxy (4444)
   # Save settings and always use this profile for I2P
   ```

## Troubleshooting

### Tor Issues

1. **Permission Errors**
   ```bash
   # Check directory permissions
   podman exec zapped-privacy ls -la /app/hidden_service
   
   # Should show: drwx------ owned by privacyuser
   ```

2. **Service Not Starting**
   ```bash
   # Check Tor configuration
   podman exec zapped-privacy cat /etc/tor/torrc
   
   # Restart Tor service
   podman exec zapped-privacy tor --runasdaemon 1
   ```

### I2P Issues

1. **Tunnel Problems**
   ```bash
   # Verify tunnel configuration
   podman exec zapped-privacy cat /etc/i2pd/tunnels.conf
   
   # Restart I2P service
   podman exec zapped-privacy killall i2pd
   podman exec zapped-privacy i2pd --daemon
   ```

2. **Proxy Connection Failed**
   - Ensure ports are properly exposed (4444 for HTTP proxy)
   - Check if I2P is running and initialized
   - Allow 5-10 minutes for initial network integration

## Security Recommendations

1. **Browser Security**
   - Use separate browser profiles for clearnet and privacy services
   - Enable HTTPS-Only mode
   - Install privacy-enhancing extensions
   - Clear browser data after sessions

2. **Network Security**
   - Use a VPN for additional privacy
   - Consider using Whonix or Tails for maximum anonymity
   - Keep all software updated

3. **Container Security**
   - Run privacy containers on isolated networks
   - Use volume mounts for persistent data
   - Regular security audits of configurations

## Common Commands

```bash
# View all service logs
podman logs zapped-privacy

# Check service ports
podman exec zapped-privacy netstat -tulpn

# Restart privacy services
podman restart zapped-privacy

# View .onion address
podman exec zapped-privacy cat /app/hidden_service/hostname

# Test local access
curl http://localhost:3000
```

## Additional Resources

- [Tor Project Documentation](https://tb-manual.torproject.org/)
- [I2P Documentation](https://geti2p.net/en/docs)
- [Privacy Tools Guide](https://www.privacytools.io/)
- [EFF Surveillance Self-Defense](https://ssd.eff.org/) 
# Zapped

A secure and fast [Zig Zap](https://zigzap.org/) web server with built-in privacy features.

> [!WARNING]  
> Still security testing, not ready for production use. Use at your own risk.

> [!IMPORTANT]
> I2P takes 5-15 minutes to start up initially. See [COMMANDS.md](COMMANDS.md) for more information.

## Zapped Features

- 🔥 Hot Reloading
- 🚀 Performance Optimized
- 🔒 Security Features
  - CORS protection
  - Rate limiting
  - CSRF protection
  - Security headers
  - IP blacklisting
- 🕶️ Privacy Features
  - Tor hidden services (.onion) (Onion-Location Header)
  - I2P network support (.i2p)
  - SAM bridge integration
  - Private networking
- 📦 Asset Optimization
  - Compression (Gzip/Brotli)
  - Cache control
  - MIME type handling
- 📊 Monitoring
  - Metrics endpoint
  - Memory stats
  - Request tracking
- 🔐 SSL Support
  - Automatic certificate generation
- 🐋 Containers
  - Docker
  - Podman
  - Rootless

## Quick Start

1. Install dependencies:
   - [Zig](https://ziglang.org/download/)
   - [Zap](https://zigzap.org/learn.html)
   - [Docker](https://docs.docker.com/get-docker/) or [Podman](https://podman.io/getting-started/installation)
   - [Tor](https://www.torproject.org/) (optional)
   - [I2P](https://geti2p.net/) (optional)

## Podman

```bash
git clone https://github.com/Sudo-Ivan/zapped.git
cd zapped

# Standard build
make podman
make podman-run

# Privacy-enhanced build with Tor/I2P
make podman-privacy
make podman-run-privacy

# With SSL
make podman-run-ssl DOMAIN=example.com EMAIL=admin@example.com

# Check SSL certificates
make check-certs DOMAIN=example.com

# Run with SSL + Tor + I2P
make podman-run-privacy-ssl DOMAIN=example.com EMAIL=admin@example.com

# Run with SSL + Tor
make podman-run-ssl DOMAIN=example.com EMAIL=admin@example.com USE_I2P=false
```

## Privacy Features

### Tor Hidden Services
- Automatic .onion address generation
- Hidden service configuration

### I2P Integration
- SAM bridge support
- I2P network tunnels

## Configuration

Edit `zapped.json` to customize:
- Server settings
- Security options
- Tor configuration
- I2P settings
- Compression settings
- Cache control
- CORS settings
- Rate limiting

## Port Configuration

For non-root port binding (80/443), you can either:

1. Set system-wide unprivileged port start:
```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

2. Or use higher ports (3000/3443) with reverse proxy
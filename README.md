# Zapped

A secure and fast [Zig Zap](https://zigzap.org/) web server with built-in privacy features.

## Features

- 🔥 Hot Reloading
- 🚀 Performance Optimized
- 🔒 Security Features
  - CORS protection
  - Rate limiting
  - CSRF protection
  - Security headers
  - IP blacklisting
- 🕶️ Privacy Features
  - Tor hidden services (.onion)
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

## Quick Start

1. Install dependencies:
   - [Zig](https://ziglang.org/download/)
   - [Zap](https://zigzap.org/learn.html)
   - [Docker](https://docs.docker.com/get-docker/) or [Podman](https://podman.io/getting-started/installation)
   - [Tor](https://www.torproject.org/) (optional)
   - [I2P](https://geti2p.net/) (optional)

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
```

## Privacy Features

### Tor Hidden Services
- Automatic .onion address generation
- Control port integration
- Hidden service configuration

### I2P Integration
- SAM bridge support
- HTTP proxy (access .i2p sites)
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

## License

MIT

```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
sudo sysctl net.ipv4.ip_unprivileged_port_start=443
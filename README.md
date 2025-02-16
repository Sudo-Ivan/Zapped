# Zapped

A secure and fast [Zig Zap](https://zigzap.org/) web server with built-in privacy features.

> [!WARNING]  
> Still early development and security testing, Use at your own risk.

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

2. Drop your website into the `public` directory.

3. Edit `zapped.json` to your liking.

4. Run the following commands:

> Replace docker with podman to use Podman instead of Docker.

```bash
make docker
make docker-run
```
or with Tor:

```bash
make docker-privacy
make docker-run-privacy USE_I2P=false # change to true to use I2P
```

```bash
git clone https://github.com/Sudo-Ivan/zapped.git
cd zapped
```

## Privacy Features

### Tor Hidden Services
- Automatic .onion address generation
- Hidden service configuration
- Onion-Location Header

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
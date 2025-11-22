# X/Twitter → xcancel Redirector

Local network tool that transparently redirects all X/Twitter traffic to [xcancel.com](https://xcancel.com), allowing you to browse Twitter content without directly accessing X's servers.

## What is xcancel?

[xcancel.com](https://xcancel.com) is a privacy-respecting Twitter/X frontend that lets you view tweets, threads, and profiles without tracking, ads, or algorithm manipulation. It's similar to Nitter but remains actively maintained as of 2025.

## How It Works

This setup intercepts X/Twitter traffic using DNS override + reverse proxy:

```
┌─────────────┐      DNS Query           ┌──────────────┐
│ Your Device │─────twitter.com?────────▶│ DNS Server   │
│             │                           │ (Pi-hole/    │
│             │◀────nginx IP (local)─────│  dnsmasq)    │
└─────────────┘                           └──────────────┘
       │
       │ HTTP Request to twitter.com
       │ (goes to nginx IP instead)
       ▼
┌─────────────┐
│ nginx       │─────301 Redirect────────▶ xcancel.com
│ Container   │                           (loads content)
│ (local)     │
└─────────────┘
```

**What happens:**

1. Your DNS server points twitter.com/x.com/t.co to your nginx server's IP
2. nginx receives the request and issues a 301 redirect to xcancel.com
3. Your browser loads content from xcancel instead of X

**Why?** View tweets shared in links while avoiding tracking and supporting privacy-respecting alternatives.

## Prerequisites

- Docker & Docker Compose
- Local DNS control (Pi-hole, router admin, or ability to run dnsmasq)
- Basic familiarity with command line (or use the web wizard)

## Choose Your Setup Path

### 🎯 Path 1: Web Wizard (Recommended for Beginners)

**[🚀 Launch Web Wizard](https://ryantenney.github.io/xcancel-forwarder/setup-wizard.html)**

Interactive browser tool that:

- Asks simple questions about your network
- Generates all config files for you
- Provides step-by-step instructions
- No command-line experience needed

**Time**: 10-15 minutes • **Difficulty**: Easy

### ⚡ Path 2: CLI Wizard (For Servers)

```bash
python3 scripts/setup-wizard.py
```

Command-line wizard that:

- Auto-detects your network settings
- Can run mkcert automatically for SSL
- Creates config files with validation
- Best for headless servers or SSH

**Time**: 5-10 minutes • **Difficulty**: Medium

### 📚 Path 3: Manual Setup (For Learning)

Follow the detailed guides to understand each component:

1. [Quick Start Guide](docs/QUICKSTART.md) - Step-by-step manual setup
2. [SSL Setup (mkcert)](docs/SSL_SETUP_MKCERT.md) - Easy certificates
3. [DNS Configuration](docs/DECISION_GUIDE.md) - Choose your DNS method

**Time**: 20-30 minutes • **Difficulty**: Medium-Hard

**Not sure which?** See [Decision Guide](docs/DECISION_GUIDE.md) for help choosing setup options.

## Quick Start (Manual)

For those who want to understand each step:

```bash
# 1. Clone and configure
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder
cp .env.example .env
# Edit .env with your network settings

# 2. Set up SSL certificates (optional but recommended)
brew install mkcert
mkcert -install
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"
# Place certificates in nginx/ssl/

# 3. Start nginx
docker compose up -d

# 4. Configure DNS (choose one):
#    - Pi-hole: Add DNS records in web UI
#    - dnsmasq: Uncomment in docker-compose.yaml
#    - Router: Add static DNS entries
#    See docs/ for detailed instructions

# 5. Test
curl -I http://twitter.com  # Should show 301 to xcancel.com
```

**Full details**: See [docs/QUICKSTART.md](docs/QUICKSTART.md)

## Configuration Options

### Web Server

- **nginx** (default): Battle-tested, widely used
- **Caddy** (alternative): Simpler config (4 lines vs 27)

See [Caddy Alternative](docs/CADDY_ALTERNATIVE.md)

### SSL Certificates

- **mkcert** (recommended): Automatic trusted certificates
- **Manual OpenSSL**: Full control over CA parameters

See [SSL Setup Guide](docs/SSL_SETUP_MKCERT.md) or [Advanced SSL](docs/SSL_SETUP.md)

### DNS Method

- **Pi-hole** (easiest if you have it): Web UI configuration
- **dnsmasq** (included): Dedicated DNS server
- **Router**: Static DNS entries
- **Hosts file**: Per-device (no Docker DNS needed)

See [Decision Guide](docs/DECISION_GUIDE.md) to choose

### Networking

- **Bridge** (simpler): Uses host IP with port forwarding
- **Macvlan** (recommended): Dedicated IP for nginx container

See `docker-compose.yaml` comments for setup

## Project Structure

```
.
├── setup-wizard.html          # Web-based setup wizard
├── docker-compose.yaml        # nginx configuration
├── docker-compose.caddy.yaml  # Caddy alternative
├── .env.example               # Environment template
├── nginx/
│   ├── conf.d/
│   │   └── xcancel-redirect.conf  # Redirect rules
│   └── ssl/                   # Place certificates here
├── caddy/
│   ├── Caddyfile              # Caddy config (simpler)
│   └── ssl/                   # Caddy certificates
├── dnsmasq/
│   └── dnsmasq.conf           # Optional DNS server
├── docs/                      # Detailed guides
└── scripts/
    ├── setup-wizard.py        # CLI wizard
    └── test-redirect.sh       # Quick test
```

## Testing

```bash
# Check DNS resolution
nslookup twitter.com  # Should return nginx IP

# Test HTTP redirect
curl -I http://twitter.com  # Should show 301

# Test HTTPS redirect (if SSL configured)
curl -I https://twitter.com

# Test in browser
# Visit twitter.com - should redirect to xcancel.com
```

**Detailed testing**: See [docs/TESTING.md](docs/TESTING.md)

## Common Issues

### Redirect not working

```bash
# Check DNS
nslookup twitter.com  # Should return nginx IP

# Check nginx is running
docker compose ps

# View logs
docker compose logs nginx
```

### Browser warnings

- Install CA certificate on device (see SSL setup guide)
- Restart browser after installing CA
- Clear browser cache

### DNS not updating

- Flush DNS cache on device
- Verify device is using correct DNS server
- Check DNS server logs

**Full troubleshooting**: See [docs/TESTING.md](docs/TESTING.md)

## Quick Reference

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f nginx

# Restart
docker compose restart

# Stop
docker compose down

# Update
docker compose pull && docker compose up -d
```

**Complete reference**: See [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

## Documentation

**Getting Started:**

- **[Quick Start Guide](docs/QUICKSTART.md)** - Detailed manual setup steps
- **[Decision Guide](docs/DECISION_GUIDE.md)** - Help choosing options
- **[Examples](docs/EXAMPLES.md)** - Real-world setup walkthroughs
- **[FAQ](docs/FAQ.md)** - Frequently asked questions

**Configuration:**

- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Commands cheat sheet
- **[SSL Setup (mkcert)](docs/SSL_SETUP_MKCERT.md)** - Easy SSL certificates
- **[SSL Setup (OpenSSL)](docs/SSL_SETUP.md)** - Advanced SSL control
- **[Pi-hole Setup](docs/PIHOLE_SETUP.md)** - Pi-hole configuration
- **[dnsmasq Setup](docs/DNSMASQ_SETUP.md)** - Included DNS server
- **[dnsmasq Advanced](docs/DNSMASQ_ADVANCED.md)** - Performance, security, custom DNS
- **[Other DNS Options](docs/OTHER_DNS.md)** - Router, BIND, hosts file
- **[Caddy Alternative](docs/CADDY_ALTERNATIVE.md)** - Simpler web server

**Testing & Troubleshooting:**

- **[Testing Guide](docs/TESTING.md)** - Essential verification procedures
- **[Advanced Testing](docs/TESTING_ADVANCED.md)** - Monitoring, performance, automation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Symptom-based problem solving

## Security Notes

Installing a self-signed CA as trusted means your device will trust any certificate signed by that CA. Keep the CA private key secure and only install on devices you control.

This setup only intercepts domains you explicitly configure. It cannot intercept other domains without adding them to DNS, nginx config, and SSL certificate.

See [Security Considerations](docs/SSL_SETUP.md#security-considerations) for details.

## Contributing

Issues and pull requests welcome at [https://github.com/ryantenney/xcancel-forwarder](https://github.com/ryantenney/xcancel-forwarder)

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- [xcancel.com](https://xcancel.com) - Privacy-respecting Twitter frontend
- [Pi-hole](https://pi-hole.net/) - Network-wide ad blocking
- [nginx](https://nginx.org/) - High-performance web server

# X/Twitter → xcancel Redirector

Local network tool that transparently redirects all X/Twitter traffic to [xcancel.com](https://xcancel.com), allowing you to browse Twitter content without directly accessing X's servers.

## What is xcancel?

[xcancel.com](https://xcancel.com) is a privacy-respecting Twitter/X frontend that lets you view tweets, threads, and profiles without:

- Tracking
- Ads
- Algorithm manipulation
- Supporting X's current management

It's similar to Nitter but remains actively maintained as of 2025.

## How This Works

This setup uses two components to intercept and redirect X/Twitter traffic:

1. **DNS Override**: Your local DNS server (Pi-hole, dnsmasq, router, etc.) points `twitter.com`, `x.com`, and `t.co` to your nginx server's IP
2. **NGINX Reverse Proxy**: Receives requests for X/Twitter domains and issues HTTP 301 redirects to xcancel.com

When you visit `https://twitter.com/username`, your browser:

1. Asks DNS for twitter.com → gets your nginx server's IP
2. Connects to your nginx server
3. Receives a redirect to `https://xcancel.com/username`
4. Loads content from xcancel instead

## Why This Approach?

Rather than blocking X/Twitter entirely, this redirects to a privacy-respecting frontend so you can still:

- View tweets shared in links
- Follow conversations
- Browse profiles
- Access Twitter content without supporting the platform

## Prerequisites

- **Docker & Docker Compose** installed
- **Local DNS control** (Pi-hole, router admin, or ability to run dnsmasq)
- **SSL Certificate Setup** (optional but recommended - see below)

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Copy environment template
cp .env.example .env

# Edit .env with your network settings
vim .env
```

### 2. Choose Your Networking Mode

**Option A: Bridge Networking (Simpler)**

Default configuration. Uses standard Docker port forwarding on your host's IP.

- Keep `docker-compose.yaml` as-is
- Configure DNS to point domains to your **Docker host's IP**
- Uses ports 80 and 443 on your host

**Option B: Macvlan Networking (Recommended for Pi-hole/dnsmasq)**

Gives nginx a dedicated IP on your LAN, separate from the host.

1. Uncomment the `macvlan_lan` network in `docker-compose.yaml`
2. Uncomment the `networks` section in the `nginx` service
3. Comment out the `ports` section in the `nginx` service
4. Set network configuration in `.env`
5. Configure DNS to point domains to your **nginx container's dedicated IP**

See `docker-compose.yaml` comments for details.

### 3. SSL Certificates (Optional but Recommended)

For HTTPS interception without browser warnings, you need a self-signed CA and certificates.

**Quick version:**

1. Create a self-signed Certificate Authority
2. Generate a certificate for twitter.com/x.com/t.co
3. Install your CA as trusted on all devices
4. Place certificates in `nginx/ssl/`

**Detailed instructions:** See [docs/SSL_SETUP.md](docs/SSL_SETUP.md)

**Skip SSL?** Remove or comment out the SSL-related lines in `nginx/conf.d/xcancel-redirect.conf` (lines 3, 5, 9, 13-18, 20-21). Only HTTP (port 80) will work.

### 4. DNS Configuration

Choose ONE of these options:

#### Option A: Pi-hole (Recommended)

See [docs/PIHOLE_SETUP.md](docs/PIHOLE_SETUP.md)

#### Option B: Use Included dnsmasq

1. Uncomment the `dnsmasq` service in `docker-compose.yaml`
2. Uncomment macvlan networking (dnsmasq requires it)
3. Edit `dnsmasq/dnsmasq.conf` with your nginx IP
4. Configure devices/DHCP to use dnsmasq IP as DNS server

See [docs/DNSMASQ_SETUP.md](docs/DNSMASQ_SETUP.md)

#### Option C: Router/Other DNS

See [docs/OTHER_DNS.md](docs/OTHER_DNS.md)

### 5. Start the Service

```bash
# Start nginx (and optionally dnsmasq)
docker compose up -d

# Check logs
docker compose logs -f nginx

# Check status
docker compose ps
```

### 6. Test the Setup

See [docs/TESTING.md](docs/TESTING.md) for verification steps.

Quick test:

```bash
# Should return your nginx IP
nslookup twitter.com

# Should show 301 redirect to xcancel.com
curl -I http://twitter.com

# If you set up SSL:
curl -I https://twitter.com
```

## Project Structure

```
.
├── docker-compose.yaml        # Container orchestration
├── .env.example               # Environment template
├── nginx/
│   ├── nginx.conf            # Main nginx config
│   ├── conf.d/
│   │   └── xcancel-redirect.conf  # Redirect rules
│   └── ssl/                  # SSL certificates (not in git)
│       └── README.md
├── dnsmasq/
│   └── dnsmasq.conf          # Optional DNS server config
├── docs/
│   ├── SSL_SETUP.md          # Certificate generation guide
│   ├── PIHOLE_SETUP.md       # Pi-hole configuration
│   ├── DNSMASQ_SETUP.md      # dnsmasq configuration
│   ├── OTHER_DNS.md          # Other DNS options
│   └── TESTING.md            # Testing and verification
└── scripts/
    └── test-redirect.sh      # Quick test script
```

## Maintenance

### View Logs

```bash
docker compose logs -f nginx
```

### Restart Services

```bash
docker compose restart
```

### Update nginx Image

```bash
docker compose pull
docker compose up -d
```

### Stop Everything

```bash
docker compose down
```

## Troubleshooting

### Browser Still Reaching X Directly

1. Check DNS is returning correct IP: `nslookup twitter.com`
2. Clear browser DNS cache (Chrome: `chrome://net-internals/#dns`)
3. Verify nginx is running: `docker compose ps`
4. Check nginx logs: `docker compose logs nginx`

### SSL Certificate Warnings

1. Verify CA is installed as trusted root on your device
2. Check certificate matches domains: `openssl s_client -connect twitter.com:443 -servername twitter.com`
3. Restart browser after installing CA
4. See [docs/SSL_SETUP.md](docs/SSL_SETUP.md) for device-specific instructions

### DNS Not Working

1. Verify your device is using the correct DNS server
2. Check dnsmasq/Pi-hole logs
3. Try flushing DNS cache on your device
4. Confirm DNS overrides are configured correctly

### Macvlan Networking Issues

1. Verify network interface name: `ip link show`
2. Check IP isn't already in use: `ping <nginx_ip>`
3. Ensure IP range doesn't overlap with DHCP
4. Docker host can't directly reach macvlan IPs (this is normal)

## Advanced Configuration

### Adding More Domains

Edit `nginx/conf.d/xcancel-redirect.conf` and add domains to the `server_name` directive:

```nginx
server_name twitter.com www.twitter.com x.com www.x.com t.co www.t.co additional.domain;
```

Also update:

- DNS overrides in Pi-hole/dnsmasq
- SSL certificate SANs (Subject Alternative Names)

### HTTP/3 (QUIC) Support

Already configured! Modern browsers will automatically use HTTP/3 when available. The redirect includes `Alt-Svc` headers to advertise HTTP/3 support.

### Custom Redirect Destination

Want to redirect somewhere other than xcancel.com?

Edit `nginx/conf.d/xcancel-redirect.conf` line 24:

```nginx
return 301 https://your-preferred-frontend.com$request_uri;
```

## Security Considerations

### Trust Implications

Installing a self-signed CA as a trusted root means:

- Your device will trust ANY certificate signed by that CA
- Keep your CA's private key SECURE
- Only install on devices you control
- Consider using a separate CA just for this purpose

### Scope of Interception

This setup ONLY intercepts domains you explicitly configure in DNS. It cannot intercept other domains without:

1. Adding them to DNS overrides
2. Adding them to nginx configuration
3. Adding them to your SSL certificate

### Network Security

- Macvlan networking exposes services directly on your LAN
- Consider firewall rules if running on untrusted networks
- The nginx container only listens on ports 80 and 443

## Why Not Just Block X/Twitter?

Blocking is simpler, but redirecting to xcancel lets you:

- Still view content shared in links
- Follow conversations without supporting the platform
- Make your own choice about engagement
- Avoid the "broken link" experience when people share tweets

If you prefer blocking, just use Pi-hole's blacklist feature instead of this setup.

## Contributing

Issues and pull requests welcome at [https://github.com/ryantenney/xcancel-forwarder](https://github.com/ryantenney/xcancel-forwarder)

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- [xcancel.com](https://xcancel.com) - Privacy-respecting Twitter frontend
- [Pi-hole](https://pi-hole.net/) - Network-wide ad blocking and DNS
- [nginx](https://nginx.org/) - High-performance web server

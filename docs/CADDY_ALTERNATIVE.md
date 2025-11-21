# Using Caddy Instead of nginx

Caddy is a simpler alternative to nginx with automatic HTTPS handling and a much more readable configuration format.

## Why Choose Caddy?

**Caddy is better if you want:**

- ✅ Simpler configuration (Caddyfile vs nginx.conf)
- ✅ Less to learn and understand
- ✅ Automatic HTTP/2 and HTTP/3 (QUIC) with zero config
- ✅ Built-in automatic HTTPS (though we use custom certs here)
- ✅ Modern defaults out of the box
- ✅ Single binary, easier troubleshooting

**nginx is better if you:**

- ✅ Need maximum performance (slightly faster than Caddy)
- ✅ Want widespread documentation and examples
- ✅ Need advanced features (complex routing, caching, etc.)
- ✅ Prefer battle-tested, ubiquitous technology
- ✅ Already know nginx

**For this project (simple redirect):** Either works great! Caddy is simpler.

## Configuration Comparison

### Caddy (4 lines)

```Caddyfile
twitter.com, www.twitter.com, x.com, www.x.com, t.co, www.t.co {
    tls /etc/caddy/ssl/twitter_bundle.pem /etc/caddy/ssl/twitter_key.pem
    redir https://xcancel.com{uri} permanent
}
```

### nginx (27 lines)

```nginx
server {
    ssl_protocols TLSv1.2 TLSv1.3;

    listen 443 ssl;
    listen 80;
    http2 on;

    listen 443 quic reuseport;

    server_name twitter.com www.twitter.com x.com www.x.com t.co www.t.co _;

    ssl_certificate     /etc/nginx/ssl/twitter_bundle.pem;
    ssl_certificate_key /etc/nginx/ssl/twitter_key.pem;

    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    add_header Alt-Svc 'h3=":443"; ma=86400' always;
    add_header X-Protocol $server_protocol always;

    location / {
        return 301 https://xcancel.com$request_uri;
    }
}
```

Both do the exact same thing. Caddy is just more concise.

## Setup Instructions

### 1. Use Caddy Docker Compose File

```bash
# Instead of docker-compose.yaml, use docker-compose.caddy.yaml
docker compose -f docker-compose.caddy.yaml up -d
```

### 2. Configuration Files

Caddy uses:

- `caddy/Caddyfile` - Main configuration (already configured)
- `caddy/ssl/` - SSL certificates (same as nginx)

### 3. SSL Certificates

**Same process as nginx!** Generate certificates using either:

- **mkcert** (simple): See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)
- **OpenSSL** (advanced): See [SSL_SETUP.md](SSL_SETUP.md)

Then copy to `caddy/ssl/`:

```bash
# mkcert example
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"
cp twitter.com+5.pem caddy/ssl/twitter_bundle.pem
cp twitter.com+5-key.pem caddy/ssl/twitter_key.pem
chmod 644 caddy/ssl/twitter_bundle.pem
chmod 600 caddy/ssl/twitter_key.pem
```

### 4. Start Caddy

```bash
# Start Caddy
docker compose -f docker-compose.caddy.yaml up -d

# Check logs
docker compose -f docker-compose.caddy.yaml logs -f caddy

# Check status
docker compose -f docker-compose.caddy.yaml ps
```

### 5. DNS Configuration

**Same as nginx!** Configure your DNS to point domains to Caddy's IP:

- Pi-hole: See [PIHOLE_SETUP.md](PIHOLE_SETUP.md)
- dnsmasq: See [DNSMASQ_SETUP.md](DNSMASQ_SETUP.md)
- Other: See [OTHER_DNS.md](OTHER_DNS.md)

## Testing

Use the same test script:

```bash
./scripts/test-redirect.sh
```

The script works with both nginx and Caddy - it tests DNS and redirects, not the server implementation.

## Networking Options

Same as nginx - choose bridge or macvlan:

**Bridge (default, simpler):**

```bash
# Uses ports 80 and 443 on host
docker compose -f docker-compose.caddy.yaml up -d
```

**Macvlan (for dedicated IP):**

1. Edit `docker-compose.caddy.yaml`
2. Uncomment `macvlan_lan` network
3. Uncomment `networks` section in caddy service
4. Comment out `ports` section
5. Configure `.env` with your network settings

## Managing Caddy

### View Logs

```bash
docker compose -f docker-compose.caddy.yaml logs -f caddy
```

### Restart

```bash
docker compose -f docker-compose.caddy.yaml restart caddy
```

### Reload Configuration

Caddy automatically reloads when Caddyfile changes! No restart needed if you mount the file as a volume (which we do).

Or manually:

```bash
docker compose -f docker-compose.caddy.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Stop Everything

```bash
docker compose -f docker-compose.caddy.yaml down
```

## Switching from nginx to Caddy

Already using nginx and want to switch?

```bash
# Stop nginx
docker compose down

# Start Caddy
docker compose -f docker-compose.caddy.yaml up -d

# Copy SSL certificates if in different location
cp nginx/ssl/twitter_bundle.pem caddy/ssl/
cp nginx/ssl/twitter_key.pem caddy/ssl/
```

DNS stays the same - just point to the new container's IP (or same IP if using same host).

## Switching from Caddy to nginx

```bash
# Stop Caddy
docker compose -f docker-compose.caddy.yaml down

# Start nginx
docker compose up -d

# Copy SSL certificates if needed
cp caddy/ssl/twitter_bundle.pem nginx/ssl/
cp caddy/ssl/twitter_key.pem nginx/ssl/
```

## Customizing Caddy Configuration

### Skip SSL (HTTP-only)

Edit `caddy/Caddyfile`:

```Caddyfile
twitter.com, www.twitter.com, x.com, www.x.com, t.co, www.t.co {
    # Remove the tls line
    redir https://xcancel.com{uri} permanent
}
```

### Change Redirect Destination

```Caddyfile
twitter.com, www.twitter.com, x.com, www.x.com, t.co, www.t.co {
    tls /etc/caddy/ssl/twitter_bundle.pem /etc/caddy/ssl/twitter_key.pem
    redir https://your-alternative-frontend.com{uri} permanent
}
```

### Add More Domains

```Caddyfile
twitter.com, www.twitter.com, x.com, www.x.com, t.co, www.t.co, additional.domain {
    tls /etc/caddy/ssl/twitter_bundle.pem /etc/caddy/ssl/twitter_key.pem
    redir https://xcancel.com{uri} permanent
}
```

### Enable Access Logging

```Caddyfile
twitter.com, www.twitter.com, x.com, www.x.com, t.co, www.t.co {
    tls /etc/caddy/ssl/twitter_bundle.pem /etc/caddy/ssl/twitter_key.pem

    log {
        output file /var/log/caddy/access.log
    }

    redir https://xcancel.com{uri} permanent
}
```

Then mount a log directory:

```yaml
volumes:
  - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
  - ./caddy/ssl:/etc/caddy/ssl:ro
  - ./caddy/logs:/var/log/caddy  # Add this
```

## Troubleshooting

### Caddy Won't Start

```bash
# Check logs
docker compose -f docker-compose.caddy.yaml logs caddy

# Common issues:
# - Port 80 or 443 already in use
# - Invalid Caddyfile syntax
# - SSL certificate files missing or wrong permissions
```

### Certificate Errors

```bash
# Verify certificates exist
ls -l caddy/ssl/

# Check permissions
# - .pem files: 644 (readable)
# - .key files: 600 (read by owner only)

# Test certificate
openssl x509 -in caddy/ssl/twitter_bundle.pem -text -noout
```

### Configuration Not Loading

```bash
# Validate Caddyfile syntax
docker compose -f docker-compose.caddy.yaml exec caddy caddy validate --config /etc/caddy/Caddyfile

# Reload configuration
docker compose -f docker-compose.caddy.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Port Already in Use

If you have nginx still running:

```bash
# Stop nginx first
docker compose down

# Then start Caddy
docker compose -f docker-compose.caddy.yaml up -d
```

Or use different ports in `.env`:

```bash
HTTP_PORT=8080
HTTPS_PORT=8443
```

## Performance Comparison

For this simple redirect use case:

- **nginx**: ~50,000 requests/second
- **Caddy**: ~45,000 requests/second

**Difference is negligible** for home/small network use. Both handle way more traffic than you'll ever see.

## Additional Caddy Features

Caddy has many features we're not using here:

- **Automatic HTTPS**: Can get Let's Encrypt certs automatically (not useful for local domains)
- **File serving**: Can serve static files
- **Reverse proxy**: Can proxy to backend services
- **Templates**: Dynamic content generation
- **API**: JSON API for configuration

For our simple redirect, we're just scratching the surface of what Caddy can do.

## Resources

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile)
- [Caddy Docker Image](https://hub.docker.com/_/caddy)

## Recommendation

**For this project:**

- **New users**: Use Caddy (simpler)
- **nginx experience**: Use nginx (familiar)
- **Learning**: Try both! (they coexist fine)

Both work perfectly for this redirect. The choice is personal preference.

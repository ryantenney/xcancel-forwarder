# SSL Certificates for Caddy

Place your SSL certificates in this directory:

- `twitter_bundle.pem` - Full certificate chain (certificate + CA chain)
- `twitter_key.pem` - Private key

**IMPORTANT**: Never commit actual certificates or private keys to git! They are excluded via `.gitignore`.

## Setup Instructions

Same certificates as nginx! Generate using either:

- **mkcert** (simple): See `docs/SSL_SETUP_MKCERT.md`
- **OpenSSL** (advanced): See `docs/SSL_SETUP.md`

Then copy them here:

```bash
# If you generated with mkcert
cp twitter.com+5.pem caddy/ssl/twitter_bundle.pem
cp twitter.com+5-key.pem caddy/ssl/twitter_key.pem

# Or if you used manual OpenSSL
cp ~/ssl-ca/twitter-bundle.pem caddy/ssl/
cp ~/ssl-ca/twitter-key.pem caddy/ssl/

# Set permissions
chmod 644 caddy/ssl/twitter_bundle.pem
chmod 600 caddy/ssl/twitter_key.pem
```

## Skip SSL?

To run HTTP-only (no HTTPS):

1. Edit `caddy/Caddyfile`
2. Comment out or remove the `tls` line
3. Restart: `docker compose -f docker-compose.caddy.yaml restart`

Caddy will only listen on port 80 and redirect HTTP traffic.

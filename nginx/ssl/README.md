# SSL Certificates

Place your SSL certificates in this directory:

- `twitter_bundle.pem` - Full certificate chain (certificate + CA chain)
- `twitter_key.pem` - Private key

**IMPORTANT**: Never commit actual certificates or private keys to git! They are excluded via `.gitignore`.

## Required Files

Your nginx configuration expects:

- `twitter_bundle.pem` - Certificate + CA chain
- `twitter_key.pem` - Private key

## Setup Instructions

See `docs/SSL_SETUP.md` for complete instructions on:

1. Creating a self-signed Certificate Authority
2. Generating certificates for twitter.com/x.com
3. Installing the CA on your devices
4. Placing certificates in this directory

## Security Note

The certificates in this directory allow your local nginx server to intercept HTTPS traffic to twitter.com and x.com domains. This only works because you've configured DNS on your network to point these domains to your nginx server, and you've installed your self-signed CA as a trusted root on your devices.

Without the DNS override, these certificates have no effect. Without the trusted CA, browsers will show security warnings.

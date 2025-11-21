# SSL Certificate Setup

This guide walks through creating a self-signed Certificate Authority (CA) and generating SSL certificates for intercepting HTTPS traffic to twitter.com/x.com.

## Overview

To intercept HTTPS traffic without browser warnings, you need:

1. **Certificate Authority (CA)** - Your own trusted root certificate
2. **Server Certificate** - Signed by your CA for twitter.com, x.com, t.co
3. **CA Installation** - Install CA as trusted on all your devices

## Security Warning

Creating and installing a self-signed CA means:

- Your device will trust ANY certificate signed by that CA
- Keep your CA private key EXTREMELY secure
- Only install on devices you personally control
- Consider using a dedicated CA just for this purpose

If your CA's private key is compromised, an attacker could generate trusted certificates for any domain on your devices.

## Part 1: Create Your Certificate Authority

### 1.1 Generate CA Private Key

```bash
# Create a secure directory for your CA
mkdir -p ~/ssl-ca
cd ~/ssl-ca
chmod 700 ~/ssl-ca

# Generate CA private key (keep this VERY secure!)
openssl genrsa -out ca-key.pem 4096
chmod 400 ca-key.pem
```

### 1.2 Create CA Certificate

Create a config file for your CA (`ca.conf`):

```ini
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = Your State
L = Your City
O = Your Name
CN = Your Name Personal CA
emailAddress = your-email@example.com

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
```

Generate the CA certificate:

```bash
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem -config ca.conf
```

This creates a CA certificate valid for 10 years.

### 1.3 Verify CA Certificate

```bash
openssl x509 -in ca-cert.pem -text -noout
```

You should see:

- `CA:TRUE` in Basic Constraints
- Your organization name
- 10-year validity period

## Part 2: Generate Server Certificate for Twitter/X

### 2.1 Create Certificate Signing Request (CSR)

Create a config file (`twitter.conf`):

```ini
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Your State
L = Your City
O = Local Intercept
OU = Proxy
CN = twitter.com

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = twitter.com
DNS.2 = www.twitter.com
DNS.3 = x.com
DNS.4 = www.x.com
DNS.5 = t.co
DNS.6 = www.t.co
DNS.7 = *.twitter.com
DNS.8 = *.x.com
```

Generate private key and CSR:

```bash
# Generate server private key
openssl genrsa -out twitter-key.pem 2048

# Generate CSR
openssl req -new -key twitter-key.pem -out twitter.csr -config twitter.conf
```

### 2.2 Sign Certificate with Your CA

Create signing config (`signing.conf`):

```ini
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = twitter.com
DNS.2 = www.twitter.com
DNS.3 = x.com
DNS.4 = www.x.com
DNS.5 = t.co
DNS.6 = www.t.co
DNS.7 = *.twitter.com
DNS.8 = *.x.com
```

Sign the certificate:

```bash
openssl x509 -req -in twitter.csr -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out twitter-cert.pem -days 825 -sha256 \
  -extfile signing.conf -extensions v3_req
```

Note: 825 days (about 2 years) is the maximum validity accepted by modern browsers.

### 2.3 Create Certificate Bundle

nginx needs the full certificate chain:

```bash
cat twitter-cert.pem ca-cert.pem > twitter-bundle.pem
```

### 2.4 Verify Server Certificate

```bash
# Check certificate details
openssl x509 -in twitter-cert.pem -text -noout

# Verify certificate chain
openssl verify -CAfile ca-cert.pem twitter-cert.pem
```

Should output: `twitter-cert.pem: OK`

## Part 3: Install Certificates in nginx

Copy certificates to your xcancel-forwarder directory:

```bash
cd /path/to/xcancel-forwarder

# Copy server certificate and key
cp ~/ssl-ca/twitter-bundle.pem nginx/ssl/
cp ~/ssl-ca/twitter-key.pem nginx/ssl/

# Set secure permissions
chmod 644 nginx/ssl/twitter-bundle.pem
chmod 600 nginx/ssl/twitter-key.pem
```

Verify nginx configuration references these files correctly (should already be set):

```nginx
ssl_certificate     /etc/nginx/ssl/twitter_bundle.pem;
ssl_certificate_key /etc/nginx/ssl/twitter_key.pem;
```

## Part 4: Install CA on Your Devices

You need to install `ca-cert.pem` as a trusted root CA on every device that will access the redirected sites.

### macOS

```bash
# GUI method
open ca-cert.pem
# Keychain Access will open, double-click certificate, set "Always Trust"

# Command line method
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca-cert.pem
```

Verify:

1. Open Keychain Access
2. Select "System" keychain
3. Find your CA certificate
4. Double-click and verify "This certificate is marked as trusted"

### iOS/iPadOS

1. Email `ca-cert.pem` to yourself or host it on a web server
2. Open the file on your iOS device
3. Go to Settings → General → VPN & Device Management
4. Tap on your CA profile and install it
5. Go to Settings → General → About → Certificate Trust Settings
6. Enable full trust for your CA

### Android

1. Transfer `ca-cert.pem` to your device
2. Settings → Security → Encryption & credentials
3. Install from storage → CA certificate
4. Navigate to and select `ca-cert.pem`
5. Name it something recognizable (e.g., "Twitter Redirect CA")

Note: User-installed CAs are not trusted by all apps on Android. Some apps may still show warnings.

### Windows

```powershell
# Run PowerShell as Administrator
certutil -addstore -f "ROOT" ca-cert.pem
```

Or use GUI:

1. Right-click `ca-cert.pem` → Install Certificate
2. Store Location: Local Machine
3. Place certificate in: Trusted Root Certification Authorities

### Linux (Debian/Ubuntu)

```bash
# Copy CA to system certificates
sudo cp ca-cert.pem /usr/local/share/ca-certificates/twitter-redirect-ca.crt

# Update CA store
sudo update-ca-certificates
```

### Linux (Arch/Manjaro)

```bash
sudo trust anchor --store ca-cert.pem
```

### Firefox (All Platforms)

Firefox uses its own certificate store:

1. Open Firefox → Settings → Privacy & Security
2. Scroll to "Certificates" → View Certificates
3. Authorities tab → Import
4. Select `ca-cert.pem`
5. Check "Trust this CA to identify websites"

### Chrome/Edge (Windows/Linux)

Chrome and Edge use system certificates, so installing via OS methods (above) is sufficient.

## Part 5: Test Certificate Installation

### Test DNS Resolution

```bash
nslookup twitter.com
# Should return your nginx server IP
```

### Test HTTPS Connection

```bash
# Should show your certificate
openssl s_client -connect twitter.com:443 -servername twitter.com < /dev/null

# Look for:
# - Issuer: Your CA name
# - Subject: CN=twitter.com
# - Verify return code: 0 (ok)
```

### Test in Browser

1. Navigate to `https://twitter.com`
2. Should redirect to xcancel.com with NO security warnings
3. Click the padlock icon
4. Certificate should show as issued by your CA

If you see warnings:

- CA not installed correctly
- Browser hasn't refreshed certificate store (restart browser)
- DNS not pointing to your nginx server

## Certificate Renewal

Your server certificate expires in 825 days. To renew:

```bash
cd ~/ssl-ca

# Generate new CSR with same key (or generate new key)
openssl req -new -key twitter-key.pem -out twitter-new.csr -config twitter.conf

# Sign with your CA
openssl x509 -req -in twitter-new.csr -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out twitter-new-cert.pem -days 825 -sha256 \
  -extfile signing.conf -extensions v3_req

# Create new bundle
cat twitter-new-cert.pem ca-cert.pem > twitter-new-bundle.pem

# Copy to nginx
cp twitter-new-bundle.pem /path/to/xcancel-forwarder/nginx/ssl/twitter-bundle.pem

# Reload nginx
docker compose restart nginx
```

No need to reinstall CA on devices unless you regenerated the CA certificate.

## Troubleshooting

### "Certificate not trusted" in Browser

1. Verify CA is installed: Check system keychain/certificate store
2. Restart browser after installing CA
3. Check certificate chain: `openssl verify -CAfile ca-cert.pem twitter-cert.pem`
4. Verify Subject Alternative Names include the domain you're accessing

### Certificate Works on Some Devices, Not Others

Each device needs the CA installed independently. Don't forget:

- Mobile devices (iOS/Android)
- Other computers
- Firefox (separate certificate store)

### "Certificate is for wrong domain"

Verify Subject Alternative Names (SANs) include all domains:

```bash
openssl x509 -in twitter-bundle.pem -text -noout | grep -A 10 "Subject Alternative Name"
```

Should list: twitter.com, x.com, t.co, and their variants.

## Security Best Practices

1. **Protect CA Private Key**
   ```bash
   chmod 400 ca-key.pem
   # Store backup on encrypted USB drive, not cloud storage
   ```

2. **Separate CA for This Purpose**
   - Don't reuse CAs across different interception projects
   - Makes revocation easier if needed

3. **Document What You've Done**
   - Keep notes on which devices have your CA installed
   - Remember to uninstall if you stop using this setup

4. **Regular Audits**
   - Periodically check which devices trust your CA
   - Ensure CA private key is still secure

5. **Revocation Plan**
   - If CA key is compromised, uninstall from all devices immediately
   - Generate new CA and server certificates

## Alternative: Skip SSL

If certificate management is too complex, you can skip SSL:

1. Edit `nginx/conf.d/xcancel-redirect.conf`
2. Remove or comment out lines related to SSL:
   - `ssl_protocols`
   - `listen 443 ssl`
   - `http2 on`
   - `listen 443 quic`
   - `ssl_certificate` and `ssl_certificate_key`
   - `ssl_session_cache` and `ssl_session_timeout`
   - `add_header Alt-Svc` and `add_header X-Protocol`

3. Keep only:
   ```nginx
   server {
       listen 80;
       server_name twitter.com www.twitter.com x.com www.x.com t.co www.t.co _;

       location / {
           return 301 https://xcancel.com$request_uri;
       }
   }
   ```

This will work for HTTP-only traffic. HTTPS links will show browser warnings.

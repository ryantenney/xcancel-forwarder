# Quick Start Guide

**Detailed manual setup for xcancel-forwarder**

This guide walks through manual setup to help you understand how each component works. For faster automated setup, use the [Web Wizard](https://ryantenney.github.io/xcancel-forwarder/setup-wizard.html) or CLI wizard (`python3 scripts/setup-wizard.py`).

**Time**: 20-30 minutes • **Difficulty**: Medium

## Prerequisites

Before starting, ensure you have:

- [ ] Docker and Docker Compose installed
- [ ] Basic command line familiarity
- [ ] One of these DNS control methods:
  - Existing Pi-hole installation
  - Ability to run dnsmasq (included)
  - Router admin access
  - Ability to edit hosts files on devices

- [ ] Network information:
  - Your local network subnet (e.g., 192.168.1.0/24)
  - An available IP address for nginx (e.g., 192.168.1.100)
  - Your default gateway IP (e.g., 192.168.1.1)

## Overview

You'll complete these steps:

1. Clone repository and configure environment
2. Choose networking mode (bridge or macvlan)
3. Set up SSL certificates (optional but recommended)
4. Start nginx container
5. Configure DNS (Pi-hole, dnsmasq, router, or hosts file)
6. Test the setup

## Step 1: Clone and Configure

Clone the repository and set up basic configuration:

```bash
# Clone repository
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Create environment file from template
cp .env.example .env

# Edit environment file
vim .env
# Or use your preferred editor: nano .env, code .env, etc.
```

### Environment Configuration

Edit `.env` and set these values based on your networking choice:

**For bridge networking (simpler)**:

- Leave default values as-is
- You'll configure DNS to point to your Docker host's IP

**For macvlan networking (recommended for Pi-hole/dnsmasq)**:

```bash
# Set nginx IP address (choose unused IP on your LAN)
NGINX_IP=192.168.1.100

# Set network interface (find with: ip link show)
LAN_INTERFACE=eth0

# Set your network subnet
LAN_SUBNET=192.168.1.0/24

# Set your gateway IP
LAN_GATEWAY=192.168.1.1

# If using dnsmasq, set its IP too
DNSMASQ_IP=192.168.1.101
```

**Finding your network interface**:

```bash
# Linux/macOS
ip link show
# Look for your active interface: eth0, enp0s3, wlan0, etc.

# macOS alternative
ifconfig
# Look for en0, en1, etc.
```

## Step 2: Choose Networking Mode

### Option A: Bridge Networking (Default)

**When to use**: Simplest setup, DNS server not on Docker host

**Configuration**: Already configured in `docker-compose.yaml`

**DNS setup later**: Point DNS to your **Docker host IP**

**Pros**: Simple, standard Docker networking

**Cons**: Uses host's ports 80/443, potential conflicts

### Option B: Macvlan Networking (Recommended)

**When to use**: Pi-hole/dnsmasq on same host, want dedicated IP

**Configuration**: Edit `docker-compose.yaml`:

1. **Uncomment the macvlan network section** (bottom of file):

```yaml
networks:
  macvlan_lan:
    driver: macvlan
    driver_opts:
      parent: ${LAN_INTERFACE}
    ipam:
      config:
        - subnet: ${LAN_SUBNET}
          gateway: ${LAN_GATEWAY}
```

2. **Uncomment the networks section in nginx service**:

```yaml
services:
  nginx:
    # ... existing config ...
    networks:
      macvlan_lan:
        ipv4_address: ${NGINX_IP}
```

3. **Comment out the ports section in nginx service**:

```yaml
# ports:
#   - "${NGINX_HOST_IP:-0.0.0.0}:80:80"
#   - "${NGINX_HOST_IP:-0.0.0.0}:443:443"
```

4. **If using dnsmasq, uncomment its network config**:

```yaml
  dnsmasq:
    # ... existing config ...
    networks:
      macvlan_lan:
        ipv4_address: ${DNSMASQ_IP}
```

**DNS setup later**: Point DNS to your **nginx container IP** (from `.env`)

**Pros**: Dedicated IP, cleaner network separation

**Cons**: Docker host can't directly reach container (this is normal)

## Step 3: SSL Certificates (Optional but Recommended)

SSL certificates allow HTTPS interception without browser warnings.

**Skip SSL?** Comment out SSL-related lines in `nginx/conf.d/xcancel-redirect.conf` (lines 3, 5, 9, 13-18, 20-21). HTTP-only redirect will still work.

### Option A: mkcert (Recommended)

Automatic CA installation and certificate generation.

**Install mkcert**:

```bash
# macOS
brew install mkcert

# Linux (Debian/Ubuntu)
sudo apt install mkcert

# Linux (Fedora)
sudo dnf install mkcert

# Or install from source
# See: https://github.com/FiloSottile/mkcert
```

**Generate certificates**:

```bash
# Install local CA
mkcert -install

# Generate certificates for Twitter/X domains
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Move certificates to nginx ssl directory
mv twitter.com+5.pem nginx/ssl/server.crt
mv twitter.com+5-key.pem nginx/ssl/server.key

# Or for Caddy
cp twitter.com+5.pem caddy/ssl/server.crt
cp twitter.com+5-key.pem caddy/ssl/server.key
```

**Install CA on other devices**: See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)

### Option B: Manual OpenSSL (Advanced)

Full control over certificate parameters.

**Create Certificate Authority**:

```bash
# Create CA private key
openssl genrsa -out ca.key 4096

# Create CA certificate (valid 10 years)
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/C=US/ST=State/L=City/O=Home/OU=CA/CN=Home CA"
```

**Generate Server Certificate**:

```bash
# Create server private key
openssl genrsa -out server.key 2048

# Create certificate request
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Home/OU=Proxy/CN=twitter.com"

# Create extensions file for SANs
cat > server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = twitter.com
DNS.2 = *.twitter.com
DNS.3 = x.com
DNS.4 = *.x.com
DNS.5 = t.co
DNS.6 = *.t.co
EOF

# Sign certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 825 -sha256 -extfile server.ext

# Move to nginx directory
mv server.crt nginx/ssl/
mv server.key nginx/ssl/

# Keep CA for device installation
# ca.crt needs to be installed on each device
```

**Install CA on devices**: See [SSL_SETUP.md](SSL_SETUP.md)

## Step 4: Start nginx

Start the nginx container:

```bash
# Start nginx with default (nginx) configuration
docker compose up -d

# Or start with Caddy
docker compose -f docker-compose.caddy.yaml up -d

# Check status
docker compose ps

# View logs
docker compose logs -f nginx
```

**Expected output**:

```
[+] Running 1/1
 ✔ Container xcancel-forwarder-nginx-1  Started
```

**Verify nginx is running**:

```bash
# Should show nginx container running
docker compose ps

# Test direct connection (replace with your nginx IP)
curl -I http://192.168.1.100
# Should return: HTTP/1.1 301 Moved Permanently
```

## Step 5: Configure DNS

Choose **ONE** of these DNS methods:

### Option A: Pi-hole

**Prerequisites**: Existing Pi-hole installation

**Method 1: Web UI (Recommended)**:

1. Open Pi-hole admin: `http://pi.hole/admin`
2. Login with your password
3. Navigate to **Local DNS** → **DNS Records**
4. Add these A records:

```
twitter.com → 192.168.1.100  (your nginx IP)
x.com → 192.168.1.100
t.co → 192.168.1.100
```

5. Add these CNAME records:

```
*.twitter.com → twitter.com
*.x.com → x.com
```

**Method 2: Configuration File**:

```bash
# SSH to Pi-hole host
ssh pi@pihole.local

# Edit custom DNS file
sudo nano /etc/dnsmasq.d/02-custom.conf

# Add these lines:
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100

# Save and restart
pihole restartdns
```

**Verify**:

```bash
nslookup twitter.com
# Should return: 192.168.1.100
```

**Full guide**: [PIHOLE_SETUP.md](PIHOLE_SETUP.md)

### Option B: dnsmasq (Included)

**When to use**: Want dedicated DNS server, don't have Pi-hole

**Enable dnsmasq**:

1. Edit `docker-compose.yaml`
2. Uncomment the `dnsmasq` service section
3. Uncomment macvlan networking for dnsmasq
4. Set `DNSMASQ_IP` in `.env`

**Configure dnsmasq**:

```bash
# Edit dnsmasq configuration
vim dnsmasq/dnsmasq.conf

# Add your nginx IP to these lines:
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100

# Set upstream DNS server
server=1.1.1.1
```

**Start dnsmasq**:

```bash
docker compose up -d dnsmasq

# Check logs
docker compose logs dnsmasq
```

**Configure devices to use dnsmasq**: Point device DNS to `192.168.1.101` (your dnsmasq IP)

**Full guide**: [DNSMASQ_SETUP.md](DNSMASQ_SETUP.md)

### Option C: Router DNS

**When to use**: Can access router, want network-wide

**Steps** (vary by router):

1. Access router admin panel (usually 192.168.1.1)
2. Find DNS settings (often under DHCP/DNS or Advanced)
3. Add static DNS entries or host overrides:

```
twitter.com → 192.168.1.100
*.twitter.com → 192.168.1.100
x.com → 192.168.1.100
*.x.com → 192.168.1.100
t.co → 192.168.1.100
```

4. Save and reboot router if needed

**Note**: Not all routers support wildcard DNS entries.

**Full guide**: [OTHER_DNS.md](OTHER_DNS.md)

### Option D: Hosts File (Per-Device)

**When to use**: Single device, can't run DNS server

**Linux/macOS**:

```bash
sudo vim /etc/hosts

# Add these lines:
192.168.1.100 twitter.com www.twitter.com
192.168.1.100 x.com www.x.com
192.168.1.100 t.co
```

**Windows**:

```powershell
# Open as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add these lines:
192.168.1.100 twitter.com www.twitter.com
192.168.1.100 x.com www.x.com
192.168.1.100 t.co
```

**Limitations**: Wildcard subdomains don't work in hosts file.

**Full guide**: [OTHER_DNS.md](OTHER_DNS.md)

## Step 6: Test the Setup

Run these tests to verify everything works:

### Test 1: DNS Resolution

```bash
# Should return your nginx IP (192.168.1.100)
nslookup twitter.com

# Also test other domains
nslookup x.com
nslookup t.co

# Test wildcard (if configured)
nslookup mobile.twitter.com
```

**Expected**: All return your nginx IP

### Test 2: HTTP Redirect

```bash
# Should show 301 redirect to xcancel.com
curl -I http://twitter.com

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/
```

### Test 3: HTTPS Redirect (If SSL Configured)

```bash
# Should show 301 redirect to xcancel.com
curl -I https://twitter.com

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/
```

### Test 4: Browser Test

1. Open browser
2. Visit `http://twitter.com`
3. Should redirect to xcancel.com
4. If SSL configured, try `https://twitter.com` - should work without warnings

### Test 5: Wildcard Subdomains

```bash
# Test subdomains
curl -I http://mobile.twitter.com
curl -I http://www.x.com
```

**Expected**: Both redirect to xcancel.com

## Troubleshooting

### DNS Not Resolving

**Symptom**: `nslookup twitter.com` returns wrong IP

**Fixes**:

```bash
# Check what DNS server you're using
cat /etc/resolv.conf  # Linux/macOS
ipconfig /all          # Windows

# Flush DNS cache (client)
sudo dscacheutil -flushcache  # macOS
sudo systemd-resolve --flush-caches  # Linux
ipconfig /flushdns  # Windows

# Restart DNS server
pihole restartdns  # Pi-hole
docker compose restart dnsmasq  # dnsmasq

# Test specific DNS server
dig @192.168.1.101 twitter.com
```

### Redirect Not Working

**Symptom**: DNS works but redirect doesn't happen

**Fixes**:

```bash
# Check nginx is running
docker compose ps

# View logs for errors
docker compose logs nginx

# Test direct connection to nginx
curl -I http://192.168.1.100

# Check nginx config syntax
docker compose exec nginx nginx -t

# Restart nginx
docker compose restart nginx
```

### SSL Certificate Warnings

**Symptom**: Browser shows "Your connection is not private"

**Fixes**:

- Verify CA certificate is installed on device
- Check certificate includes correct domains:

```bash
openssl s_client -connect twitter.com:443 -servername twitter.com 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

- Restart browser after installing CA
- Clear browser cache
- See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md) or [SSL_SETUP.md](SSL_SETUP.md)

### Macvlan Container Not Reachable

**Symptom**: Can't reach nginx from Docker host

**This is normal**: Docker host cannot directly reach macvlan containers due to network isolation.

**Verify from another device**:

```bash
# From laptop/phone on same network
curl -I http://192.168.1.100
```

**If other devices can't reach it**:

- Check IP not already in use: `ping 192.168.1.100`
- Verify macvlan network: `docker network ls`
- Check firewall rules on Docker host

### Browser Cache Issues

**Symptom**: Old behavior persists after changes

**Fixes**:

```bash
# Clear browser DNS cache
# Chrome/Edge: chrome://net-internals/#dns → Clear host cache
# Firefox: about:networking#dns → Clear DNS Cache

# Or try private/incognito window

# Clear browser cache completely
# Chrome: Ctrl+Shift+Delete → Clear browsing data
# Firefox: Ctrl+Shift+Delete → Clear data
```

## Next Steps

### Monitor Logs

Watch for redirect activity:

```bash
# Follow nginx access logs
docker compose logs -f nginx

# Show recent access
docker compose exec nginx tail /var/log/nginx/access.log
```

### Install CA on Other Devices

If using SSL, install CA on:

- [ ] Other computers
- [ ] Mobile devices (iOS/Android)
- [ ] Tablets
- [ ] Smart TVs (if applicable)

See device-specific instructions in [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)

### Maintenance

```bash
# Update nginx image
docker compose pull
docker compose up -d

# Restart services
docker compose restart

# View logs
docker compose logs -f

# Stop everything
docker compose down
```

### Add More Domains

Want to redirect other services? Edit `nginx/conf.d/xcancel-redirect.conf`:

1. Add domains to `server_name` directive
2. Add domains to DNS configuration
3. Add domains to SSL certificate (if using SSL)
4. Restart: `docker compose restart nginx`

## Additional Resources

- **[DECISION_GUIDE.md](DECISION_GUIDE.md)** - Help choosing setup options
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands cheat sheet
- **[TESTING.md](TESTING.md)** - Comprehensive testing procedures
- **[SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)** - Easy SSL with mkcert
- **[SSL_SETUP.md](SSL_SETUP.md)** - Advanced SSL with OpenSSL
- **[PIHOLE_SETUP.md](PIHOLE_SETUP.md)** - Detailed Pi-hole configuration
- **[DNSMASQ_SETUP.md](DNSMASQ_SETUP.md)** - Detailed dnsmasq configuration
- **[OTHER_DNS.md](OTHER_DNS.md)** - Router and alternative DNS options
- **[CADDY_ALTERNATIVE.md](CADDY_ALTERNATIVE.md)** - Using Caddy web server

## Getting Help

If you encounter issues:

1. Check [TESTING.md](TESTING.md) comprehensive troubleshooting section
2. Review logs: `docker compose logs -f nginx`
3. Verify each step independently
4. Search GitHub issues: [github.com/ryantenney/xcancel-forwarder/issues](https://github.com/ryantenney/xcancel-forwarder/issues)
5. Open a new issue with logs and configuration details

**Most common fix**: Clear all DNS caches (client + browser + DNS server) and try again.

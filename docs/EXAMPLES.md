# Real-World Setup Examples

Complete end-to-end walkthroughs for common xcancel-forwarder configurations.

Each example includes the full setup process, verification steps, and typical issues you might encounter.

## Example Index

- [Example 1: Pi-hole + nginx + macOS/iOS](#example-1-pi-hole--nginx--macosios)
- [Example 2: dnsmasq + Caddy + Home Network](#example-2-dnsmasq--caddy--home-network)
- [Example 3: Router DNS + nginx + Android](#example-3-router-dns--nginx--android)
- [Example 4: Hosts File Only (No Docker DNS)](#example-4-hosts-file-only-no-docker-dns)
- [Example 5: Existing nginx Reverse Proxy](#example-5-existing-nginx-reverse-proxy)

---

## Example 1: Pi-hole + nginx + macOS/iOS

**Scenario**: You have Pi-hole running on a Raspberry Pi. You want network-wide redirect that works on your Mac and iPhone.

**Your Network**:

- Pi-hole: `192.168.1.2`
- Docker host (laptop): `192.168.1.10`
- nginx IP (macvlan): `192.168.1.100`
- Network: `192.168.1.0/24`, gateway `192.168.1.1`

### Step 1: Set Up nginx

```bash
# On your laptop
cd ~/
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Create environment file
cp .env.example .env
vim .env
```

Edit `.env`:

```bash
NGINX_IP=192.168.1.100
LAN_INTERFACE=en0  # Your Mac's interface
LAN_SUBNET=192.168.1.0/24
LAN_GATEWAY=192.168.1.1
```

### Step 2: Enable macvlan

Edit `docker-compose.yaml`:

- Uncomment macvlan network section (bottom)
- Uncomment networks section in nginx service
- Comment out ports section in nginx service

### Step 3: Set Up SSL (mkcert)

```bash
# Install mkcert
brew install mkcert

# Create and install CA
mkcert -install

# Generate certificates
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Move to nginx directory
mv twitter.com+5.pem nginx/ssl/server.crt
mv twitter.com+5-key.pem nginx/ssl/server.key
```

### Step 4: Start nginx

```bash
docker compose up -d

# Check status
docker compose ps
# Should show nginx Up/healthy

# Test from another device (not Mac - macvlan limitation)
# From iPhone:
curl http://192.168.1.100
# Should return 301 to xcancel.com
```

### Step 5: Configure Pi-hole

1. Open Pi-hole web interface: `http://192.168.1.2/admin`
2. Login with your password
3. Go to **Local DNS** → **DNS Records**
4. Add these A records:
   - `twitter.com` → `192.168.1.100`
   - `x.com` → `192.168.1.100`
   - `t.co` → `192.168.1.100`
5. Add CNAME records:
   - `*.twitter.com` → `twitter.com`
   - `*.x.com` → `x.com`
6. Click **Add** for each

### Step 6: Verify DNS

```bash
# Test from Mac
nslookup twitter.com
# Should return 192.168.1.100

# Test other domains
nslookup google.com
# Should return real IP (Pi-hole forwarding)
```

### Step 7: Install CA on macOS

```bash
# mkcert already installed it
# Verify:
security find-certificate -c "mkcert" -a
# Should show your CA
```

### Step 8: Test on macOS

1. Open Safari
2. Visit `https://twitter.com`
3. Should redirect to xcancel.com
4. No security warnings

### Step 9: Install CA on iPhone

1. On Mac, find CA file:

```bash
mkcert -CAROOT
# Shows location, usually: /Users/yourname/Library/Application Support/mkcert
```

2. Email the `rootCA.pem` file to yourself
3. On iPhone, open email and tap attachment
4. Follow prompts to install profile
5. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
6. Enable trust for your CA

### Step 10: Test on iPhone

1. Open Safari
2. Visit `https://twitter.com`
3. Should redirect to xcancel.com
4. No security warnings

### Common Issues

**Mac can't test redirect**:

- Normal - macvlan prevents Docker host from reaching container
- Test from iPhone or another device

**iPhone shows certificate warning**:

- CA not trusted - check Settings → Certificate Trust Settings
- Make sure you enabled trust (step 9)

**iPhone not redirecting**:

- Clear DNS cache: Airplane mode for 5 seconds
- Verify iPhone using Pi-hole DNS: Settings → Wi-Fi → DNS should be 192.168.1.2

---

## Example 2: dnsmasq + Caddy + Home Network

**Scenario**: No existing DNS server. You want simplest setup with Caddy for entire home network.

**Your Network**:

- Docker host: `192.168.1.50`
- nginx IP (macvlan): `192.168.1.100`
- dnsmasq IP (macvlan): `192.168.1.101`
- Network: `192.168.1.0/24`, gateway `192.168.1.1`
- Router: `192.168.1.1`

### Step 1: Set Up Project

```bash
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

cp .env.example .env
vim .env
```

Edit `.env`:

```bash
LAN_INTERFACE=eth0
LAN_SUBNET=192.168.1.0/24
LAN_GATEWAY=192.168.1.1
NGINX_IP=192.168.1.100
DNSMASQ_IP=192.168.1.101
```

### Step 2: Configure dnsmasq

Edit `dnsmasq/dnsmasq.conf`:

```bash
# Update nginx IP
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100

# Upstream DNS (Cloudflare)
server=1.1.1.1
server=1.0.0.1
```

### Step 3: Enable macvlan and dnsmasq

Edit `docker-compose.caddy.yaml`:

- Uncomment macvlan network section
- Uncomment networks section in caddy service
- Comment out ports section in caddy service
- Uncomment entire dnsmasq service

### Step 4: Set Up SSL (mkcert)

```bash
# Install mkcert (Linux example)
sudo apt install mkcert

# Create and install CA
mkcert -install

# Generate certificates
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Move to Caddy directory
mv twitter.com+5.pem caddy/ssl/server.crt
mv twitter.com+5-key.pem caddy/ssl/server.key
```

### Step 5: Start Services

```bash
docker compose -f docker-compose.caddy.yaml up -d

# Check both containers
docker compose ps
# Should show caddy and dnsmasq both Up
```

### Step 6: Test from Another Device

```bash
# From another computer/phone on network
nslookup twitter.com 192.168.1.101
# Should return 192.168.1.100

curl -I http://192.168.1.100
# Should return 301 to xcancel.com
```

### Step 7: Configure Router DHCP

1. Access router admin: `http://192.168.1.1`
2. Find DHCP settings
3. Set Primary DNS: `192.168.1.101` (your dnsmasq)
4. Set Secondary DNS: `1.1.1.1` (fallback)
5. Save and reboot router

### Step 8: Reconnect Devices

All devices need to get new DHCP lease:

- **Computers**: Reconnect to Wi-Fi or renew DHCP
- **Phones**: Forget network and reconnect
- **Smart TVs**: Reboot

### Step 9: Install CA on All Devices

**Windows**:

1. Copy `rootCA.pem` from Docker host
2. Double-click certificate
3. Install → Local Machine → Place in Trusted Root Certification Authorities

**Linux**:

```bash
sudo cp rootCA.pem /usr/local/share/ca-certificates/xcancel-ca.crt
sudo update-ca-certificates
```

**Android**:

1. Copy `rootCA.pem` to phone
2. Settings → Security → Install from storage
3. Select file

**iOS**: See Example 1 step 9

### Step 10: Network-Wide Testing

Test from multiple devices:

```bash
# Each device
nslookup twitter.com
# Should return 192.168.1.100

# Browser test
# Visit https://twitter.com
# Should redirect without warnings
```

### Common Issues

**Some devices still using old DNS**:

- Wait for DHCP lease renewal (usually 24 hours)
- Manually reconnect devices to Wi-Fi
- Reboot devices

**DNS not working from Docker host**:

- Normal - macvlan isolation
- Test from other devices

**dnsmasq port 53 conflict**:

- Check for systemd-resolved: `sudo systemctl stop systemd-resolved`
- Or run dnsmasq on different host

---

## Example 3: Router DNS + nginx + Android

**Scenario**: You can access your router's DNS settings. Simple setup for Android phone.

**Your Network**:

- Docker host: `192.168.0.5`
- nginx (bridge mode): Docker host IP `192.168.0.5`
- Network: `192.168.0.0/24`
- Router: `192.168.0.1` (supports static DNS)

### Step 1: Simple Docker Setup

```bash
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Use default .env (bridge mode)
# No changes needed for bridge networking
```

### Step 2: Skip SSL (HTTP Only)

```bash
# Edit nginx/conf.d/xcancel-redirect.conf
# Comment out SSL-related lines:
# - Lines 3, 5, 9, 13-18, 20-21

# Or just remove the HTTPS server block
```

### Step 3: Start nginx

```bash
docker compose up -d

# Test
curl -I http://localhost
# Should return 301 to xcancel.com
```

### Step 4: Configure Router DNS

1. Access router: `http://192.168.0.1`
2. Find **DNS Settings** or **Static DNS**
3. Add entries:
   - `twitter.com` → `192.168.0.5`
   - `x.com` → `192.168.0.5`
   - `t.co` → `192.168.0.5`

**Note**: Not all routers support this. If yours doesn't, use dnsmasq instead.

### Step 5: Configure Android DNS

Since router DNS may not support wildcards:

1. **Settings** → **Network & Internet** → **Wi-Fi**
2. Tap your network name
3. **Advanced** → **IP Settings** → **Static**
4. Set DNS 1: Your router (for everything else): `192.168.0.1`
5. Save

Alternative: Leave Wi-Fi on DHCP and edit `/etc/hosts` (requires root).

### Step 6: Clear Android DNS Cache

1. Enable Airplane Mode
2. Wait 5 seconds
3. Disable Airplane Mode

### Step 7: Test on Android

1. Open Chrome
2. Visit `http://twitter.com` (note: HTTP, not HTTPS)
3. Should redirect to xcancel.com
4. HTTPS will show warning (expected - no SSL)

### Limitations

**HTTP only**:

- https://twitter.com shows warning
- Most Twitter links use HTTPS
- For full HTTPS support, add SSL certificates

**Manual DNS on Android**:

- Only affects this Wi-Fi network
- Need to repeat for other networks
- Or use dnsmasq for network-wide

### Upgrade Path

To add HTTPS:

1. Set up mkcert (see Example 1)
2. Uncomment SSL config in nginx
3. Install CA on Android
4. Restart nginx

---

## Example 4: Hosts File Only (No Docker DNS)

**Scenario**: Single laptop, don't want to run DNS server, simplest possible setup.

**Your Setup**:

- Laptop running Docker
- Bridge networking (default)
- HTTP only (no SSL)

### Step 1: Minimal Docker Setup

```bash
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Use all defaults - no .env changes needed
```

### Step 2: Skip SSL

```bash
# Edit nginx/conf.d/xcancel-redirect.conf
# Comment out HTTPS server block (lines 9-23)
# Keep only HTTP server block
```

### Step 3: Start nginx

```bash
docker compose up -d

# Test
curl -I http://localhost
# Should return 301
```

### Step 4: Edit Hosts File

**macOS/Linux**:

```bash
sudo vim /etc/hosts

# Add these lines:
127.0.0.1 twitter.com www.twitter.com
127.0.0.1 x.com www.x.com
127.0.0.1 t.co
```

**Windows**:

```powershell
# Run as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add these lines:
127.0.0.1 twitter.com www.twitter.com
127.0.0.1 x.com www.x.com
127.0.0.1 t.co
```

### Step 5: Clear DNS Cache

**macOS**:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Windows**:

```powershell
ipconfig /flushdns
```

**Linux**:

```bash
sudo systemd-resolve --flush-caches
```

### Step 6: Test

```bash
# Test DNS
nslookup twitter.com
# Should return 127.0.0.1

# Test redirect
curl -I http://twitter.com
# Should return 301 to xcancel.com

# Browser
# Visit http://twitter.com
# Should redirect to xcancel.com
```

### Limitations

**Wildcard subdomains don't work**:

- `mobile.twitter.com` won't redirect
- Hosts file doesn't support wildcards
- Need to add each subdomain manually

**HTTPS shows warnings**:

- No SSL configured
- For HTTPS support, add certificates (see Example 1)

**Single device only**:

- Only works on this computer
- Repeat hosts file edit on each device

### When to Use

**Perfect for**:

- Testing the concept
- Single laptop/desktop
- Don't want complexity of DNS server
- HTTP-only access acceptable

**Not suitable for**:

- Network-wide deployment
- Mobile devices (editing hosts on iOS is difficult)
- HTTPS without warnings (need SSL + CA installation)

---

## Example 5: Existing nginx Reverse Proxy

**Scenario**: You already run nginx as reverse proxy (or nginx-proxy-manager). You want to add Twitter redirect without disrupting existing setup.

**Your Setup**:

- nginx on host (not Docker)
- Serving multiple websites
- SSL configured with Let's Encrypt
- Can't dedicate ports 80/443 to xcancel-forwarder

### Option A: Add Rules to Existing nginx

Don't run xcancel-forwarder containers. Just add redirect rules.

#### Step 1: Create Redirect Config

```bash
# Add to your existing nginx config
sudo vim /etc/nginx/sites-available/twitter-redirect

# Add this:
server {
    listen 80;
    listen [::]:80;
    server_name twitter.com www.twitter.com x.com www.x.com t.co www.t.co;

    location / {
        return 301 https://xcancel.com$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name twitter.com www.twitter.com x.com www.x.com t.co www.t.co;

    # Use your existing SSL certificates or create new ones
    ssl_certificate /etc/letsencrypt/live/twitter.local/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/twitter.local/privkey.pem;

    location / {
        return 301 https://xcancel.com$request_uri;
    }
}
```

#### Step 2: Create SSL Certificate

Since Let's Encrypt won't issue certificates for twitter.com (you don't own it), use self-signed:

```bash
# Create certificate
sudo mkcert -install
sudo mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Or use your existing CA
```

#### Step 3: Enable and Test

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/twitter-redirect /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Reload
sudo systemctl reload nginx

# Test
curl -I http://your-server-ip
# Set Host header to test:
curl -I -H "Host: twitter.com" http://your-server-ip
# Should return 301
```

#### Step 4: Configure DNS

Use Pi-hole, dnsmasq, or router DNS to point domains to your nginx server IP.

### Option B: Run on Different Ports

Run xcancel-forwarder on ports 8080/8443, proxy from main nginx.

#### Step 1: Change Ports

```bash
# docker-compose.yaml (bridge mode)
services:
  nginx:
    ports:
      - "8080:80"
      - "8443:443"
```

#### Step 2: Start xcancel-forwarder

```bash
docker compose up -d
```

#### Step 3: Proxy from Main nginx

```bash
# In your main nginx config
server {
    listen 80;
    server_name twitter.com x.com t.co;

    location / {
        proxy_pass http://localhost:8080;
    }
}

server {
    listen 443 ssl;
    server_name twitter.com x.com t.co;

    # Your SSL config...

    location / {
        proxy_pass https://localhost:8443;
    }
}
```

#### Step 4: Test

```bash
curl -I -H "Host: twitter.com" http://localhost
# Should return 301 from proxied xcancel-forwarder
```

### When to Use Each Option

**Option A** (add rules):

- Simple, no containers
- Uses your existing nginx
- Fewer moving parts

**Option B** (proxy to containers):

- Keep xcancel-forwarder separate
- Easier updates
- Can use Caddy instead of nginx for simpler config

---

## Comparison of Examples

| Example | DNS Method | Web Server | SSL | Complexity | Best For |
|---------|------------|------------|-----|------------|----------|
| #1 | Pi-hole | nginx | mkcert | Medium | Existing Pi-hole users |
| #2 | dnsmasq | Caddy | mkcert | Medium | Whole network, no Pi-hole |
| #3 | Router | nginx | None | Low | Router with static DNS |
| #4 | Hosts file | nginx | None | Low | Single device testing |
| #5 | Any | Existing | Your choice | Medium | Existing reverse proxy |

## Related Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Detailed setup guide
- **[DECISION_GUIDE.md](DECISION_GUIDE.md)** - Help choosing options
- **[TESTING.md](TESTING.md)** - Verification procedures
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues

## Contributing Examples

Have a different setup? Submit a PR with your example!

Include:

- Scenario description
- Network layout
- Step-by-step walkthrough
- Common issues you encountered
- Testing verification

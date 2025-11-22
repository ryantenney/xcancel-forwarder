# Quick Reference

**One-page cheat sheet for xcancel-forwarder**

## Essential Commands

### Docker Compose Operations

```bash
# Start services
docker compose up -d

# Start with specific compose file
docker compose -f docker-compose.caddy.yaml up -d

# View logs (follow mode)
docker compose logs -f nginx

# View logs (last 100 lines)
docker compose logs --tail=100 nginx

# Check container status
docker compose ps

# Restart services
docker compose restart

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v

# Update images and restart
docker compose pull && docker compose up -d

# Rebuild and restart
docker compose up -d --build
```

### Testing Commands

```bash
# Check DNS resolution
nslookup twitter.com
dig twitter.com
host twitter.com

# Test HTTP redirect
curl -I http://twitter.com
curl -I http://x.com
curl -I http://t.co/example

# Test HTTPS redirect
curl -I https://twitter.com
curl -I https://x.com

# Test with specific DNS server
nslookup twitter.com 192.168.1.100
dig @192.168.1.100 twitter.com

# Verbose curl (see full redirect chain)
curl -v http://twitter.com

# Follow redirects
curl -L http://twitter.com

# Check SSL certificate
openssl s_client -connect twitter.com:443 -servername twitter.com

# Check certificate expiry
openssl s_client -connect twitter.com:443 -servername twitter.com 2>/dev/null | openssl x509 -noout -dates
```

### SSL Certificate Commands

#### mkcert

```bash
# Install mkcert
brew install mkcert              # macOS
apt install mkcert               # Debian/Ubuntu
dnf install mkcert               # Fedora

# Create CA and install
mkcert -install

# Generate certificates
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Check CA location
mkcert -CAROOT

# Uninstall CA
mkcert -uninstall
```

#### OpenSSL

```bash
# Create CA private key
openssl genrsa -out ca.key 4096

# Create CA certificate
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt

# Create server private key
openssl genrsa -out server.key 2048

# Create certificate signing request
openssl req -new -key server.key -out server.csr

# Sign certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 825

# Verify certificate
openssl verify -CAfile ca.crt server.crt

# View certificate details
openssl x509 -in server.crt -text -noout

# Check certificate expiry
openssl x509 -in server.crt -noout -dates
```

### DNS Cache Clearing

#### Client DNS Cache

```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux (systemd-resolved)
sudo systemd-resolve --flush-caches

# Linux (nscd)
sudo /etc/init.d/nscd restart

# Windows (PowerShell)
ipconfig /flushdns
```

#### Browser Cache

```bash
# Chrome/Edge - navigate to:
chrome://net-internals/#dns
# Click "Clear host cache"

# Firefox - navigate to:
about:networking#dns
# Click "Clear DNS Cache"

# Safari
# Develop menu → Empty Caches
```

#### DNS Server Cache

```bash
# Pi-hole (via SSH)
pihole restartdns

# dnsmasq
docker compose restart dnsmasq

# Or with systemd
sudo systemctl restart dnsmasq
```

### Network Diagnostics

```bash
# Find Docker host IP
ip addr show
ifconfig

# Test connectivity to nginx
curl http://NGINX_IP
curl https://NGINX_IP

# Check port availability
netstat -tuln | grep -E ':(80|443)'
ss -tuln | grep -E ':(80|443)'

# Test from specific interface
curl --interface eth0 http://twitter.com

# Trace HTTP request
curl -v -L http://twitter.com 2>&1 | grep -E '(> |< )'

# Check Docker network
docker network ls
docker network inspect xcancel-forwarder_default
docker network inspect xcancel-forwarder_macvlan_lan
```

## File Locations

### Configuration Files

| File | Purpose | Default Location |
|------|---------|-----------------|
| `.env` | Environment variables | Project root |
| `docker-compose.yaml` | nginx orchestration | Project root |
| `docker-compose.caddy.yaml` | Caddy orchestration | Project root |
| `nginx/nginx.conf` | nginx main config | `nginx/nginx.conf` |
| `nginx/conf.d/xcancel-redirect.conf` | Redirect rules | `nginx/conf.d/` |
| `nginx/ssl/server.crt` | SSL certificate | `nginx/ssl/` |
| `nginx/ssl/server.key` | SSL private key | `nginx/ssl/` |
| `caddy/Caddyfile` | Caddy config | `caddy/Caddyfile` |
| `caddy/ssl/server.crt` | Caddy SSL cert | `caddy/ssl/` |
| `caddy/ssl/server.key` | Caddy SSL key | `caddy/ssl/` |
| `dnsmasq/dnsmasq.conf` | dnsmasq config | `dnsmasq/dnsmasq.conf` |

### Log Files

```bash
# nginx access log (inside container)
docker compose exec nginx tail -f /var/log/nginx/access.log

# nginx error log (inside container)
docker compose exec nginx tail -f /var/log/nginx/error.log

# dnsmasq query log (if enabled)
docker compose logs -f dnsmasq

# Docker compose logs
docker compose logs -f
```

## Port Numbers

| Port | Service | Protocol | Notes |
|------|---------|----------|-------|
| 80 | nginx/Caddy | HTTP | Redirect port |
| 443 | nginx/Caddy | HTTPS | SSL redirect port |
| 53 | dnsmasq | DNS | UDP/TCP (if using dnsmasq) |

## Common IP Addresses

| Description | Example | Configure In |
|-------------|---------|--------------|
| Docker host IP | 192.168.1.10 | `.env` → `NGINX_HOST_IP` |
| nginx macvlan IP | 192.168.1.100 | `.env` → `NGINX_IP` |
| dnsmasq macvlan IP | 192.168.1.101 | `.env` → `DNSMASQ_IP` |
| LAN subnet | 192.168.1.0/24 | `.env` → `LAN_SUBNET` |
| LAN gateway | 192.168.1.1 | `.env` → `LAN_GATEWAY` |
| DNS upstream | 1.1.1.1 | `dnsmasq.conf` → `server=` |

## Environment Variables

| Variable | Purpose | Example | Required |
|----------|---------|---------|----------|
| `NGINX_IP` | nginx macvlan IP | `192.168.1.100` | If using macvlan |
| `DNSMASQ_IP` | dnsmasq macvlan IP | `192.168.1.101` | If using dnsmasq |
| `LAN_SUBNET` | Network CIDR | `192.168.1.0/24` | If using macvlan |
| `LAN_GATEWAY` | Default gateway | `192.168.1.1` | If using macvlan |
| `LAN_INTERFACE` | Host interface | `eth0` | If using macvlan |

## DNS Configuration Quick Reference

### Pi-hole Web UI

1. Login: `http://pi.hole/admin`
2. Settings → DNS → DNS Records
3. Add A record: `twitter.com` → nginx IP
4. Add A record: `x.com` → nginx IP
5. Add A record: `t.co` → nginx IP
6. Add CNAME: `*.twitter.com` → `twitter.com`
7. Add CNAME: `*.x.com` → `x.com`

### dnsmasq.conf Syntax

```bash
# A records
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100

# Wildcard subdomains (included in address= above)
```

### Router DNS (Example)

```
twitter.com → 192.168.1.100
*.twitter.com → 192.168.1.100
x.com → 192.168.1.100
*.x.com → 192.168.1.100
t.co → 192.168.1.100
```

### Hosts File Syntax

#### Linux/macOS: `/etc/hosts`

```
192.168.1.100 twitter.com www.twitter.com
192.168.1.100 x.com www.x.com
192.168.1.100 t.co
```

#### Windows: `C:\Windows\System32\drivers\etc\hosts`

```
192.168.1.100 twitter.com www.twitter.com
192.168.1.100 x.com www.x.com
192.168.1.100 t.co
```

## Troubleshooting One-Liners

### DNS Not Resolving

```bash
# Check what DNS server you're using
cat /etc/resolv.conf                  # Linux/macOS
ipconfig /all                         # Windows

# Test specific DNS server
dig @192.168.1.100 twitter.com        # Query dnsmasq directly
nslookup twitter.com 1.1.1.1          # Query Cloudflare (should NOT return nginx IP)
```

### Redirect Not Working

```bash
# Check nginx is running
docker compose ps | grep nginx

# Check nginx config syntax
docker compose exec nginx nginx -t

# View nginx access log
docker compose logs nginx | grep twitter

# Test directly with IP
curl -I http://NGINX_IP
```

### SSL Certificate Issues

```bash
# Check certificate validity
openssl s_client -connect twitter.com:443 -servername twitter.com 2>/dev/null | openssl x509 -noout -dates

# Check certificate SANs
openssl s_client -connect twitter.com:443 -servername twitter.com 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# Check CA is trusted (macOS)
security find-certificate -c "mkcert" -a

# Check CA is trusted (Linux)
ls /usr/local/share/ca-certificates/

# Check CA is trusted (Firefox - separate CA store)
# about:preferences#privacy → View Certificates → Authorities
```

### Macvlan Not Working

```bash
# Check Docker host cannot reach macvlan (this is normal)
ping 192.168.1.100  # From Docker host - will fail

# Check from another device
ping 192.168.1.100  # From laptop/phone - should work

# Check IP isn't already in use
nmap -sn 192.168.1.0/24

# Verify macvlan network exists
docker network ls | grep macvlan
```

### Container Won't Start

```bash
# Check detailed error
docker compose logs nginx

# Check ports aren't in use
sudo netstat -tuln | grep -E ':(80|443)'

# Check SELinux/AppArmor (Linux)
sudo setenforce 0  # Temporarily disable SELinux
sudo aa-status     # Check AppArmor

# Check file permissions
ls -la nginx/ssl/
```

## Quick Setup Paths

### Fastest Setup (5 min)

```bash
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder
python3 scripts/setup-wizard.py
# Follow prompts, done!
```

### Manual nginx + mkcert (15 min)

```bash
# Clone
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Config
cp .env.example .env
vim .env

# SSL
brew install mkcert
mkcert -install
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"
mv *.pem nginx/ssl/
mv nginx/ssl/*-key.pem nginx/ssl/server.key
mv nginx/ssl/*.pem nginx/ssl/server.crt

# Start
docker compose up -d

# Configure DNS (choose method from guides)
```

### Caddy + HTTP Only (10 min)

```bash
# Clone
git clone https://github.com/ryantenney/xcancel-forwarder.git
cd xcancel-forwarder

# Use Caddy
docker compose -f docker-compose.caddy.yaml up -d

# Configure DNS to point to Docker host IP
# No SSL setup needed
```

## Testing Checklist

- [ ] DNS resolves to nginx IP: `nslookup twitter.com`
- [ ] HTTP redirect works: `curl -I http://twitter.com`
- [ ] HTTPS redirect works: `curl -I https://twitter.com`
- [ ] Browser loads xcancel: visit `http://twitter.com`
- [ ] No SSL warnings: visit `https://twitter.com`
- [ ] Wildcard works: visit `https://mobile.twitter.com`
- [ ] Subdomains work: visit `https://www.x.com`
- [ ] Short links work: visit `http://t.co/example`

## Getting Help

**Documentation**:

- [Main README](../README.md)
- [Decision Guide](DECISION_GUIDE.md)
- [Quick Start](QUICKSTART.md)
- [Testing Guide](TESTING.md)
- [SSL Setup](SSL_SETUP_MKCERT.md)

**Troubleshooting**:

1. Check [TESTING.md](TESTING.md) troubleshooting section
2. Review logs: `docker compose logs -f`
3. Verify each component independently
4. Check GitHub issues for similar problems

**Common Fix**: 90% of issues are DNS cache. Clear **all** caches (client, browser, DNS server).

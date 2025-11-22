# Troubleshooting Guide

**Symptom-based troubleshooting quick reference**

Find your symptom below for quick diagnosis and solutions. For detailed testing procedures, see [TESTING.md](TESTING.md).

## Quick Diagnostic Checklist

Start here if nothing is working:

- [ ] **Containers running?** `docker compose ps`
- [ ] **DNS resolves to nginx IP?** `nslookup twitter.com`
- [ ] **nginx accessible?** `curl http://NGINX_IP`
- [ ] **All caches cleared?** DNS server + client + browser

**90% of issues are DNS cache** - clear everything and try again.

## Symptom Index

**Connection Issues:**

- [Browser still reaches Twitter/X directly](#browser-still-reaches-twitterx-directly)
- [Connection refused / Can't reach nginx](#connection-refused--cant-reach-nginx)
- [Works on some devices but not others](#works-on-some-devices-but-not-others)
- [Redirect stopped working after it was working](#redirect-stopped-working-after-it-was-working)

**DNS Issues:**

- [DNS returns wrong IP / Returns real Twitter IP](#dns-returns-wrong-ip--returns-real-twitter-ip)
- [nslookup returns correct IP but browser still goes to Twitter](#nslookup-returns-correct-ip-but-browser-still-goes-to-twitter)
- [DNS queries timing out](#dns-queries-timing-out)

**SSL/Certificate Issues:**

- [Browser shows security warning / Certificate error](#browser-shows-security-warning--certificate-error)
- [SSL handshake failure](#ssl-handshake-failure)
- [Certificate not trusted by curl](#certificate-not-trusted-by-curl)

**Container Issues:**

- [Container won't start / Exits immediately](#container-wont-start--exits-immediately)
- [Container shows "Up" but not "healthy"](#container-shows-up-but-not-healthy)
- [dnsmasq container won't start](#dnsmasq-container-wont-start)

**Network Issues:**

- [Can't reach nginx from Docker host (macvlan)](#cant-reach-nginx-from-docker-host-macvlan)
- [Slow redirects / High latency](#slow-redirects--high-latency)
- [xcancel loads slowly](#xcancel-loads-slowly)

**Redirect Issues:**

- [Gets 404 or wrong response](#gets-404-or-wrong-response)
- [Redirects to wrong destination](#redirects-to-wrong-destination)
- [Path not preserved in redirect](#path-not-preserved-in-redirect)

---

## Browser Still Reaches Twitter/X Directly

**Symptom**: Visiting twitter.com loads actual Twitter, not xcancel.

### Quick Fix

```bash
# 1. Clear ALL caches
# DNS server cache
pihole restartdns  # OR
docker compose restart dnsmasq

# 2. Client DNS cache
# macOS:
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
# Windows:
ipconfig /flushdns
# Linux:
sudo systemd-resolve --flush-caches

# 3. Browser cache
# Chrome: chrome://net-internals/#dns → Clear host cache
# Or use incognito/private mode

# 4. Test
nslookup twitter.com
# Should return your nginx IP, not 104.244.42.x
```

### Root Causes

**DNS not configured**:

- Check DNS server has override: `nslookup twitter.com DNS_SERVER_IP`
- Pi-hole: Verify records in web UI
- dnsmasq: Check `dnsmasq/dnsmasq.conf` has `address=/twitter.com/NGINX_IP`
- Router: Check static DNS entries

**Device using wrong DNS**:

```bash
# Check what DNS you're using
cat /etc/resolv.conf  # Linux/macOS
ipconfig /all          # Windows
```

- Ensure DNS points to your DNS server
- VPN may override DNS settings
- Some devices hard-code DNS (8.8.8.8)

**DNS cache**:

- Most common issue
- Must clear: DNS server + client + browser
- Try incognito/private mode to bypass browser cache

---

## Connection Refused / Can't Reach nginx

**Symptom**: `curl http://NGINX_IP` returns "Connection refused" or times out.

### Quick Fix

```bash
# 1. Check nginx is running
docker compose ps
# Should show nginx Up

# 2. Check nginx logs
docker compose logs nginx
# Look for errors

# 3. Verify nginx is listening
docker compose exec nginx netstat -tlnp | grep -E ':(80|443)'
# Should show nginx listening on ports 80 and 443

# 4. Restart nginx
docker compose restart nginx
```

### Root Causes

**nginx not running**:

```bash
docker compose up -d nginx
```

**Wrong IP**:

- Verify nginx IP: Check `.env` for `NGINX_IP`
- Bridge mode: Use Docker host IP
- Macvlan mode: Use dedicated container IP

**Firewall blocking**:

```bash
# Check firewall
sudo iptables -L -n | grep -E '(80|443)'

# Allow ports (if needed)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

**Port already in use**:

```bash
# Check what's using port 80/443
sudo netstat -tlnp | grep -E ':(80|443)'

# Stop conflicting service or use different ports
```

---

## DNS Returns Wrong IP / Returns Real Twitter IP

**Symptom**: `nslookup twitter.com` returns 104.244.42.x (Twitter's real IP) instead of your nginx IP.

### Quick Fix

```bash
# 1. Test DNS server directly
nslookup twitter.com YOUR_DNS_IP
# Should return nginx IP

# 2. If wrong, check DNS config
# Pi-hole: Web UI → Local DNS → DNS Records
# dnsmasq: cat dnsmasq/dnsmasq.conf
# Router: Check static DNS entries

# 3. Restart DNS server
pihole restartdns  # OR
docker compose restart dnsmasq
```

### Root Causes

**DNS override not configured**:

- **Pi-hole**: Add A record: `twitter.com → NGINX_IP`
- **dnsmasq**: Add line: `address=/twitter.com/NGINX_IP`
- **Router**: Add static DNS entry
- **Hosts file**: Add line: `NGINX_IP twitter.com`

**Client not using your DNS**:

```bash
# Check DNS server setting
cat /etc/resolv.conf
# Should list your DNS server IP

# If wrong, configure device DNS:
# - Per-device: Network settings
# - Network-wide: Router DHCP settings
```

**Using upstream DNS directly**:

- Device configured with 8.8.8.8 or 1.1.1.1 directly
- Bypasses your DNS server
- Must use your DNS server IP instead

---

## Browser Shows Security Warning / Certificate Error

**Symptom**: "Your connection is not private" or "NET::ERR_CERT_AUTHORITY_INVALID" when visiting `https://twitter.com`.

### Quick Fix

**Option 1: Install CA certificate** (recommended):

- **mkcert**: See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md) - device-specific instructions
- **OpenSSL**: Install `ca.crt` as trusted root certificate

**Option 2: Skip SSL** (HTTP only):

```bash
# Edit nginx/conf.d/xcancel-redirect.conf
# Comment out SSL-related lines (3, 5, 9, 13-18, 20-21)
docker compose restart nginx
# Now only http://twitter.com works (no warnings)
```

### Root Causes

**CA not installed**:

- Must install CA certificate on every device
- Different process for each OS/browser
- Firefox uses own certificate store (separate from OS)

**Wrong certificate**:

```bash
# Check what certificate nginx is serving
openssl s_client -connect twitter.com:443 -servername twitter.com </dev/null | openssl x509 -noout -text

# Verify:
# - Subject CN matches domain
# - Subject Alternative Names includes twitter.com, x.com, t.co
# - Issuer is your CA
```

**Certificate expired**:

```bash
# Check expiry
openssl x509 -in nginx/ssl/server.crt -noout -dates

# If expired, regenerate:
# mkcert: Re-run mkcert command
# OpenSSL: Create new certificate
```

---

## Works on Some Devices But Not Others

**Symptom**: Redirect works on laptop but not phone, or works in Firefox but not Chrome.

### Quick Fix

**For each failing device**:

```bash
# 1. Check DNS
nslookup twitter.com
# Should return nginx IP

# 2. Clear caches
# Device DNS cache (see OS-specific commands above)
# Browser cache (incognito mode or clear cache)

# 3. Check DNS server setting
# Should point to your DNS server, not 8.8.8.8 or 1.1.1.1
```

### Root Causes

**Device using wrong DNS**:

- Check network settings on failing device
- Ensure DNS points to your DNS server
- VPN may override DNS settings

**SSL certificate not installed on device**:

- Install CA certificate on each device
- See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)

**Device has stale cache**:

- Clear device DNS cache
- Clear browser cache
- Reconnect to Wi-Fi (mobile)

**Browser using DoH (DNS over HTTPS)**:

- Chrome/Firefox may bypass system DNS
- Disable DoH in browser settings:
  - Chrome: Settings → Privacy → Security → Use secure DNS → Off
  - Firefox: Settings → Network Settings → Disable DNS over HTTPS

---

## Container Won't Start / Exits Immediately

**Symptom**: `docker compose ps` shows container as "Exited" or not running.

### Quick Fix

```bash
# 1. Check logs
docker compose logs nginx

# 2. Common issues

# SSL files missing:
ls nginx/ssl/
# Should have server.crt and server.key

# Config syntax error:
docker compose exec nginx nginx -t

# Port already in use:
sudo netstat -tlnp | grep -E ':(80|443)'

# Fix issue, then restart:
docker compose up -d
```

### Root Causes

**SSL certificate files missing**:

```bash
# Check files exist
ls -la nginx/ssl/

# Should have:
# - server.crt (certificate)
# - server.key (private key)

# If missing, generate certificates:
# See SSL_SETUP_MKCERT.md or SSL_SETUP.md
```

**Invalid nginx configuration**:

```bash
# Test config
docker compose exec nginx nginx -t

# If errors, check:
# - nginx/conf.d/xcancel-redirect.conf syntax
# - Certificate paths correct
```

**Port conflict**:

```bash
# Check if port in use
sudo netstat -tlnp | grep :80

# Solutions:
# - Stop conflicting service
# - Use different ports in docker-compose.yaml
# - Use macvlan networking (no port mapping)
```

**Macvlan IP conflict**:

```bash
# Check IP not in use
ping NGINX_IP
# Should timeout (IP free)

# If responds, IP is in use
# Choose different IP in .env
```

---

## nslookup Returns Correct IP But Browser Still Goes to Twitter

**Symptom**: `nslookup twitter.com` shows nginx IP, but browser loads actual Twitter.

### Quick Fix

```bash
# 1. Clear browser DNS cache
# Chrome: chrome://net-internals/#dns → Clear host cache
# Firefox: about:networking#dns → Clear DNS Cache
# Safari: Quit and reopen

# 2. Try incognito/private mode

# 3. Check browser DNS settings
# Chrome/Edge: Settings → Privacy → Security
# Disable "Use secure DNS" (DNS over HTTPS)
```

### Root Causes

**Browser DNS cache**:

- Browser caches DNS separately from OS
- Must clear browser DNS cache
- Incognito/private mode bypasses cache

**Browser using DNS over HTTPS (DoH)**:

- Chrome/Firefox can bypass system DNS
- Queries go directly to 1.1.1.1 or 8.8.8.8
- Disable in browser settings

**HSTS preload list**:

- Browsers have hardcoded list of HTTPS-only domains
- twitter.com is on this list
- Browser may try HTTPS first, get certificate warning

---

## dnsmasq Container Won't Start

**Symptom**: dnsmasq container exits immediately or shows error.

### Quick Fix

```bash
# 1. Check logs
docker compose logs dnsmasq

# 2. Common issues

# Port 53 in use:
sudo netstat -tulnp | grep :53
# Another DNS server running?

# IP conflict:
ping DNSMASQ_IP
# Should timeout

# Macvlan not configured:
docker network ls | grep macvlan

# 3. Fix and restart
docker compose up -d dnsmasq
```

### Root Causes

**Port 53 already in use**:

```bash
# Check what's using port 53
sudo netstat -tulnp | grep :53

# Common culprits:
# - systemd-resolved (Ubuntu)
# - Another dnsmasq instance
# - Pi-hole on same host

# Solution: Stop conflicting service or use different host
```

**IP address conflict**:

- dnsmasq IP already in use
- Check `.env` → `DNSMASQ_IP`
- Choose unused IP on your network

**Macvlan not enabled**:

- dnsmasq requires macvlan networking
- Check `docker-compose.yaml` - macvlan section uncommented
- Verify network exists: `docker network ls`

**Missing NET_ADMIN capability**:

- dnsmasq needs NET_ADMIN to bind to port 53
- Check `docker-compose.yaml` has `cap_add: - NET_ADMIN`

---

## Can't Reach nginx from Docker Host (macvlan)

**Symptom**: `curl http://NGINX_IP` fails from Docker host but works from other devices.

### This Is Normal

**Docker limitation**: Host cannot directly reach macvlan containers.

**Test from another device** on your network:

```bash
# From laptop/phone
curl http://NGINX_IP
# Should work
```

### Solutions

**If you need host access**:

1. **Use bridge networking** instead of macvlan
2. **Or** access via loopback:

```bash
# Route through router
curl http://NGINX_IP --interface eth0
```

**Verification**:

- Macvlan works fine for DNS/redirect
- Clients on network can reach nginx
- Only Docker host has this limitation

---

## Slow Redirects / High Latency

**Symptom**: Redirect takes several seconds instead of instant.

### Quick Fix

```bash
# 1. Test redirect time
time curl -s -o /dev/null http://twitter.com
# Should be < 0.1s on local network

# 2. Check DNS resolution
time nslookup twitter.com
# Should be < 0.01s

# 3. Check nginx response
time curl -s -o /dev/null http://NGINX_IP
# Should be < 0.05s
```

### Root Causes

**DNS slow**:

- DNS server overloaded
- Upstream DNS slow (change in dnsmasq.conf)
- Increase DNS cache size

**Network issues**:

- Verify nginx on local network, not remote
- Check for network congestion
- Use `ping NGINX_IP` to check latency

**Container resources**:

```bash
docker stats xcancel-nginx xcancel-dnsmasq
# Check CPU/memory usage
# Should be minimal (< 5% CPU, < 50MB RAM)
```

---

## xcancel Loads Slowly

**Symptom**: Redirect happens instantly but xcancel.com takes long to load.

### This Is Not Your Setup

The redirect is instant (< 100ms). Content loading is xcancel.com's performance.

**Test redirect speed**:

```bash
time curl -s -o /dev/null http://twitter.com
# Your redirect time (should be < 0.1s)

# Content from xcancel is separate
curl -s -o /dev/null https://xcancel.com
# This is xcancel's speed, not yours
```

### Solutions

**Wait**: xcancel.com may be temporarily slow

**Switch frontend**: Change redirect URL in nginx config to different Twitter frontend

**Check xcancel status**: Visit https://xcancel.com directly from another device

---

## Gets 404 or Wrong Response

**Symptom**: Redirect returns 404 Not Found or unexpected page.

### Quick Fix

```bash
# 1. Check nginx config
cat nginx/conf.d/xcancel-redirect.conf

# Verify server_name includes domain:
# server_name twitter.com www.twitter.com x.com ...

# 2. Test config
docker compose exec nginx nginx -t

# 3. Restart nginx
docker compose restart nginx
```

### Root Causes

**Domain not in server_name**:

- Edit `nginx/conf.d/xcancel-redirect.conf`
- Add domain to `server_name` directive
- Restart: `docker compose restart nginx`

**Wrong nginx config loaded**:

- Check `/etc/nginx/conf.d/` in container
- Verify volume mount in docker-compose.yaml

**Accessing wrong server**:

- DNS pointing to wrong IP?
- Multiple nginx instances?

---

## Common Fixes Summary

### The Universal Fix (90% of Issues)

```bash
# Clear ALL caches
pihole restartdns  # OR docker compose restart dnsmasq
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder  # macOS
ipconfig /flushdns  # Windows
sudo systemd-resolve --flush-caches  # Linux

# Clear browser cache
# Chrome: chrome://net-internals/#dns → Clear
# Or use incognito mode
```

### Quick Diagnostic Commands

```bash
# Is DNS working?
nslookup twitter.com
# Should return nginx IP

# Is nginx working?
curl -I http://NGINX_IP
# Should return 301

# Are containers running?
docker compose ps
# Should show Up/healthy

# What's in the logs?
docker compose logs nginx
docker compose logs dnsmasq
```

### When All Else Fails

1. **Stop everything**: `docker compose down`
2. **Clear all caches** (DNS server, client, browser)
3. **Restart everything**: `docker compose up -d`
4. **Test step by step**: Follow [TESTING.md](TESTING.md)

---

## Related Documentation

- **[TESTING.md](TESTING.md)** - Comprehensive testing procedures
- **[TESTING_ADVANCED.md](TESTING_ADVANCED.md)** - Advanced diagnostics
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands cheat sheet
- **[FAQ.md](FAQ.md)** - Frequently asked questions

## Getting Help

If you're still stuck:

1. Follow [TESTING.md](TESTING.md) step-by-step
2. Check [FAQ.md](FAQ.md) for your specific question
3. Search [GitHub issues](https://github.com/ryantenney/xcancel-forwarder/issues)
4. Open new issue with:
   - Your setup (DNS method, networking mode, SSL status)
   - Output of diagnostic commands above
   - Relevant logs: `docker compose logs`

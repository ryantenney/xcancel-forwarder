# Testing and Verification

Complete guide for testing your X/Twitter → xcancel redirect setup.

## Pre-Flight Checklist

Before testing, ensure:

- [ ] Docker containers are running: `docker compose ps`
- [ ] DNS is configured (Pi-hole, dnsmasq, router, or hosts file)
- [ ] SSL certificates are in place (if using HTTPS)
- [ ] You know your nginx server's IP address

## Quick Test Script

Use the included test script for automated verification:

```bash
./scripts/test-redirect.sh
```

Or continue with manual tests below.

## Test 1: Container Status

Verify containers are running properly:

```bash
# Check container status
docker compose ps

# Should show:
# NAME              STATUS
# xcancel-nginx     Up (healthy)
# xcancel-dnsmasq   Up (if using dnsmasq)

# Check nginx logs
docker compose logs nginx

# Should show nginx started without errors
# Look for: "start worker processes"
```

### Expected Output

```
nginx: [notice] start worker processes
nginx: [notice] ... worker process started
```

### Troubleshooting

**Container is "Up" but not "healthy":**

```bash
# Check health check logs
docker inspect xcancel-nginx | grep -A 10 Health

# Health check tests wget to localhost
# If failing, check nginx is actually listening
docker compose exec nginx netstat -tlnp
```

**Container exits immediately:**

```bash
# Check for config errors
docker compose logs nginx

# Common issues:
# - SSL certificate files missing
# - Invalid nginx configuration
# - Port already in use
```

## Test 2: DNS Resolution

Verify domains resolve to your nginx IP.

### Using nslookup

```bash
# Test twitter.com
nslookup twitter.com

# Expected output:
# Server:   192.168.1.1 (or your DNS server IP)
# Address:  192.168.1.1#53
#
# Name:     twitter.com
# Address:  192.168.1.100 (your nginx IP)

# Test all domains
nslookup x.com
nslookup t.co
nslookup www.twitter.com
nslookup www.x.com
```

### Using dig (More Detailed)

```bash
# Test twitter.com
dig twitter.com

# Look for ANSWER section:
# ;; ANSWER SECTION:
# twitter.com.  300  IN  A  192.168.1.100

# Test specific DNS server
dig @192.168.1.101 twitter.com
```

### Using host

```bash
host twitter.com
# Should return: twitter.com has address 192.168.1.100
```

### Troubleshooting

**Still returns real X IP (104.244.42.x):**

- DNS override not working
- Client not using your DNS server
- DNS cache needs clearing

**"Non-authoritative answer" or caching issues:**

```bash
# Clear local DNS cache (see below)
# Force fresh lookup
dig twitter.com +trace
```

## Test 3: HTTP Redirect (Port 80)

Test the redirect without SSL:

```bash
# Test with curl
curl -I http://twitter.com

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/
# ...

# Test with a path
curl -I http://twitter.com/NASA

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/NASA
```

### Test All Domains

```bash
curl -I http://twitter.com
curl -I http://www.twitter.com
curl -I http://x.com
curl -I http://www.x.com
curl -I http://t.co
```

All should return `301 Moved Permanently` to `https://xcancel.com/`.

### Troubleshooting

**Connection refused:**

```bash
# Check nginx is listening on port 80
docker compose exec nginx netstat -tlnp | grep :80

# Test directly to nginx IP
curl -I http://192.168.1.100
```

**404 or wrong response:**

- nginx config issue
- Check `nginx/conf.d/xcancel-redirect.conf`
- Verify `server_name` includes the domain

**Redirect to wrong destination:**

- Check `location /` block in nginx config
- Should be: `return 301 https://xcancel.com$request_uri;`

## Test 4: HTTPS Redirect (Port 443)

If you configured SSL certificates:

```bash
# Test HTTPS redirect
curl -I https://twitter.com

# Expected output:
# HTTP/2 301
# location: https://xcancel.com/
# ...
```

### Test Certificate

```bash
# Check certificate details
openssl s_client -connect twitter.com:443 -servername twitter.com < /dev/null

# Look for:
# - Issuer: Your CA
# - Subject: CN=twitter.com
# - Subject Alternative Names: twitter.com, x.com, etc.
# - Verify return code: 0 (ok)
```

### Troubleshooting

**Certificate not trusted (curl):**

```bash
# Bypass verification (testing only)
curl -Ik https://twitter.com

# If this works, certificate is being served
# Issue is with trust/CA installation
```

**Wrong certificate:**

```bash
# Check what cert nginx is serving
openssl s_client -connect 192.168.1.100:443 < /dev/null | openssl x509 -text

# Verify Subject and SANs match
```

**SSL handshake failure:**

- Check certificate files exist in `nginx/ssl/`
- Verify permissions (644 for .pem, 600 for .key)
- Check nginx error logs: `docker compose logs nginx`

## Test 5: Browser Test

Most important test - does it work in a real browser?

### Desktop Browser Test

1. Open browser (Chrome, Firefox, Safari, Edge)
2. Navigate to `https://twitter.com`
3. Should redirect to `https://xcancel.com`
4. Check address bar - should show `xcancel.com`
5. No security warnings

### Test Specific Paths

Visit these URLs - all should redirect to xcancel:

- `https://twitter.com/NASA`
- `https://x.com/verified`
- `https://twitter.com/i/trends`
- `https://t.co/xxxxxxxxxx` (any t.co short link)

### Mobile Browser Test

Repeat tests on mobile devices (iOS/Android):

1. Ensure mobile device is using your DNS
2. Visit `https://twitter.com`
3. Should redirect without warnings

### Troubleshooting

**Browser shows security warning:**

- CA not installed on this device
- Certificate doesn't match domain
- See [SSL_SETUP.md](SSL_SETUP.md) for CA installation

**Not redirecting:**

- DNS not working on this device
- Browser DNS cache needs clearing
- Try private/incognito mode

**Mixed results (works sometimes):**

- DNS caching - wait or clear cache
- Multiple DNS servers configured, using wrong one
- VPN overriding DNS settings

## Test 6: End-to-End Test

Complete test from a clean device:

1. **Configure device DNS** to use your DNS server
2. **Clear all caches** (DNS, browser)
3. **Navigate to** `https://twitter.com/verified`
4. **Should see** xcancel.com page load
5. **Check URL** in address bar: `https://xcancel.com/verified`
6. **No warnings** or errors

Success = you're viewing Twitter content via xcancel without ever hitting X's servers!

## Test 7: Network-Wide Verification

If using router/Pi-hole (network-wide DNS):

### Test Multiple Devices

Verify redirect works on:

- [ ] Desktop computer
- [ ] Laptop
- [ ] Smartphone
- [ ] Tablet
- [ ] Smart TV (if applicable)
- [ ] Any other network-connected device

### Test Different Browsers

- [ ] Chrome/Chromium
- [ ] Firefox
- [ ] Safari
- [ ] Edge
- [ ] Mobile browsers

## Clearing Caches

If tests aren't working, clear caches:

### DNS Server Cache

**Pi-hole:**

```bash
pihole restartdns
```

**dnsmasq (standalone):**

```bash
docker compose restart dnsmasq
```

**Router:**

Restart router's DNS service or reboot router.

### Client DNS Cache

**Windows:**

```cmd
ipconfig /flushdns
```

**macOS:**

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Linux:**

```bash
# systemd-resolved
sudo systemd-resolve --flush-caches

# nscd
sudo service nscd restart

# dnsmasq (if running locally)
sudo systemctl restart dnsmasq
```

**iOS:**

1. Enable Airplane Mode
2. Wait 5 seconds
3. Disable Airplane Mode

**Android:**

1. Settings → Network → Wi-Fi
2. Forget network
3. Reconnect

### Browser Cache

**Chrome/Edge:**

1. Visit `chrome://net-internals/#dns`
2. Click "Clear host cache"

**Firefox:**

1. Close and reopen browser
2. Or visit `about:config`
3. Set `network.dnsCacheExpiration` to `0` temporarily

**Safari:**

- Quit Safari completely
- Reopen

## Monitoring and Logs

### nginx Access Logs

```bash
# Watch nginx access logs
docker compose logs -f nginx

# Or view log file directly
tail -f nginx/logs/access.log
```

Look for requests like:

```
192.168.1.50 - [21/Jan/2025:12:00:00 -0500] "GET / HTTP/2.0" 301 0 "-" "Mozilla/5.0..."
```

### DNS Query Logs

**Pi-hole:**

Web interface → Tools → Query Log

**dnsmasq:**

If you enabled `log-queries`:

```bash
docker compose logs -f dnsmasq
```

### Check Traffic

On your router or using tcpdump:

```bash
# Monitor DNS traffic
sudo tcpdump -i any port 53 -v

# Monitor HTTP/HTTPS traffic to nginx
sudo tcpdump -i any host 192.168.1.100
```

## Performance Test

Verify redirect is fast:

```bash
# Time the redirect
time curl -s -o /dev/null -w "HTTP Code: %{http_code}\nTime: %{time_total}s\n" http://twitter.com

# Should complete in < 0.1s on local network
```

## Automated Testing Script

Create a comprehensive test:

```bash
#!/bin/bash
# Test all aspects of the redirect

echo "=== Testing DNS Resolution ==="
for domain in twitter.com x.com t.co; do
  echo -n "$domain: "
  nslookup $domain | grep Address | tail -1 | awk '{print $2}'
done

echo -e "\n=== Testing HTTP Redirect ==="
for domain in twitter.com x.com t.co; do
  echo -n "$domain: "
  curl -s -o /dev/null -w "%{http_code}" http://$domain
  echo
done

echo -e "\n=== Testing HTTPS Redirect ==="
for domain in twitter.com x.com t.co; do
  echo -n "$domain: "
  curl -s -o /dev/null -w "%{http_code}" https://$domain 2>/dev/null || echo "SSL Error"
  echo
done

echo -e "\n=== Testing Full Redirect Chain ==="
curl -I -L http://twitter.com 2>&1 | grep -E "HTTP|Location"
```

Save as `test-all.sh` and run:

```bash
chmod +x test-all.sh
./test-all.sh
```

## Common Issues Checklist

If things aren't working, check:

- [ ] Containers are running: `docker compose ps`
- [ ] DNS resolves correctly: `nslookup twitter.com`
- [ ] nginx is accessible: `curl http://192.168.1.100`
- [ ] Firewall allows ports 80/443
- [ ] SSL certificates exist: `ls nginx/ssl/`
- [ ] Client is using your DNS server
- [ ] Caches have been cleared
- [ ] No VPN overriding DNS

## Success Indicators

You'll know it's working when:

1. ✅ `nslookup twitter.com` returns your nginx IP
2. ✅ `curl -I http://twitter.com` returns 301 to xcancel.com
3. ✅ Browser redirects without security warnings
4. ✅ You can browse Twitter content via xcancel
5. ✅ URL bar shows xcancel.com, not twitter.com
6. ✅ Works on all devices on your network

## What Next?

Once everything is working:

- Document which devices have CA installed
- Set calendar reminder for certificate renewal (825 days)
- Consider adding more domains if needed
- Share with others who want to avoid X!

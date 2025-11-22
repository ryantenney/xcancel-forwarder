# Advanced Testing

Comprehensive testing procedures for network-wide verification, monitoring, performance testing, and automation.

**For basic testing**: See [TESTING.md](TESTING.md) for essential tests including container status, DNS resolution, HTTP/HTTPS redirects, browser testing, and cache clearing.

## Test 6: End-to-End Test

Complete test from a clean device to verify the full redirect chain works:

**Steps**:

1. **Configure device DNS** to use your DNS server (Pi-hole, dnsmasq, router, etc.)
2. **Clear all caches** (DNS, browser) - see [TESTING.md](TESTING.md#clearing-caches)
3. **Navigate to** `https://twitter.com/verified`
4. **Should see** xcancel.com page load
5. **Check URL** in address bar: `https://xcancel.com/verified`
6. **No warnings** or errors

**Success** = you're viewing Twitter content via xcancel without ever hitting X's servers!

### Verification Checklist

- [ ] DNS resolves to nginx IP (not X's IP)
- [ ] HTTP redirect returns 301 status
- [ ] HTTPS redirect returns 301 status
- [ ] Browser loads xcancel.com content
- [ ] No SSL/TLS warnings
- [ ] URL bar shows xcancel.com
- [ ] Specific paths redirect correctly (e.g., /verified → /verified)
- [ ] Wildcard subdomains work (mobile.twitter.com, www.x.com)

### Common End-to-End Failures

**Browser loads twitter.com directly**:

- DNS not configured correctly
- Device using wrong DNS server
- VPN overriding DNS

**SSL warning appears**:

- CA not installed on device
- Wrong certificate served
- Certificate doesn't include domain

**Redirect works but content doesn't load**:

- xcancel.com may be temporarily unavailable
- Network connectivity issue
- Firewall blocking xcancel.com

## Test 7: Network-Wide Verification

If using router/Pi-hole (network-wide DNS), verify redirect works across all devices.

### Test Multiple Devices

Verify redirect works on:

- [ ] Desktop computer
- [ ] Laptop
- [ ] Smartphone
- [ ] Tablet
- [ ] Smart TV (if applicable)
- [ ] Any other network-connected device

**For each device**:

1. Verify DNS server setting
2. Clear DNS/browser cache
3. Visit `https://twitter.com`
4. Should redirect to xcancel.com

### Test Different Browsers

Test on multiple browsers to ensure compatibility:

- [ ] Chrome/Chromium
- [ ] Firefox
- [ ] Safari
- [ ] Edge
- [ ] Mobile browsers (Safari iOS, Chrome Android)
- [ ] Alternative browsers (Brave, Vivaldi, etc.)

### Test Operating Systems

- [ ] macOS
- [ ] Windows
- [ ] Linux (various distributions)
- [ ] iOS
- [ ] Android
- [ ] ChromeOS (if applicable)

### Network-Wide Troubleshooting

**Some devices work, others don't**:

- Check DNS server configuration on failing devices
- Verify devices are on same network
- Check for device-specific firewall rules
- Some devices may have hardcoded DNS (8.8.8.8)

**All devices fail**:

- DNS server not working
- nginx not accessible from network
- Firewall blocking nginx ports
- Verify from DNS server host: `curl http://192.168.1.100`

**Intermittent failures**:

- DNS load balancing or multiple DNS servers
- TTL too long, stale cache entries
- Network infrastructure issues

## Monitoring and Logs

### nginx Access Logs

Monitor redirect activity in real-time:

```bash
# Watch nginx access logs
docker compose logs -f nginx

# Or view log file directly (if mounted)
docker compose exec nginx tail -f /var/log/nginx/access.log

# Filter for specific domain
docker compose logs nginx | grep twitter.com

# Count redirects
docker compose logs nginx | grep "301" | wc -l
```

**Example log entry**:

```
192.168.1.50 - - [21/Jan/2025:12:00:00 -0500] "GET / HTTP/2.0" 301 0 "-" "Mozilla/5.0..."
```

**Log format fields**:

- `192.168.1.50` - Client IP
- `[21/Jan/2025:12:00:00 -0500]` - Timestamp
- `"GET / HTTP/2.0"` - Request method and path
- `301` - Status code (redirect)
- `"Mozilla/5.0..."` - User agent

### nginx Error Logs

Check for errors:

```bash
# View error log
docker compose exec nginx tail -f /var/log/nginx/error.log

# Check for specific errors
docker compose logs nginx | grep error
docker compose logs nginx | grep warn
```

**Common errors to watch for**:

- SSL handshake failures
- Missing certificate files
- Configuration syntax errors
- Permission denied errors

### DNS Query Logs

**Pi-hole**:

1. Open Pi-hole web interface: `http://pi.hole/admin`
2. Navigate to **Tools** → **Query Log**
3. Filter for twitter.com/x.com/t.co
4. Verify returning nginx IP

**dnsmasq**:

Enable query logging in `dnsmasq/dnsmasq.conf`:

```bash
log-queries
```

Then view logs:

```bash
docker compose logs -f dnsmasq

# Filter for specific domain
docker compose logs dnsmasq | grep twitter.com
```

### Network Traffic Monitoring

Monitor DNS and HTTP/HTTPS traffic:

```bash
# Monitor DNS traffic
sudo tcpdump -i any port 53 -v

# Monitor HTTP/HTTPS traffic to nginx
sudo tcpdump -i any host 192.168.1.100 -v

# Monitor specific port
sudo tcpdump -i any port 443 -v

# Save capture for analysis
sudo tcpdump -i any port 443 -w capture.pcap
```

**Analysis with tshark** (if available):

```bash
# Analyze captured traffic
tshark -r capture.pcap -Y "http.request.method == GET"
```

### Metrics and Statistics

**nginx request statistics**:

```bash
# Count total requests
docker compose logs nginx | grep -c "GET"

# Count 301 redirects
docker compose logs nginx | grep -c "301"

# Top requesting IPs
docker compose logs nginx | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# Requests per domain
docker compose logs nginx | grep twitter.com | wc -l
docker compose logs nginx | grep x.com | wc -l
docker compose logs nginx | grep t.co | wc -l
```

## Performance Testing

Verify redirect performance on local network.

### Response Time Test

```bash
# Time a single redirect
time curl -s -o /dev/null -w "HTTP Code: %{http_code}\nTime: %{time_total}s\n" http://twitter.com

# Expected: < 0.1s on local network
```

### Detailed Timing

```bash
# Show all timing phases
curl -w "\nDNS lookup: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" \
  -o /dev/null -s http://twitter.com
```

**Expected values on local network**:

- DNS lookup: < 0.01s
- Connect: < 0.01s
- TTFB (Time to First Byte): < 0.05s
- Total: < 0.1s

### Load Testing

Test performance under load:

```bash
# Using Apache Bench (if installed)
ab -n 1000 -c 10 http://twitter.com/

# Shows:
# - Requests per second
# - Time per request
# - Connection times
```

**Expected performance**:

- Requests per second: > 1000 (local network)
- Time per request: < 10ms average
- No failed requests

### HTTPS Performance

Test HTTPS redirect performance:

```bash
# HTTPS timing
curl -w "\nDNS: %{time_namelookup}s\nConnect: %{time_connect}s\nSSL: %{time_appconnect}s\nTotal: %{time_total}s\n" \
  -o /dev/null -s https://twitter.com
```

**Expected**: SSL handshake adds 5-20ms locally.

### Performance Troubleshooting

**Slow DNS lookups**:

- DNS server overloaded
- Upstream DNS slow
- Increase DNS cache size

**Slow SSL handshake**:

- Large certificate chain
- Weak CPU on nginx host
- Consider enabling session resumption

**High latency**:

- Network congestion
- Verify nginx is on local network
- Check for routing issues

## Automated Testing Script

Comprehensive test automation example:

```bash
#!/bin/bash
# comprehensive-test.sh - Complete xcancel-forwarder test suite

set -e

NGINX_IP="192.168.1.100"  # Change to your nginx IP
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

echo "======================================"
echo "xcancel-forwarder Test Suite"
echo "======================================"
echo

# Test 1: Container Status
echo "Test 1: Container Status"
if docker compose ps | grep -q "xcancel-nginx.*Up"; then
    echo -e "${GREEN}✓${NC} nginx container is running"
else
    echo -e "${RED}✗${NC} nginx container is not running"
    exit 1
fi
echo

# Test 2: DNS Resolution
echo "Test 2: DNS Resolution"
for domain in twitter.com x.com t.co; do
    echo -n "  Testing $domain: "
    result=$(nslookup $domain | grep "Address:" | tail -1 | awk '{print $2}')
    if [ "$result" == "$NGINX_IP" ]; then
        echo -e "${GREEN}✓${NC} ($result)"
    else
        echo -e "${RED}✗${NC} Got $result, expected $NGINX_IP"
    fi
done
echo

# Test 3: HTTP Redirect
echo "Test 3: HTTP Redirect"
for domain in twitter.com x.com t.co; do
    echo -n "  Testing http://$domain: "
    status=$(curl -s -o /dev/null -w "%{http_code}" http://$domain)
    location=$(curl -s -I http://$domain | grep -i "location:" | awk '{print $2}' | tr -d '\r')
    if [ "$status" == "301" ] && [[ "$location" == *"xcancel.com"* ]]; then
        echo -e "${GREEN}✓${NC} (301 → xcancel.com)"
    else
        echo -e "${RED}✗${NC} (Status: $status, Location: $location)"
    fi
done
echo

# Test 4: HTTPS Redirect
echo "Test 4: HTTPS Redirect"
for domain in twitter.com x.com t.co; do
    echo -n "  Testing https://$domain: "
    status=$(curl -s -o /dev/null -w "%{http_code}" https://$domain 2>/dev/null)
    if [ "$status" == "301" ]; then
        echo -e "${GREEN}✓${NC} (301)"
    elif [ -z "$status" ]; then
        echo -e "${YELLOW}⚠${NC} SSL not configured or certificate not trusted"
    else
        echo -e "${RED}✗${NC} (Status: $status)"
    fi
done
echo

# Test 5: Performance
echo "Test 5: Performance"
echo -n "  HTTP redirect time: "
time=$(curl -s -o /dev/null -w "%{time_total}" http://twitter.com)
echo "${time}s"
if (( $(echo "$time < 0.1" | bc -l) )); then
    echo -e "  ${GREEN}✓${NC} Performance is good (< 0.1s)"
else
    echo -e "  ${YELLOW}⚠${NC} Performance is slower than expected (>= 0.1s)"
fi
echo

# Test 6: Path Preservation
echo "Test 6: Path Preservation"
echo -n "  Testing path redirect: "
location=$(curl -s -I http://twitter.com/NASA | grep -i "location:" | awk '{print $2}' | tr -d '\r')
if [[ "$location" == "https://xcancel.com/NASA" ]]; then
    echo -e "${GREEN}✓${NC} Path preserved"
else
    echo -e "${RED}✗${NC} Expected https://xcancel.com/NASA, got $location"
fi
echo

echo "======================================"
echo "Test Suite Complete"
echo "======================================"
```

**Save and run**:

```bash
chmod +x comprehensive-test.sh
./comprehensive-test.sh
```

### Continuous Monitoring Script

For ongoing monitoring:

```bash
#!/bin/bash
# monitor-redirects.sh - Monitor redirect success rate

while true; do
    clear
    echo "xcancel-forwarder Status Monitor"
    echo "================================="
    echo "Last updated: $(date)"
    echo

    # Container status
    echo "Container Status:"
    docker compose ps
    echo

    # Recent redirect count
    echo "Recent Redirects (last 100 log lines):"
    redirects=$(docker compose logs --tail=100 nginx | grep -c "301")
    echo "  301 Redirects: $redirects"
    echo

    # Top requesting IPs
    echo "Top Requesting IPs:"
    docker compose logs --tail=100 nginx | awk '{print $1}' | sort | uniq -c | sort -rn | head -5
    echo

    sleep 5
done
```

## Troubleshooting Advanced Issues

### DNS Propagation Issues

**Problem**: Some devices get old DNS resolution

**Diagnosis**:

```bash
# Check TTL
dig twitter.com | grep "IN A"

# Query specific DNS servers
dig @8.8.8.8 twitter.com
dig @192.168.1.101 twitter.com
```

**Solution**: Lower TTL in DNS configuration, wait for caches to expire.

### SSL/TLS Issues

**Problem**: Certificate validation fails intermittently

**Diagnosis**:

```bash
# Test SSL/TLS connection
openssl s_client -connect twitter.com:443 -servername twitter.com

# Check certificate chain
openssl s_client -showcerts -connect twitter.com:443 < /dev/null

# Verify certificate
openssl verify -CAfile /path/to/ca.crt nginx/ssl/server.crt
```

**Solution**: Ensure CA is installed, check certificate validity, verify SANs.

### Performance Degradation

**Problem**: Redirects become slow over time

**Diagnosis**:

```bash
# Check nginx load
docker stats xcancel-nginx

# Check DNS server load
docker stats xcancel-dnsmasq

# Check system resources
top
df -h
```

**Solution**: Restart containers, check for resource constraints, review logs for errors.

### Macvlan Networking Issues

**Problem**: nginx not reachable from some devices

**Diagnosis**:

```bash
# From Docker host (will fail - this is normal)
ping 192.168.1.100

# From another device (should work)
ping 192.168.1.100

# Check Docker network
docker network inspect xcancel-forwarder_macvlan_lan

# Check ARP table
arp -a | grep 192.168.1.100
```

**Solution**: Verify macvlan configuration, check for IP conflicts, ensure correct subnet/gateway.

## Success Metrics

Track these metrics to ensure healthy operation:

- **DNS resolution success rate**: > 99%
- **HTTP redirect success rate**: 100%
- **HTTPS redirect success rate**: 100% (if SSL configured)
- **Average redirect time**: < 100ms
- **Container uptime**: 100%
- **Failed SSL handshakes**: 0

## Related Documentation

- **[TESTING.md](TESTING.md)** - Essential testing procedures
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands cheat sheet
- **[QUICKSTART.md](QUICKSTART.md)** - Setup guide
- **[DECISION_GUIDE.md](DECISION_GUIDE.md)** - Configuration decisions

# Advanced dnsmasq Configuration

Advanced features, performance tuning, and security considerations for dnsmasq.

**For basic setup**: See [DNSMASQ_SETUP.md](DNSMASQ_SETUP.md) for installation, configuration, client setup, verification, and basic troubleshooting.

## Advanced Configuration

### Multiple Upstream DNS Servers

Configure multiple upstream DNS servers for redundancy and failover:

Edit `dnsmasq/dnsmasq.conf`:

```bash
# Primary upstream DNS servers
server=1.1.1.1
server=1.0.0.1

# Secondary upstream (fallback)
server=8.8.8.8
server=8.8.4.4
```

**How it works**: dnsmasq will query them in order and fall back to the next if one fails or times out.

**Recommended combinations**:

- **Cloudflare + Google**: `1.1.1.1`, `8.8.8.8` (fast, reliable)
- **Quad9 + Cloudflare**: `9.9.9.9`, `1.1.1.1` (security + privacy)
- **ISP + Public**: `192.168.1.1`, `1.1.1.1` (local + fallback)

### Domain-Specific Upstream

Route specific domains to specific DNS servers:

```bash
# Use ISP DNS for local domains
server=/local.domain/192.168.1.1

# Use corporate DNS for company domains
server=/company.com/10.0.0.1
server=/internal.corp/10.0.0.1

# Use specific DNS for certain TLDs
server=/cn/223.5.5.5
```

**Use cases**:

- Corporate VPN split-DNS
- Local network domains
- Geographic DNS optimization
- Bypass DNS censorship for specific domains

### DHCP Server (Advanced)

dnsmasq can also function as a DHCP server to automatically assign IPs and DNS settings to devices.

**Warning**: Running DHCP alongside your router's DHCP will cause conflicts. Only use if:

- You're replacing your router's DHCP
- You understand DHCP networking
- You can disable router's DHCP server

**Basic DHCP configuration** (add to `dnsmasq.conf`):

```bash
# Enable DHCP
dhcp-range=192.168.1.100,192.168.1.200,12h

# Gateway (your router)
dhcp-option=option:router,192.168.1.1

# DNS servers (dnsmasq itself)
dhcp-option=option:dns-server,192.168.1.101

# Domain name
dhcp-option=option:domain-name,home.local

# Static leases for specific devices
dhcp-host=aa:bb:cc:dd:ee:ff,192.168.1.150,laptop
```

**This is advanced** - see [dnsmasq documentation](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html) for full DHCP features.

### Custom DNS Records

Add custom DNS entries beyond the Twitter/X redirect:

```bash
# Redirect additional domains
address=/example.com/192.168.1.200
address=/anothersite.com/192.168.1.201

# Host records (A records)
host-record=server.local,192.168.1.50
host-record=nas.home,192.168.1.60

# CNAME records (aliases)
cname=media.home,nas.home
cname=files.home,nas.home

# MX records (mail servers)
mx-host=example.com,mail.example.com,10

# SRV records (service discovery)
srv-host=_http._tcp.example.com,server.local,80,10,10

# TXT records
txt-record=example.com,"v=spf1 mx ~all"
```

**Use cases**:

- Local hostname resolution
- Development/testing environments
- Home lab infrastructure
- Block additional domains

### Wildcard Blocking

Block entire domains and subdomains:

```bash
# Block all of facebook.com
address=/facebook.com/

# Block specific subdomain
address=/ads.example.com/
```

**Empty address** means "return NXDOMAIN" (domain doesn't exist).

### DNSSEC Validation

Enable DNSSEC for additional security:

```bash
# In dnsmasq.conf
dnssec
trust-anchor=.,19036,8,2,49AAC11D7B6F6446702E54A1607371607A1A41855200FD2CE1CDDE32F24E8FB5
dnssec-check-unsigned
```

**Warning**: Can break some domains if misconfigured.

### IPv6 Configuration

Configure IPv6 DNS if you have IPv6 on your network:

```bash
# Enable IPv6
enable-ra

# IPv6 upstream DNS
server=2606:4700:4700::1111
server=2606:4700:4700::1001

# IPv6 DHCP range
dhcp-range=::100,::1ff,constructor:eth0,12h

# IPv6 address for domains
address=/twitter.com/192.168.1.100
# Note: No IPv6 override needed if only intercepting IPv4
```

## Performance Tuning

### Cache Size

Increase DNS cache size for better performance:

```bash
# In dnsmasq.conf
# Default: 150
cache-size=10000
```

**Recommendations**:

- Small network (< 10 devices): `1000`
- Medium network (10-50 devices): `5000`
- Large network (50+ devices): `10000+`

**Memory usage**: ~1KB per cached entry, so 10000 entries ≈ 10MB RAM

### Negative Caching

Cache "domain doesn't exist" responses to reduce upstream queries:

```bash
# In dnsmasq.conf
# Cache NXDOMAIN for 1 hour
neg-ttl=3600
```

**Benefits**: Reduces repeated queries for typos or non-existent domains.

### Cache Expiry

Control maximum cache time:

```bash
# In dnsmasq.conf
# Maximum TTL (time-to-live) in seconds
max-cache-ttl=3600
```

**Default**: Uses TTL from authoritative server

**Lower value**: More frequent upstream queries, more up-to-date

**Higher value**: Fewer queries, staler data

### Query Rate Limiting

Limit queries per client to prevent abuse:

```bash
# In dnsmasq.conf
# Maximum 100 queries per second per client
dns-rate-limit=100/s
```

**Prevents**: DNS amplification attacks, runaway clients

### Parallelization

Handle multiple queries concurrently:

```bash
# In dnsmasq.conf
# Allow up to 150 concurrent queries
dns-forward-max=150
```

**Default**: 150

**Increase** if you see "maximum number of concurrent DNS queries reached" in logs.

### Log Settings

Control logging verbosity:

```bash
# In dnsmasq.conf

# Log queries (verbose)
log-queries

# Log DHCP activity
log-dhcp

# Log async DNS
log-async

# Log to specific file
log-facility=/var/log/dnsmasq.log
```

**Production**: Disable `log-queries` to reduce I/O and log size.

**Debugging**: Enable temporarily, then disable.

## Security Considerations

### Exposure Risk

dnsmasq is exposed to your entire LAN. Risks:

**Internal threats**:

- Malicious clients querying sensitive internal names
- DNS cache poisoning attempts
- Resource exhaustion attacks

**Mitigation**:

- Only allow trusted devices on LAN
- Use MAC filtering on router
- Enable query rate limiting
- Monitor logs for suspicious activity

### DNS Amplification Attacks

If accidentally exposed to internet, dnsmasq could be used for DNS amplification DDoS attacks.

**Prevention**:

- Run behind firewall (never forward port 53)
- Use macvlan to isolate from WAN
- Don't bind to public IP
- Enable query rate limiting

**Verify not exposed**:

```bash
# From outside your network
dig @YOUR_PUBLIC_IP twitter.com
# Should timeout or be filtered by firewall
```

### Cache Poisoning

Attackers could attempt to poison DNS cache with false responses.

**Mitigation**:

- Use DNSSEC validation
- Use trusted upstream DNS
- Enable query randomization (enabled by default)
- Monitor for unusual query patterns

### Privacy Considerations

DNS queries reveal browsing history.

**Query logs contain**:

- Which domains were accessed
- When they were accessed
- Which device made the request

**Best practices**:

- Disable `log-queries` in production
- Rotate/delete logs regularly
- Don't commit logs to git
- Use encrypted upstream DNS (DNS-over-HTTPS/TLS) if supported

### Log Retention

Query logs grow quickly and contain sensitive data:

**Recommendations**:

- Delete logs older than 7-30 days
- Use log rotation:

```bash
# Linux logrotate example
/var/log/dnsmasq.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
}
```

- Disable logging if not needed
- Store logs securely

### Firewall Configuration

Restrict DNS access to known networks:

**iptables example**:

```bash
# Allow DNS from LAN only
iptables -A INPUT -p udp --dport 53 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -s 192.168.1.0/24 -j ACCEPT

# Drop all other DNS queries
iptables -A INPUT -p udp --dport 53 -j DROP
iptables -A INPUT -p tcp --dport 53 -j DROP
```

**firewalld example**:

```bash
# Create zone for DNS
firewall-cmd --permanent --new-zone=dnsmasq
firewall-cmd --permanent --zone=dnsmasq --add-source=192.168.1.0/24
firewall-cmd --permanent --zone=dnsmasq --add-service=dns
firewall-cmd --reload
```

## Advanced Troubleshooting

### Performance Issues

**Symptoms**: Slow DNS resolution, timeouts

**Diagnosis**:

```bash
# Check cache hit rate
docker compose exec dnsmasq killall -USR1 dnsmasq
docker compose logs dnsmasq | grep -i cache

# Monitor query rate
docker compose logs -f dnsmasq | grep query | wc -l

# Check system resources
docker stats xcancel-dnsmasq
```

**Solutions**:

- Increase cache size
- Add more upstream DNS servers
- Check upstream DNS latency: `ping 1.1.1.1`
- Reduce logging if enabled

### Memory Issues

**Symptoms**: Container restarts, OOM (Out of Memory)

**Check memory usage**:

```bash
docker stats xcancel-dnsmasq --no-stream
```

**Solutions**:

- Reduce cache size
- Disable query logging
- Add memory limit in docker-compose.yaml:

```yaml
dnsmasq:
  mem_limit: 256m
```

### DNSSEC Failures

**Symptoms**: Some domains don't resolve with DNSSEC enabled

**Diagnosis**:

```bash
# Check DNSSEC validation
dig twitter.com @192.168.1.101 +dnssec

# Look for SERVFAIL status
```

**Solutions**:

- Verify trust anchors are up-to-date
- Check upstream DNS supports DNSSEC
- Disable DNSSEC temporarily:

```bash
# Comment out in dnsmasq.conf:
# dnssec
```

### IPv6 Issues

**Symptoms**: Queries fail for devices using IPv6

**Diagnosis**:

```bash
# Test IPv6 connectivity
docker compose exec dnsmasq ping6 google.com

# Check IPv6 DNS
dig AAAA twitter.com @192.168.1.101
```

**Solutions**:

- Ensure macvlan supports IPv6
- Add IPv6 upstream DNS servers
- Check firewall allows IPv6 DNS
- Disable IPv6 if not needed:

```yaml
dnsmasq:
  sysctls:
    - net.ipv6.conf.all.disable_ipv6=1
```

## Monitoring and Metrics

### Query Statistics

Enable statistics collection:

```bash
# In dnsmasq.conf
log-queries
```

Then analyze:

```bash
# Top queried domains
docker compose logs dnsmasq | grep "query\[" | awk '{print $(NF-2)}' | sort | uniq -c | sort -rn | head -20

# Queries per hour
docker compose logs dnsmasq | grep "query\[" | awk '{print $1, $2}' | cut -d: -f1 | sort | uniq -c

# Cache hits vs misses
docker compose exec dnsmasq killall -USR1 dnsmasq
docker compose logs dnsmasq | grep "cache statistics"
```

### Health Checks

Monitor dnsmasq health:

```bash
#!/bin/bash
# dnsmasq-health-check.sh

DNSMASQ_IP="192.168.1.101"

# Test basic resolution
if nslookup google.com $DNSMASQ_IP > /dev/null 2>&1; then
    echo "✓ Basic DNS resolution working"
else
    echo "✗ DNS resolution failing"
    exit 1
fi

# Test our override
result=$(nslookup twitter.com $DNSMASQ_IP | grep "Address:" | tail -1 | awk '{print $2}')
if [ "$result" == "192.168.1.100" ]; then
    echo "✓ DNS override working"
else
    echo "✗ DNS override not working (got $result)"
    exit 1
fi

# Check container running
if docker compose ps | grep -q "dnsmasq.*Up"; then
    echo "✓ Container healthy"
else
    echo "✗ Container not running"
    exit 1
fi

echo "All health checks passed"
```

## Related Documentation

- **[DNSMASQ_SETUP.md](DNSMASQ_SETUP.md)** - Basic setup and configuration
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands cheat sheet
- **[TESTING.md](TESTING.md)** - Testing procedures
- **[TESTING_ADVANCED.md](TESTING_ADVANCED.md)** - Advanced testing and monitoring

## External Resources

- [dnsmasq official documentation](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
- [dnsmasq FAQ](http://www.thekelleys.org.uk/dnsmasq/docs/FAQ)

# Frequently Asked Questions (FAQ)

Common questions about xcancel-forwarder setup, usage, and troubleshooting.

## General Questions

### Which DNS method should I choose?

**If you already have Pi-hole**: Use Pi-hole (easiest, 5 minutes)

**If you want a dedicated DNS server**: Use included dnsmasq (10-15 minutes)

**If you can access your router settings**: Use router DNS override (10 minutes, network-wide)

**If you only need this on one device**: Use hosts file (5 minutes per device, no Docker DNS needed)

See [DECISION_GUIDE.md](DECISION_GUIDE.md) for detailed comparison and decision flowcharts.

### Do I need to use HTTPS/SSL?

**No, but it's recommended.**

- **Without SSL**: `http://twitter.com` redirects work, but `https://twitter.com` shows browser warnings
- **With SSL**: Both HTTP and HTTPS work seamlessly without warnings

Most links to Twitter/X use HTTPS, so SSL makes the experience smoother.

See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md) for easy setup (10 minutes).

### Will this slow down my browsing?

**No**, if set up on your local network.

- DNS resolution: < 10ms (local DNS server)
- Redirect: < 50ms (local nginx container)
- Total overhead: < 100ms on local network

xcancel.com itself may load slightly slower/faster than twitter.com depending on their servers, but the redirect is nearly instantaneous.

### Can I use this on mobile devices?

**Yes**, mobile devices work great.

**Options**:

1. **Network-wide** (Pi-hole/dnsmasq/router): Mobile automatically uses it on your Wi-Fi
2. **Per-device**: Configure DNS on each mobile device in Wi-Fi settings
3. **SSL certificates**: Must install CA certificate on mobile for HTTPS without warnings

See [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md) for iOS/Android CA installation.

### What if I already have a reverse proxy (traefik/nginx-proxy-manager)?

You have several options:

1. **Run xcancel nginx on different ports**: Use ports 8080/8443, configure your main proxy to forward twitter.com to these ports
2. **Add rules to existing proxy**: Copy the redirect rules from `nginx/conf.d/xcancel-redirect.conf` into your existing nginx/traefik config
3. **Use Caddy instead**: Simpler 4-line config, see [CADDY_ALTERNATIVE.md](CADDY_ALTERNATIVE.md)

The key is: DNS points to your proxy, proxy issues 301 redirect to xcancel.com.

### How do I undo this setup?

**Reverse the DNS changes**:

1. **Pi-hole**: Remove DNS records from web UI
2. **dnsmasq**: Stop container: `docker compose stop dnsmasq`
3. **Router**: Remove static DNS entries
4. **Hosts file**: Delete lines you added

**Clear caches**:

- Restart devices or clear DNS/browser caches
- See [TESTING.md](TESTING.md#clearing-caches)

**Stop nginx**:

```bash
docker compose down
```

Everything reverts to normal immediately.

### Why not just use browser extensions?

Browser extensions work great! This solution offers:

**Advantages**:

- Works on mobile devices (iOS, Android)
- Network-wide (all devices automatically)
- Works in all apps, not just browsers (Twitter embeds, etc.)
- No per-device configuration
- No browser-specific setup

**Disadvantages**:

- More complex setup
- Requires DNS control
- Affects entire network

**Use both**: Browser extensions + network redirect provides redundancy and works everywhere.

### Is this legal?

**Yes**. This setup:

- Runs on your own network
- Only affects your own devices
- Redirects to a public website (xcancel.com)
- Doesn't intercept actual Twitter traffic
- Doesn't modify content
- Doesn't violate any TOS you agreed to

You're simply choosing to view publicly available Twitter data through a different frontend. It's like using a bookmark that points to xcancel instead of twitter.

### What about rate limiting?

**xcancel.com** is not affiliated with this project. They may have rate limits or availability issues.

If xcancel is slow or unavailable:

- The redirect still works (instant)
- Content loads from xcancel (their speed/availability)
- You can switch to different frontend by changing nginx redirect URL

This project just handles the **redirect**, not xcancel's performance or availability.

### Can I add other domains?

**Yes**, easily.

1. Edit `nginx/conf.d/xcancel-redirect.conf`:
   - Add domain to `server_name` line
   - Optionally change redirect destination

2. Update DNS configuration:
   - Add DNS override for new domain

3. Update SSL certificate (if using HTTPS):
   - Add domain to mkcert command
   - Or add to OpenSSL SAN list

4. Restart nginx:

```bash
docker compose restart nginx
```

See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for examples.

## Technical Questions

### Which is better: nginx or Caddy?

**Both work identically** for this use case.

**Choose nginx if**:

- You know nginx already
- You want battle-tested, widely-used software
- You anticipate complex future requirements

**Choose Caddy if**:

- You're new to reverse proxies
- You want simpler configuration (4 lines vs 27 lines)
- You prefer modern, minimal config

Performance is identical. See [CADDY_ALTERNATIVE.md](CADDY_ALTERNATIVE.md).

### What's the difference between bridge and macvlan networking?

**Bridge** (simpler):

- nginx uses Docker host's IP
- Easier setup
- Port forwarding from host
- DNS points to host IP

**Macvlan** (recommended):

- nginx gets dedicated IP on LAN
- Cleaner network separation
- Required for dnsmasq
- DNS points to container IP
- Docker host can't reach container directly (normal limitation)

See [QUICKSTART.md](QUICKSTART.md) for setup instructions for each.

### Why can't I reach nginx from the Docker host with macvlan?

**This is normal Docker behavior.**

Macvlan creates network isolation - the Docker host and macvlan containers are on logically separate networks, even though they're on the same physical LAN.

**Test from another device** on your network instead:

```bash
# From laptop/phone on same network
curl http://192.168.1.100
```

**If you need host access**: Use bridge networking instead of macvlan.

### Do I need to renew SSL certificates?

**Yes, eventually**.

**mkcert certificates**:

- Valid for duration specified when CA was created
- Typically years
- Check expiry: `openssl x509 -in nginx/ssl/server.crt -noout -dates`
- Regenerate when needed: Run `mkcert` command again

**Manual OpenSSL certificates**:

- Valid for 825 days (maximum allowed by browsers)
- Set reminder to regenerate before expiry
- Process same as initial creation

Expired certificates cause browser warnings but redirect still works over HTTP.

### Can this work with IPv6?

**Yes**, IPv6 is supported.

**Requirements**:

- Docker supports IPv6
- Macvlan network configured for IPv6
- DNS server returns AAAA records for domains
- nginx listens on IPv6

Most setups only need IPv4 since Twitter/X typically accessed via IPv4. See [DNSMASQ_ADVANCED.md](DNSMASQ_ADVANCED.md) for IPv6 configuration.

### What if xcancel.com goes offline?

**The redirect still works**, but:

- Browser redirects to xcancel.com instantly
- xcancel.com fails to load (their issue, not yours)
- You see xcancel's error page or browser timeout

**Solutions**:

1. **Wait**: xcancel may come back online
2. **Switch frontend**: Change redirect URL in nginx config to different Twitter frontend (nitter, etc.)
3. **Temporarily disable**: Stop nginx to access Twitter directly

### How much bandwidth/resources does this use?

**Minimal**:

- **nginx container**: < 50MB RAM, negligible CPU
- **dnsmasq container**: < 20MB RAM, negligible CPU
- **Network traffic**: Only the initial redirect (< 1KB per page load)

Actual content loads from xcancel.com, not through your server.

### Can I run this on a Raspberry Pi?

**Yes**, works great on Raspberry Pi.

**Requirements**:

- Raspberry Pi 2 or newer
- Raspbian/Raspberry Pi OS
- Docker installed
- Use ARM-compatible images (nginx official image supports ARM)

Performance is excellent - redirect happens locally, minimal processing needed.

### Will this work with VPN?

**Depends on VPN configuration**:

**Split-tunnel VPN** (some traffic through VPN, some direct):

- Usually works if DNS goes through your network
- Check VPN doesn't override DNS settings

**Full-tunnel VPN** (all traffic through VPN):

- May not work if VPN provides own DNS
- VPN DNS won't have your overrides
- Configure VPN to use your DNS (if possible)

**Testing**: `nslookup twitter.com` - should return your nginx IP even with VPN connected.

## Troubleshooting Questions

### Why isn't it working?

**Most common issue: DNS cache**.

Clear **all** caches:

1. **DNS server**: Restart Pi-hole/dnsmasq
2. **Client DNS**: OS-specific flush commands
3. **Browser cache**: Visit `chrome://net-internals/#dns` or use incognito/private mode

See [TESTING.md](TESTING.md#clearing-caches) for complete cache clearing instructions.

Still not working? Follow [TESTING.md](TESTING.md) step-by-step.

### Works on some devices but not others?

**Check each device**:

```bash
# On each device
nslookup twitter.com
```

**Should return nginx IP**. If not:

- Device using wrong DNS server
- Device has hard-coded DNS (8.8.8.8)
- VPN overriding DNS
- Corporate network blocking DNS changes

**Solutions**:

- Configure DNS per-device
- Or use router/DHCP for network-wide DNS
- Disable VPN temporarily to test

### Why do I get SSL certificate warnings?

**CA certificate not installed on this device.**

**Solutions**:

1. Install CA certificate - see [SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md) for your device
2. Or skip HTTPS - comment out SSL config in nginx, use HTTP only

**Note**: Must install CA on **every device** you want HTTPS to work without warnings.

### Redirect works but xcancel loads slowly?

**This is xcancel.com's performance, not your setup**.

Your local redirect is instant (< 100ms). If xcancel loads slowly:

- xcancel servers may be under load
- xcancel may be rate-limiting
- Network path to xcancel may be slow

**Test redirect speed**:

```bash
time curl -s -o /dev/null http://twitter.com
# Should be < 0.1s
```

### Can I see logs of what's being redirected?

**Yes**:

```bash
# nginx access log
docker compose logs -f nginx

# Will show every request:
# 192.168.1.50 - [timestamp] "GET / HTTP/2.0" 301 ...
```

Includes:

- Source IP (which device)
- Timestamp
- URL requested
- Status code (301 = redirect)

### How do I update nginx or dnsmasq?

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d
```

Configuration persists between updates.

### Does this affect network performance?

**No noticeable impact**:

- DNS queries: Microseconds of processing
- Redirects: Minimal CPU/RAM usage
- No bandwidth used (just redirect, content from xcancel)

Even on Raspberry Pi or old hardware, performance impact is negligible.

### What if I have multiple networks (guest Wi-Fi, IoT network)?

**Each network needs own DNS configuration**:

- If using Pi-hole/dnsmasq: Ensure all networks can reach it
- If using router DNS: Configure per VLAN
- If using hosts file: Configure each device

**OR** run separate DNS server per network.

### Can I use this with Docker Swarm or Kubernetes?

**Yes**, but beyond scope of this guide.

**Key points**:

- Deploy nginx/dnsmasq as services
- Use overlay networking or external network
- Configure DNS to point to service VIP
- Handle SSL certificate distribution

Standard Docker Compose setup documented here works for single-host deployments.

## Related Documentation

- **[DECISION_GUIDE.md](DECISION_GUIDE.md)** - Help choosing setup options
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands cheat sheet
- **[QUICKSTART.md](QUICKSTART.md)** - Detailed setup guide
- **[TESTING.md](TESTING.md)** - Testing and verification
- **[SSL_SETUP_MKCERT.md](SSL_SETUP_MKCERT.md)** - SSL certificate setup

## Still Have Questions?

1. Check the comprehensive documentation in `docs/`
2. Search [GitHub issues](https://github.com/ryantenney/xcancel-forwarder/issues)
3. Open a new issue with details about your setup

# Pi-hole Configuration

Guide for configuring Pi-hole to redirect X/Twitter domains to your nginx server.

## Prerequisites

- Pi-hole already installed and running
- nginx container running (either bridge or macvlan mode)
- Know your nginx server's IP address

## Finding Your nginx IP

### Bridge Networking (Default)

Your nginx IP is your Docker host's IP address.

```bash
# Find your host IP
hostname -I | awk '{print $1}'
```

### Macvlan Networking

Your nginx IP is the dedicated IP you assigned in `docker-compose.yaml`:

```bash
# Check your docker-compose.yaml or .env file
grep NGINX_IP .env

# Or check running container
docker inspect xcancel-nginx | grep IPAddress
```

## Configure DNS Overrides in Pi-hole

### Option 1: Web Interface (Recommended)

1. Log in to Pi-hole admin interface (usually `http://pi.hole/admin` or `http://<pi-hole-ip>/admin`)

2. Navigate to **Local DNS → DNS Records**

3. Add the following entries:

| Domain | IP Address |
|--------|------------|
| `twitter.com` | `<your-nginx-ip>` |
| `x.com` | `<your-nginx-ip>` |
| `t.co` | `<your-nginx-ip>` |
| `www.twitter.com` | `<your-nginx-ip>` |
| `www.x.com` | `<your-nginx-ip>` |
| `www.t.co` | `<your-nginx-ip>` |

4. Click **Add** for each entry

### Option 2: Configuration File

SSH into your Pi-hole server:

```bash
# Edit custom DNS records
sudo vim /etc/pihole/custom.list
```

Add these lines (replace `192.168.1.100` with your nginx IP):

```
192.168.1.100 twitter.com
192.168.1.100 www.twitter.com
192.168.1.100 x.com
192.168.1.100 www.x.com
192.168.1.100 t.co
192.168.1.100 www.t.co
```

Restart DNS service:

```bash
pihole restartdns
```

## Wildcard Subdomains (Optional)

Pi-hole doesn't support true wildcard DNS entries in the standard interface, but you can handle common subdomains:

### Additional Subdomains to Consider

```
192.168.1.100 mobile.twitter.com
192.168.1.100 mobile.x.com
192.168.1.100 api.twitter.com
192.168.1.100 api.x.com
```

**Note**: Redirecting API subdomains may break Twitter apps and bots. Only add these if you want to redirect API traffic as well.

### True Wildcard Support (Advanced)

If you need true wildcard support (e.g., `*.twitter.com`), you can use dnsmasq configuration directly:

```bash
# Edit dnsmasq custom config
sudo vim /etc/dnsmasq.d/99-twitter-redirect.conf
```

Add:

```
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100
```

This will match all subdomains. Restart dnsmasq:

```bash
pihole restartdns
```

## Verify Configuration

### Check DNS Resolution

From your Pi-hole server:

```bash
# Should return your nginx IP
dig @127.0.0.1 twitter.com +short
dig @127.0.0.1 x.com +short
dig @127.0.0.1 t.co +short
```

From a client device (configured to use Pi-hole):

```bash
# Should return your nginx IP
nslookup twitter.com
nslookup x.com
```

### Check Pi-hole Query Log

1. Go to Pi-hole admin → **Tools → Query Log**
2. Search for `twitter.com` or `x.com`
3. Should show status "OK (cached)" or "OK" with your nginx IP

## Test the Redirect

From a client device using Pi-hole:

```bash
# Test HTTP redirect
curl -I http://twitter.com

# Expected output includes:
# HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/

# Test HTTPS (if you configured SSL)
curl -I https://twitter.com
```

Open a browser and visit `https://twitter.com` - should redirect to xcancel.com.

## Troubleshooting

### DNS Not Resolving to nginx IP

**Check Pi-hole is authoritative:**

```bash
# From client
nslookup twitter.com
# Server line should show Pi-hole's IP
```

If showing a different DNS server:

- Client isn't using Pi-hole as DNS
- Check DHCP settings or manually configure DNS on client

**Check Pi-hole DNS records:**

```bash
# On Pi-hole server
pihole -q twitter.com
# Should show "found in exact custom.list match"
```

**Flush Pi-hole cache:**

```bash
pihole restartdns
```

### Client DNS Cache

Even with correct Pi-hole configuration, clients may cache old DNS results:

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
sudo systemd-resolve --flush-caches
# Or
sudo service network-manager restart
```

**Browser:**

Modern browsers have their own DNS cache:

- **Chrome/Edge**: Visit `chrome://net-internals/#dns` and click "Clear host cache"
- **Firefox**: Restart browser (or set `network.dnsCacheExpiration` to 0 in `about:config`)
- **Safari**: Quit and reopen

### Redirect Not Working

If DNS resolves correctly but redirect isn't working:

1. **Check nginx is running:**
   ```bash
   docker compose ps
   # Should show nginx as "Up"
   ```

2. **Check nginx logs:**
   ```bash
   docker compose logs nginx
   # Should show incoming requests
   ```

3. **Test nginx directly:**
   ```bash
   curl -H "Host: twitter.com" http://<nginx-ip>/
   # Should return 301 redirect
   ```

4. **Check firewall:**
   ```bash
   # On nginx host
   sudo iptables -L | grep -E '80|443'
   ```

### Pi-hole Blocking Instead of Redirecting

If Pi-hole is blocking the domains instead of resolving them:

1. Go to Pi-hole admin → **Whitelist**
2. Add: `twitter.com`, `x.com`, `t.co`
3. Make sure they're not in any blocklists

## Advanced: Conditional Forwarding

If you only want certain devices to use the redirect while others still access X directly:

### Option 1: Device Groups (Pi-hole v5+)

1. Create a device group in Pi-hole
2. Assign specific devices to that group
3. Create group-specific local DNS records

See [Pi-hole documentation on Groups](https://docs.pi-hole.net/group_management/groups/) for details.

### Option 2: Separate DNS Server

Run the included dnsmasq container with a different IP and point only specific devices to it. See [DNSMASQ_SETUP.md](DNSMASQ_SETUP.md).

## Removing the Redirect

To stop redirecting X/Twitter traffic:

1. Remove DNS records from Pi-hole:
   - Web interface: Local DNS → DNS Records → Delete entries
   - Or edit `/etc/pihole/custom.list` and remove lines

2. Restart DNS:
   ```bash
   pihole restartdns
   ```

3. Clear client DNS caches (see above)

4. Stop nginx:
   ```bash
   docker compose down
   ```

## Integration with Other Pi-hole Features

### Blocklists

This redirect works alongside Pi-hole's ad-blocking. You can still:

- Block ads on other sites
- Use regex blocking
- Apply different rules to different device groups

### DHCP

If Pi-hole is your DHCP server, all clients will automatically use Pi-hole DNS and get the redirect.

### Statistics

Pi-hole will log all queries for twitter.com/x.com in its statistics. You can:

- See how many times the redirect was used
- View query history in Pi-hole admin
- Track which clients are accessing the redirect

## Security Considerations

### DNS Hijacking Detection

Some security-conscious clients may alert about "DNS hijacking" when twitter.com resolves to an unexpected IP. This is expected behavior and safe in this context since you control the DNS server.

### Split-Brain DNS

You're implementing split-brain DNS (internal vs external resolution). This means:

- Inside your network: twitter.com points to your nginx
- Outside your network: twitter.com points to X's servers

This is a standard and safe networking practice.

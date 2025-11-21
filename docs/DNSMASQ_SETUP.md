# dnsmasq Configuration

Guide for using the included dnsmasq DNS server to redirect X/Twitter domains.

## When to Use This Option

Use the included dnsmasq server if:

- You don't have Pi-hole or another DNS solution
- You want a dedicated DNS server just for this redirect
- You prefer containerized solutions

**Important**: dnsmasq requires macvlan networking to function properly as a DNS server.

## Prerequisites

- Docker and Docker Compose installed
- Macvlan networking configured
- Free IP address on your LAN for dnsmasq

## Setup Steps

### 1. Configure Environment Variables

Edit your `.env` file:

```bash
# Network settings
NETWORK_INTERFACE=eth0               # Your network interface
LAN_SUBNET=192.168.1.0/24           # Your subnet
LAN_GATEWAY=192.168.1.1             # Your router
NGINX_IP=192.168.1.100              # IP for nginx
DNSMASQ_IP=192.168.1.101            # IP for dnsmasq (must be free)

# Upstream DNS (dnsmasq will forward other queries here)
UPSTREAM_DNS=1.1.1.1                # Cloudflare DNS
```

### 2. Update dnsmasq Configuration

Edit `dnsmasq/dnsmasq.conf` and update the IP addresses to match your nginx IP:

```bash
# Replace 192.168.1.100 with your actual NGINX_IP
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100
```

Also update upstream DNS servers if desired:

```bash
# Cloudflare (default)
server=1.1.1.1
server=1.0.0.1

# Or use Google DNS
# server=8.8.8.8
# server=8.8.4.4

# Or your ISP/router
# server=192.168.1.1
```

### 3. Enable Macvlan in docker-compose.yaml

Edit `docker-compose.yaml`:

**Uncomment the macvlan network:**

```yaml
networks:
  macvlan_lan:
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE:-eth0}
    ipam:
      config:
        - subnet: ${LAN_SUBNET:-192.168.1.0/24}
          gateway: ${LAN_GATEWAY:-192.168.1.1}
          ip_range: ${IP_RANGE:-192.168.1.64/28}
          aux_addresses:
            host: ${HOST_IP:-192.168.1.10}
```

**Update nginx service to use macvlan:**

Comment out `ports` and uncomment `networks`:

```yaml
nginx:
  # Comment out these lines:
  # ports:
  #   - "${HTTP_PORT:-80}:80"
  #   - "${HTTPS_PORT:-443}:443"

  # Uncomment these lines:
  networks:
    macvlan_lan:
      ipv4_address: ${NGINX_IP:-192.168.1.100}
```

**Uncomment the dnsmasq service:**

```yaml
dnsmasq:
  image: jpillora/dnsmasq:latest
  container_name: xcancel-dnsmasq
  restart: unless-stopped
  networks:
    macvlan_lan:
      ipv4_address: ${DNSMASQ_IP:-192.168.1.101}
  volumes:
    - ./dnsmasq/dnsmasq.conf:/etc/dnsmasq.conf:ro
  environment:
    - TZ=${TZ:-America/New_York}
  cap_add:
    - NET_ADMIN
```

### 4. Start Services

```bash
# Start both nginx and dnsmasq
docker compose up -d

# Check status
docker compose ps

# Check logs
docker compose logs -f dnsmasq
```

## Configure Clients to Use dnsmasq

Now you need to point devices to use your dnsmasq server as their DNS.

### Option 1: Per-Device Configuration (Recommended for Testing)

**macOS:**

1. System Settings → Network
2. Select your connection → Details
3. DNS tab → Click "+"
4. Add your dnsmasq IP (e.g., `192.168.1.101`)
5. Drag it to the top of the list
6. Click OK

**Windows:**

1. Settings → Network & Internet
2. Properties for your connection
3. Edit DNS settings
4. Manual → IPv4 → ON
5. Preferred DNS: `192.168.1.101`
6. Save

**Linux:**

```bash
# Edit /etc/resolv.conf
sudo vim /etc/resolv.conf

# Add at the top
nameserver 192.168.1.101
```

Or use NetworkManager/systemd-resolved configuration.

**iOS/Android:**

1. Settings → Wi-Fi
2. Tap info/settings for your network
3. Configure DNS → Manual
4. Add DNS server: `192.168.1.101`

### Option 2: Router/DHCP Configuration (Network-Wide)

If you want all devices on your network to use dnsmasq:

1. Log in to your router admin panel
2. Find DHCP settings
3. Set Primary DNS server to your dnsmasq IP (e.g., `192.168.1.101`)
4. Set Secondary DNS to your ISP or `1.1.1.1` (fallback)
5. Save and restart DHCP

New DHCP leases will automatically use dnsmasq. Existing devices may need to:

- Renew DHCP lease
- Reconnect to Wi-Fi
- Reboot

## Verify dnsmasq is Working

### Test DNS Resolution

```bash
# Should return your nginx IP
nslookup twitter.com 192.168.1.101
nslookup x.com 192.168.1.101

# Expected output:
# Server:   192.168.1.101
# Address:  192.168.1.101#53
#
# Name:     twitter.com
# Address:  192.168.1.100
```

### Test Other Domains (Should Still Work)

```bash
# Should return real IP via upstream DNS
nslookup google.com 192.168.1.101
```

### Check dnsmasq Logs

```bash
docker compose logs dnsmasq

# Should show queries like:
# dnsmasq[1]: query[A] twitter.com from 192.168.1.50
# dnsmasq[1]: config twitter.com is 192.168.1.100
```

## Enable Query Logging (Optional)

To see all DNS queries for debugging:

Edit `dnsmasq/dnsmasq.conf` and uncomment:

```
log-queries
```

Restart:

```bash
docker compose restart dnsmasq
docker compose logs -f dnsmasq
```

You'll see every DNS query. Disable after debugging to reduce log volume.

## Troubleshooting

### dnsmasq Container Won't Start

**Check IP isn't already in use:**

```bash
ping 192.168.1.101
# Should get "no route to host" or timeout
```

**Check macvlan configuration:**

```bash
# Verify network interface exists
ip link show

# Check docker network
docker network ls
docker network inspect xcancel-forwarder_macvlan_lan
```

**Check logs:**

```bash
docker compose logs dnsmasq
```

Common errors:

- Port 53 already in use (another DNS server running)
- Permission denied (needs NET_ADMIN capability)
- Invalid network configuration

### Can't Reach dnsmasq from Clients

**From Docker host, you cannot reach macvlan IPs directly.** This is a Docker limitation. Test from another device on your network.

**Firewall blocking port 53:**

```bash
# On the Docker host
sudo iptables -L -n | grep 53
```

If using firewalld/ufw, allow DNS:

```bash
# UFW
sudo ufw allow 53/udp
sudo ufw allow 53/tcp

# Firewalld
sudo firewall-cmd --add-service=dns --permanent
sudo firewall-cmd --reload
```

### Queries Timing Out

**Check dnsmasq is listening:**

```bash
docker compose exec dnsmasq netstat -ulnp
# Should show process listening on 0.0.0.0:53
```

**Test with dig:**

```bash
# From another device
dig @192.168.1.101 twitter.com

# Should return answer with your nginx IP
```

### Upstream DNS Not Working

If redirected domains work but other domains don't resolve:

1. Check upstream DNS is accessible:
   ```bash
   docker compose exec dnsmasq ping -c 3 1.1.1.1
   ```

2. Try different upstream DNS in `dnsmasq.conf`:
   ```
   server=8.8.8.8
   ```

3. Check if your router/ISP is blocking DNS on port 53

## Advanced Configuration

### Multiple Upstream DNS Servers

```bash
# In dnsmasq.conf
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
```

dnsmasq will query them in order and fall back if one fails.

### Domain-Specific Upstream

```bash
# Use specific DNS for specific domains
server=/local.domain/192.168.1.1
server=/company.com/10.0.0.1
```

### DHCP Server (Advanced)

dnsmasq can also be a DHCP server. This is beyond the scope of this guide, but see [dnsmasq documentation](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).

### Custom DNS Records

Add more overrides in `dnsmasq.conf`:

```bash
# Redirect additional domains
address=/example.com/192.168.1.200

# Specific A records
host-record=custom.local,192.168.1.50

# CNAME records
cname=alias.local,target.local
```

## Performance Tuning

### Cache Size

Default is 1000 entries. Increase for better performance:

```bash
# In dnsmasq.conf
cache-size=10000
```

### Negative Caching

Cache "domain doesn't exist" responses:

```bash
# In dnsmasq.conf
neg-ttl=3600
```

## Security Considerations

### Exposure

dnsmasq is exposed to your entire LAN. Ensure:

- Your LAN is trusted
- Router firewall blocks external DNS queries
- Only trusted devices on your network

### DNS Amplification Attacks

If accidentally exposed to internet, dnsmasq could be used for DNS amplification attacks. Always:

- Run behind firewall
- Don't forward port 53 on router
- Use macvlan to isolate from external networks

### Log Retention

Query logs can grow large and contain privacy-sensitive information:

- Disable `log-queries` in production
- Rotate logs if enabled
- Don't commit logs to git

## Stopping dnsmasq

To stop using dnsmasq:

1. **Reconfigure clients** to use original DNS (router, ISP, or 1.1.1.1)

2. **Stop the container:**
   ```bash
   docker compose stop dnsmasq
   # Or comment out dnsmasq service in docker-compose.yaml
   docker compose up -d
   ```

3. **Clear DNS caches** on clients (see [PIHOLE_SETUP.md](PIHOLE_SETUP.md) for instructions)

## dnsmasq vs Pi-hole

**Use dnsmasq if:**

- You want minimal setup
- Don't need ad-blocking
- Prefer containerized solution
- Only need this specific redirect

**Use Pi-hole if:**

- You want network-wide ad blocking
- Need web interface for management
- Want query statistics and graphs
- Need more advanced features (DHCP, regex blocking, groups)

You can also use both - Pi-hole can use dnsmasq as an upstream DNS server.

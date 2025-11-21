# Other DNS Configuration Options

Guide for configuring DNS overrides on various routers and DNS servers besides Pi-hole and dnsmasq.

## General Concept

Regardless of your DNS solution, the goal is the same:

1. Point `twitter.com`, `x.com`, and `t.co` to your nginx server's IP
2. All other domains should resolve normally
3. Clients use this DNS server (via DHCP or manual configuration)

Replace `192.168.1.100` in examples below with your actual nginx IP address.

## Router-Based Solutions

Most modern routers allow custom DNS entries.

### Consumer Routers (General Steps)

1. Log in to router admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Find DNS/DHCP settings (location varies by brand)
3. Look for:
   - "Static DNS"
   - "Local DNS"
   - "Custom DNS"
   - "DNS Overrides"
   - "Host Names"
4. Add entries for:
   - `twitter.com` → `192.168.1.100`
   - `x.com` → `192.168.1.100`
   - `t.co` → `192.168.1.100`

### Asus Routers (Merlin Firmware)

1. Advanced Settings → LAN → DHCP Server
2. DNS and WINS Server Setting
3. DNS Server 1: (leave as router IP or upstream DNS)
4. Scroll to "Host Name Resolution"
5. Add custom entries:

```
192.168.1.100 twitter.com
192.168.1.100 x.com
192.168.1.100 t.co
```

Or via SSH:

```bash
# Edit /etc/hosts
nvram set dhcp_staticlist="<MAC_address>,<hostname>,192.168.1.100"
nvram commit
service restart_dnsmasq
```

### pfSense

1. Services → DNS Resolver (Unbound)
2. Scroll to "Host Overrides"
3. Click "Add"
4. For each domain:
   - Host: `twitter` / `x` / `t`
   - Domain: `com` / `com` / `co`
   - IP Address: `192.168.1.100`
   - Description: "xcancel redirect"
5. Click "Save"
6. Apply Changes

For wildcard support:

1. Services → DNS Resolver → Advanced
2. Custom Options:

```
local-zone: "twitter.com" redirect
local-data: "twitter.com A 192.168.1.100"
local-zone: "x.com" redirect
local-data: "x.com A 192.168.1.100"
```

### OPNsense

1. Services → Unbound DNS → Overrides
2. Click "+" to add Host Override
3. For each domain:
   - Host: `twitter` / `x` / `t`
   - Domain: `com` / `com` / `co`
   - Type: `A` (IPv4)
   - IP: `192.168.1.100`
4. Click "Save"
5. Apply changes

### UniFi (Ubiquiti)

#### Option A: Network UI (UniFi Network 8.0+)

Newer UniFi Network versions have a built-in UI for local DNS:

1. UniFi Network → Settings → Networks
2. Select your LAN network → Advanced
3. Scroll to "DHCP Name Server" → Custom
4. Enable "Manual" and add your gateway IP as DNS server
5. Then go to Settings → System → Advanced
6. Under "Custom DNS Entries" (or "Local DNS Records"):
   - Click "Add Entry"
   - For each domain:
     - **Record Type**: A
     - **Hostname**: `twitter.com` (or `x.com`, `t.co`)
     - **IP Address**: `192.168.1.100`
   - Save

7. Apply changes and wait for provisioning

#### Option B: SSH/CLI (All Versions)

For older versions or if you prefer command line:

```bash
# SSH to your UniFi gateway
ssh admin@<gateway-ip>

# Edit dnsmasq config
configure
edit service dns forwarding options
set address=/twitter.com/192.168.1.100
set address=/x.com/192.168.1.100
set address=/t.co/192.168.1.100
commit
save
exit

# Restart DNS
sudo /etc/init.d/dnsmasq force-reload
```

**Note**: SSH method settings may be lost on firmware updates. UI method persists.

### MikroTik RouterOS

```bash
# Via console
/ip dns static add name=twitter.com address=192.168.1.100
/ip dns static add name=x.com address=192.168.1.100
/ip dns static add name=t.co address=192.168.1.100

# For wildcards
/ip dns static add name=*.twitter.com address=192.168.1.100
/ip dns static add name=*.x.com address=192.168.1.100
```

Or via WebFig:

1. IP → DNS → Static
2. Add entries as above

### DD-WRT

1. Services → Services → DNSMasq
2. Enable "DNSMasq"
3. Additional DNSMasq Options:

```
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100
```

4. Save and Apply Settings

### OpenWrt

```bash
# SSH to router
ssh root@<router-ip>

# Edit dnsmasq config
vi /etc/dnsmasq.conf

# Add:
address=/twitter.com/192.168.1.100
address=/x.com/192.168.1.100
address=/t.co/192.168.1.100

# Restart dnsmasq
/etc/init.d/dnsmasq restart
```

Or via LuCI web interface:

1. Network → DHCP and DNS
2. Resolv and Hosts Files tab
3. Add to "Addresses":

```
/twitter.com/192.168.1.100
/x.com/192.168.1.100
/t.co/192.168.1.100
```

## Standalone DNS Servers

### BIND9

Edit zone file or create a custom view:

```bash
# /etc/bind/named.conf.local
zone "twitter.com" {
    type master;
    file "/etc/bind/db.twitter.redirect";
};

zone "x.com" {
    type master;
    file "/etc/bind/db.x.redirect";
};
```

Zone files:

```bash
# /etc/bind/db.twitter.redirect
$TTL 86400
@   IN  SOA ns1.local. admin.local. (
            2025010101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum
@   IN  NS  ns1.local.
@   IN  A   192.168.1.100
*   IN  A   192.168.1.100
```

Restart BIND:

```bash
sudo systemctl restart bind9
```

### PowerDNS Recursor

```bash
# /etc/powerdns/recursor.conf
forward-zones=twitter.com=192.168.1.100
forward-zones+=x.com=192.168.1.100
forward-zones+=t.co=192.168.1.100
```

Or use Lua config for more control:

```lua
-- /etc/powerdns/recursor.lua
addNTA("twitter.com")
addNTA("x.com")
rpzFile("twitter-redirect.rpz", {policyName="nxdomain"})
```

### Microsoft DNS (Windows Server)

1. DNS Manager → Forward Lookup Zones
2. Right-click → New Zone
3. Primary Zone → Next
4. Zone name: `twitter.com` → Next
5. Create new file → Next
6. Do not allow dynamic updates → Next
7. Finish
8. Right-click zone → New Host (A)
9. Leave name blank (apex) → IP: `192.168.1.100`
10. Add Host → Done
11. Repeat for wildcard: Name: `*` → IP: `192.168.1.100`

Repeat process for `x.com` and `t.co`.

### CoreDNS

Edit Corefile:

```
.:53 {
    # Redirect specific domains
    rewrite stop {
        name regex (.*\.)?twitter\.com twitter.com
        answer name twitter.com {$1}twitter.com
    }

    file /etc/coredns/db.redirect twitter.com
    file /etc/coredns/db.redirect x.com
    file /etc/coredns/db.redirect t.co

    # Forward everything else
    forward . 1.1.1.1 8.8.8.8
    cache
    errors
    log
}
```

Zone file `/etc/coredns/db.redirect`:

```
$ORIGIN twitter.com.
@   IN  A   192.168.1.100
*   IN  A   192.168.1.100
```

## Cloud/Managed DNS (Limited Options)

### Cloudflare DNS (Cloudflare Zero Trust)

If you're using Cloudflare Zero Trust (formerly Teams):

1. Gateway → Policies → DNS Policies
2. Create new policy
3. Selector: `Host`
4. Operator: `matches regex`
5. Value: `(.*\.)?twitter\.com|(.*\.)?x\.com|t\.co`
6. Action: Override
7. Override IPs: Your public IP (if nginx is exposed) or won't work for local IPs

**Note**: Cloudflare DNS cannot redirect to RFC1918 private IPs. Only useful if your nginx has a public IP.

### Google Public DNS / Quad9 / OpenDNS

Public DNS services cannot be customized. You must run your own DNS server.

## Per-Device Configuration (Without DNS Server)

If you can't configure a DNS server, you can modify each device's hosts file.

### Windows

```cmd
# Run as Administrator
notepad C:\Windows\System32\drivers\etc\hosts
```

Add:

```
192.168.1.100 twitter.com
192.168.1.100 www.twitter.com
192.168.1.100 x.com
192.168.1.100 www.x.com
192.168.1.100 t.co
192.168.1.100 www.t.co
```

Save and flush DNS:

```cmd
ipconfig /flushdns
```

### macOS / Linux

```bash
sudo vim /etc/hosts
```

Add same entries as above. Save and flush:

```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches
```

### iOS / Android

Requires jailbreak/root. Not recommended. Use network-wide DNS instead.

## Testing Your Configuration

Regardless of which method you used:

```bash
# Test DNS resolution
nslookup twitter.com
# Should return 192.168.1.100

nslookup x.com
# Should return 192.168.1.100

# Test the redirect
curl -I http://twitter.com
# Should show: HTTP/1.1 301 Moved Permanently
# Location: https://xcancel.com/
```

## Troubleshooting

### Changes Not Taking Effect

1. **Clear DNS caches:**
   - On DNS server: Restart DNS service
   - On clients: See [PIHOLE_SETUP.md](PIHOLE_SETUP.md) for flush commands
   - In browsers: Clear DNS cache

2. **Verify clients are using your DNS:**
   ```bash
   # Check what DNS server your device is using
   nslookup twitter.com
   # "Server:" line shows which DNS answered
   ```

3. **Check DNS server logs:**
   Most DNS servers log queries. Check for:
   - Is the query reaching your DNS server?
   - Is your override returning the correct IP?

### Wildcard Subdomains Not Working

Some DNS servers don't support wildcards in the way you configured them:

- **Works**: BIND, CoreDNS, dnsmasq, PowerDNS
- **Doesn't work**: Most router UIs, Windows DNS (need explicit entries)

Solution: Add specific subdomains manually:

```
192.168.1.100 mobile.twitter.com
192.168.1.100 api.twitter.com
192.168.1.100 mobile.x.com
```

### DNSSEC Conflicts

If you're using DNSSEC validation, custom overrides may fail validation:

- **pfSense/OPNsense**: Disable DNSSEC or add domain to DNSSEC exception list
- **BIND**: Use `validate-except { "twitter.com"; "x.com"; };`
- **Unbound**: Use `domain-insecure: "twitter.com"`

## Recommendations

For best results:

1. **Network-wide DNS** (router or Pi-hole) > Per-device configuration
2. **Dedicated DNS server** (Pi-hole/dnsmasq) > Router built-in DNS
3. **Wildcard support** (if you need subdomains) > Manual entries

If your router doesn't support custom DNS and you don't want to run a DNS server, the included dnsmasq container is your best option - see [DNSMASQ_SETUP.md](DNSMASQ_SETUP.md).

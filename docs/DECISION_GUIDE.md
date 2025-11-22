# Decision Guide

**Help choosing the right setup for your needs**

This guide helps you navigate the various options for setting up xcancel-forwarder. Use the flowcharts below to determine the best approach for your situation.

## Quick Decision Tree

```
START HERE
    │
    ├─ Do you want the fastest, easiest setup?
    │  └─ YES → Use Web Wizard (15 min) → DONE
    │
    ├─ Are you setting up on a headless server via SSH?
    │  └─ YES → Use CLI Wizard (10 min) → DONE
    │
    └─ Do you want to understand how everything works?
       └─ YES → Continue reading this guide
```

## Setup Method Decision

### Option 1: Web Wizard (Recommended for Most Users)

**Choose this if:**

- ✅ You want the simplest setup
- ✅ You prefer clicking buttons over typing commands
- ✅ You want guided configuration with visual feedback
- ✅ You're new to Docker or networking

**Launch**: [Web Wizard](https://ryantenney.github.io/xcancel-forwarder/setup-wizard.html)

**Time**: 10-15 minutes

### Option 2: CLI Wizard

**Choose this if:**

- ✅ You're setting up on a server without GUI
- ✅ You're comfortable with command line
- ✅ You want auto-detection of network settings
- ✅ You want automated mkcert execution

**Command**: `python3 scripts/setup-wizard.py`

**Time**: 5-10 minutes

### Option 3: Manual Setup

**Choose this if:**

- ✅ You want to learn how each component works
- ✅ You need custom configuration
- ✅ You're troubleshooting an issue
- ✅ You enjoy understanding systems deeply

**Start**: Follow [QUICKSTART.md](QUICKSTART.md)

**Time**: 20-30 minutes

## DNS Method Decision

```
Do you already have Pi-hole?
    │
    ├─ YES → Use Pi-hole DNS override
    │        └─ Guide: PIHOLE_SETUP.md
    │        └─ Pros: Easy web UI, already familiar
    │        └─ Cons: None
    │
    └─ NO
        │
        ├─ Do you want a dedicated DNS server?
        │  │
        │  ├─ YES → Use included dnsmasq
        │  │        └─ Guide: DNSMASQ_SETUP.md
        │  │        └─ Pros: Fast, lightweight, full-featured
        │  │        └─ Cons: One more container to manage
        │  │
        │  └─ NO
        │      │
        │      ├─ Can you access your router's DNS settings?
        │      │  │
        │      │  ├─ YES → Use router DNS override
        │      │  │        └─ Guide: OTHER_DNS.md (Router section)
        │      │  │        └─ Pros: Network-wide, no additional services
        │      │  │        └─ Cons: Router-dependent, may be limited
        │      │  │
        │      │  └─ NO → Use per-device hosts file
        │      │           └─ Guide: OTHER_DNS.md (Hosts file section)
        │      │           └─ Pros: No DNS server needed, simple
        │      │           └─ Cons: Must configure each device individually
```

### DNS Method Comparison

| Method | Difficulty | Network-Wide | Best For | Limitations |
|--------|------------|--------------|----------|-------------|
| **Pi-hole** | Easy | ✅ Yes | Existing Pi-hole users | Requires Pi-hole |
| **dnsmasq** | Medium | ✅ Yes | Dedicated DNS server | One more container |
| **Router** | Medium | ✅ Yes | Simple network-wide setup | Router-dependent |
| **Hosts file** | Easy | ❌ No | Single device, no Docker DNS | Per-device config |

### Detailed DNS Decision Criteria

#### Choose Pi-hole if:

- You already have Pi-hole running
- You want web UI configuration
- You're familiar with Pi-hole

**Setup time**: 5 minutes

#### Choose dnsmasq if:

- You want a dedicated DNS server
- You don't have Pi-hole
- You want lightweight, fast DNS
- You're comfortable with config files

**Setup time**: 10-15 minutes

#### Choose Router DNS if:

- You can access router admin panel
- Your router supports static DNS entries
- You want network-wide without additional services
- Your router supports wildcards (check first)

**Setup time**: 10 minutes (varies by router)

#### Choose Hosts File if:

- You only need this on one device
- You can't run a DNS server
- You want simplest possible setup
- You don't mind manual per-device config

**Setup time**: 5 minutes per device

## SSL Certificate Decision

```
Do you want HTTPS interception?
    │
    ├─ NO → Skip SSL setup (HTTP only)
    │        └─ Pros: Simplest, no certificate management
    │        └─ Cons: Browser warnings for https://twitter.com
    │        └─ Action: Comment out SSL config in nginx
    │
    └─ YES
        │
        ├─ Do you want the easiest SSL setup?
        │  │
        │  ├─ YES → Use mkcert
        │  │        └─ Guide: SSL_SETUP_MKCERT.md
        │  │        └─ Pros: Automatic CA installation, simple commands
        │  │        └─ Cons: Requires mkcert installation
        │  │        └─ Time: 10 minutes
        │  │
        │  └─ NO
        │      │
        │      └─ Want full control over CA parameters?
        │         │
        │         ├─ YES → Use manual OpenSSL
        │         │        └─ Guide: SSL_SETUP.md
        │         │        └─ Pros: Complete control, learn PKI
        │         │        └─ Cons: More complex, manual steps
        │         │        └─ Time: 20-30 minutes
        │         │
        │         └─ NO → Use mkcert (it's really easier)
```

### SSL Method Comparison

| Method | Difficulty | Setup Time | Best For | Learn PKI |
|--------|------------|------------|----------|-----------|
| **No SSL** | Easiest | 0 min | HTTP-only, testing | No |
| **mkcert** | Easy | 10 min | Most users, quick setup | No |
| **OpenSSL** | Hard | 30 min | Learning, full control | Yes |

### SSL Decision Criteria

#### Skip SSL if:

- You only want HTTP redirect (twitter.com works, not https://twitter.com)
- You're testing the setup
- You don't mind browser warnings
- You only access via HTTP links

**Browser experience**: Works for http://twitter.com, warnings for https://twitter.com

#### Choose mkcert if:

- You want HTTPS to work without warnings
- You want automatic CA installation
- You prefer simple commands
- You don't need to understand PKI details

**Browser experience**: Seamless HTTPS, no warnings

**Installation**: `brew install mkcert` (macOS), package manager on Linux

#### Choose Manual OpenSSL if:

- You want to learn about PKI/certificates
- You need specific CA parameters
- You want full control over certificate generation
- You're comfortable with OpenSSL commands

**Browser experience**: Seamless HTTPS, no warnings (once CA installed)

**Learning value**: High - understand certificate signing, trust chains

## Web Server Decision

```
Do you already know nginx?
    │
    ├─ YES → Use nginx (default)
    │        └─ Pros: You're familiar, powerful, widely used
    │        └─ Cons: More complex config
    │
    └─ NO
        │
        ├─ Do you want the simplest possible configuration?
        │  │
        │  ├─ YES → Use Caddy
        │  │        └─ Guide: CADDY_ALTERNATIVE.md
        │  │        └─ Pros: 4-line config, easier to understand
        │  │        └─ Cons: Less common, different paradigm
        │  │        └─ Config: docker-compose.caddy.yaml
        │  │
        │  └─ NO → Use nginx (default)
        │           └─ Pros: Industry standard, lots of examples
        │           └─ Cons: 27-line config vs Caddy's 4 lines
```

### Web Server Comparison

| Feature | nginx | Caddy |
|---------|-------|-------|
| **Config Lines** | 27 | 4 |
| **Learning Curve** | Steeper | Gentler |
| **Performance** | Excellent | Excellent |
| **Common Issues** | More docs available | Less common, fewer examples |
| **Industry Usage** | Very common | Growing |
| **Best For** | Production, familiarity | Simplicity, learning |

### When to Choose Each

#### Choose nginx if:

- You know nginx already
- You want battle-tested, widely-used software
- You anticipate complex future requirements
- You prefer familiar technology

#### Choose Caddy if:

- You're new to reverse proxies
- You want simpler configuration
- You prefer modern, minimal config
- Config file readability matters

**Note**: Both perform identically for this use case. The difference is purely configuration complexity.

## Networking Decision

```
Do you have Pi-hole or dnsmasq DNS server on the Docker host?
    │
    ├─ YES → Use macvlan networking
    │        └─ Pros: Dedicated IP, DNS server can reach it
    │        └─ Cons: Docker host can't reach container directly
    │        └─ Setup: Uncomment macvlan section in docker-compose.yaml
    │
    └─ NO
        │
        ├─ Do you want nginx on a separate IP?
        │  │
        │  ├─ YES → Use macvlan networking
        │  │        └─ Pros: Clean IP separation, dedicated address
        │  │        └─ Cons: More complex, Docker host isolation
        │  │
        │  └─ NO → Use bridge networking (default)
        │           └─ Pros: Simpler, standard Docker
        │           └─ Cons: Uses host IP, port forwarding
```

### Networking Comparison

| Mode | Complexity | nginx IP | Best For | Limitations |
|------|------------|----------|----------|-------------|
| **Bridge** | Simple | Host IP | Simple setups | Port conflicts possible |
| **Macvlan** | Medium | Dedicated IP | DNS server on host, IP separation | Host can't reach directly |

### Networking Decision Criteria

#### Choose Bridge if:

- You're new to Docker networking
- Your DNS server is not on the Docker host
- You want simplest possible setup
- Ports 80/443 are available on host

**Configuration**: Default in docker-compose.yaml

#### Choose Macvlan if:

- Pi-hole or dnsmasq runs on same host as nginx
- You want nginx on its own IP address
- You understand Docker networking
- You don't need Docker host to reach nginx directly

**Configuration**: Uncomment macvlan section, set IP/subnet in .env

## Full Setup Path Examples

### Path 1: Absolute Beginner with Pi-hole

1. **Setup Method**: Web Wizard
2. **Web Server**: nginx (default)
3. **SSL**: mkcert (easiest)
4. **DNS**: Pi-hole (you already have it)
5. **Networking**: macvlan (Pi-hole on same host)

**Total Time**: 20-25 minutes

### Path 2: Headless Server Without Existing DNS

1. **Setup Method**: CLI Wizard
2. **Web Server**: Caddy (simpler config)
3. **SSL**: mkcert (automated in wizard)
4. **DNS**: dnsmasq (included, dedicated server)
5. **Networking**: macvlan (dnsmasq on same host)

**Total Time**: 15-20 minutes

### Path 3: Learning-Focused Manual Setup

1. **Setup Method**: Manual
2. **Web Server**: nginx (learn industry standard)
3. **SSL**: Manual OpenSSL (learn PKI)
4. **DNS**: dnsmasq (learn DNS server config)
5. **Networking**: macvlan (learn Docker networking)

**Total Time**: 60-90 minutes (educational)

### Path 4: Single Device, Minimal Setup

1. **Setup Method**: Manual
2. **Web Server**: Caddy (simplest)
3. **SSL**: Skip (HTTP only)
4. **DNS**: Hosts file (no DNS server)
5. **Networking**: Bridge (default)

**Total Time**: 10 minutes

### Path 5: Router-Based Network-Wide

1. **Setup Method**: Web Wizard
2. **Web Server**: nginx (default)
3. **SSL**: mkcert (easy HTTPS)
4. **DNS**: Router static DNS
5. **Networking**: Bridge (default)

**Total Time**: 20-25 minutes

## Decision Summary Checklist

Use this to finalize your choices:

- [ ] **Setup method**: Web Wizard / CLI Wizard / Manual
- [ ] **Web server**: nginx / Caddy
- [ ] **SSL method**: None / mkcert / Manual OpenSSL
- [ ] **DNS method**: Pi-hole / dnsmasq / Router / Hosts file
- [ ] **Networking**: Bridge / Macvlan

Once decided, proceed to the appropriate guides:

- Web Wizard: [Launch it](https://ryantenney.github.io/xcancel-forwarder/setup-wizard.html)
- CLI Wizard: Run `python3 scripts/setup-wizard.py`
- Manual Setup: Start with [QUICKSTART.md](QUICKSTART.md)

## Still Unsure?

### "I just want it to work" Fast Path

**Recommended setup**:

- **Method**: Web Wizard (easiest)
- **Web Server**: nginx (default, leave unchanged)
- **SSL**: mkcert (easiest HTTPS)
- **DNS**: Whatever you have (wizard will guide)
- **Networking**: Leave at default (wizard handles it)

**Action**: [Launch Web Wizard](https://ryantenney.github.io/xcancel-forwarder/setup-wizard.html)

### "I want to learn" Educational Path

**Recommended setup**:

- **Method**: Manual
- **Web Server**: nginx (industry standard)
- **SSL**: Manual OpenSSL (learn PKI)
- **DNS**: dnsmasq (learn DNS servers)
- **Networking**: Macvlan (learn Docker networking)

**Action**: Read [QUICKSTART.md](QUICKSTART.md) and follow along

### "I want fastest setup" Speed Run

**Recommended setup**:

- **Method**: CLI Wizard
- **Web Server**: Caddy (4-line config)
- **SSL**: mkcert (automated)
- **DNS**: dnsmasq (included)
- **Networking**: macvlan (wizard handles it)

**Action**: Run `python3 scripts/setup-wizard.py`

## Common Questions

### Q: Can I change my choices later?

**A**: Yes! Most choices are not permanent:

- Web server: Switch between nginx/Caddy anytime
- SSL: Add later or switch methods
- DNS: Change method whenever needed
- Networking: Edit docker-compose.yaml and restart

### Q: Which setup is most reliable?

**A**: All setups are equally reliable once configured. Choose based on your comfort level, not reliability concerns.

### Q: What do you recommend for production?

**A**: This is intended for home networks. For "production home use":

- nginx (battle-tested)
- mkcert (easiest SSL maintenance)
- Pi-hole or dnsmasq (robust DNS)
- macvlan (cleaner network separation)

### Q: What's the minimal working setup?

**A**:

- nginx with HTTP only (no SSL)
- Bridge networking
- Hosts file DNS
- Can be running in 10 minutes

### Q: I made wrong choices, now what?

**A**: No problem! Most choices can be changed by:

1. Editing docker-compose.yaml
2. Editing .env
3. Running `docker compose down && docker compose up -d`

See relevant guide for your desired configuration.

## Related Documentation

- [Quick Start Guide](QUICKSTART.md) - Detailed manual setup
- [Quick Reference](QUICK_REFERENCE.md) - Commands cheat sheet
- [SSL Setup (mkcert)](SSL_SETUP_MKCERT.md) - Easy SSL
- [SSL Setup (OpenSSL)](SSL_SETUP.md) - Advanced SSL
- [Pi-hole Setup](PIHOLE_SETUP.md) - Pi-hole configuration
- [dnsmasq Setup](DNSMASQ_SETUP.md) - dnsmasq configuration
- [Other DNS Options](OTHER_DNS.md) - Router, BIND, hosts file
- [Caddy Alternative](CADDY_ALTERNATIVE.md) - Caddy web server
- [Testing Guide](TESTING.md) - Verification procedures

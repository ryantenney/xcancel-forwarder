# Manual Testing Guide

Comprehensive testing guide for the xcancel-forwarder setup wizard (HTML) and CLI setup script.

**Last Updated:** 2025-11-22

**Test Coverage:** ~95% of features

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [HTML Wizard Tests](#html-wizard-tests)
3. [CLI Script Tests](#cli-script-tests)
4. [Cross-Validation Tests](#cross-validation-tests)
5. [Test Results Template](#test-results-template)

---

## Prerequisites

### Environment Setup

- ✅ macOS, Linux, or WSL
- ✅ Docker and docker-compose installed
- ✅ OpenSSL installed
- ✅ Web browser (for HTML wizard)
- ✅ Terminal access (for CLI script)

### Test Data

**Network Information (for macvlan tests):**
- LAN Interface: `eth0` or `en0`
- LAN Subnet: `192.168.1.0/24`
- LAN Gateway: `192.168.1.1`
- Test Server IP: `192.168.1.100`

**Certificate Parameters:**
- Country: `US`
- State: `Test`
- Locality: `Local`
- Organization: `xcancel-test`
- Organizational Unit: `Testing`
- Validity: `1` year (for testing)

---

## HTML Wizard Tests

### Test Suite 1: Basic Happy Path (Caddy + Bridge + Auto SSL + Pi-hole)

**Objective:** Test the most common configuration path.

**Steps:**

1. Open `setup-wizard.html` in a web browser
2. Click "Get Started"
3. **Web Server:** Select "Caddy (Recommended)" → Click "Next"
4. **Networking:** Select "Bridge (Simple)" → Click "Next"
5. **SSL:** Select "🔥 Generate in Browser (Easiest)" → Click "Next"
6. **Certificate Generation:**
   - Leave "Discard CA Key (Recommended)" selected
   - Leave all certificate parameters as default
   - Click "Generate Certificates"
   - Wait for completion (should show green success message)
7. Click "Next"
8. **DNS:** Select "Pi-hole (Recommended)" → Click "Next"
9. **Review:** Verify configuration shows:
   - Web Server: Caddy
   - Networking: Bridge - Simple port forwarding
   - SSL: Generate in Browser
   - DNS: Pi-hole
10. Click "📦 Download Configuration ZIP"
11. Wait for download to complete

**Expected Results:**

- ✅ Navigation flows smoothly without errors
- ✅ Certificate generation completes successfully
- ✅ Fingerprint is displayed (SHA-256 format)
- ✅ IP address step is SKIPPED (Pi-hole uses dynamic hosts)
- ✅ ZIP file downloads successfully
- ✅ No "(Recommended)" text in review display

**Validation:**

Extract and verify ZIP contents:

```bash
unzip xcancel-config.zip
cd xcancel-forwarder

# Verify structure
ls -la

# Should contain:
# - docker-compose.yml
# - caddy/Caddyfile
# - caddy/ssl/ca.pem
# - caddy/ssl/ca.crt
# - caddy/ssl/ca.cer
# - caddy/ssl/twitter_bundle.pem
# - caddy/ssl/twitter_key.pem
# - caddy/ssl/INSTALL_CA.md
# - caddy/ssl/README.md
# - xcancel.env
# - README.md

# Verify CA cert formats
ls -lh caddy/ssl/ca.*

# Should show 3 files: ca.pem, ca.crt, ca.cer
# ca.cer should be smaller (DER binary format)

# Verify ca.pem and ca.crt are identical
diff caddy/ssl/ca.pem caddy/ssl/ca.crt
# Should output nothing (files are identical)

# Verify ca.cer is valid DER
openssl x509 -in caddy/ssl/ca.cer -inform DER -noout -subject

# Verify NO ca.key file (discarded)
ls caddy/ssl/ca.key 2>/dev/null
# Should output: "No such file or directory"

# Verify Caddyfile has dynamic hosts.txt route
grep -A 5 "handle /hosts.txt" caddy/Caddyfile

# Verify docker-compose does NOT mount hosts.txt
grep "hosts.txt" docker-compose.yml
# Should output nothing (Pi-hole uses dynamic generation)

# Verify INSTALL_CA.md mentions multiple formats
grep "Multiple formats" caddy/ssl/INSTALL_CA.md

# Verify README has correct configuration
grep "DNS Method: pihole" README.md
```

**Pass Criteria:**
- All expected files present
- Three CA certificate formats exist and are valid
- No ca.key file present
- Caddyfile has dynamic hosts.txt route
- docker-compose does NOT mount static hosts.txt

---

### Test Suite 2: nginx + Bridge + Auto SSL + UniFi DNS

**Objective:** Test nginx path with UniFi DNS (requires IP address input).

**Steps:**

1. Open `setup-wizard.html` (refresh to reset state)
2. Click "Get Started"
3. **Web Server:** Select "nginx" → Click "Next"
4. **Networking:** Select "Bridge (Simple)" → Click "Next"
5. **SSL:** Select "🔥 Generate in Browser (Easiest)" → Click "Next"
6. **Certificate Generation:**
   - Select "🔄 Keep CA Key"
   - Enter password: `test1234`
   - Confirm password: `test1234`
   - Modify parameters:
     - Country: `US`
     - State: `TestState`
     - Locality: `TestCity`
   - Click "Generate Certificates"
7. Click "Next"
8. **DNS:** Select "UniFi/Ubiquiti" → Click "Next"
9. **Docker Host IP:**
   - Note the auto-detected IP
   - Enter: `192.168.1.50`
   - Click "Next"
10. **Review:** Verify configuration
11. Download ZIP

**Expected Results:**

- ✅ IP address step is shown (not skipped for UniFi)
- ✅ Detected IP is displayed
- ✅ Custom IP accepted
- ✅ CA key is encrypted and included

**Validation:**

```bash
unzip xcancel-config.zip -d test2
cd test2/xcancel-forwarder

# Verify nginx structure
ls -la nginx/conf.d/
ls -la nginx/ssl/

# Verify ca.key exists and is encrypted
ls -lh nginx/ssl/ca.key

# Try to read encrypted key without password (should fail)
openssl rsa -in nginx/ssl/ca.key -noout 2>&1 | grep -i "pass phrase"
# Should show password prompt error

# Verify with correct password
openssl rsa -in nginx/ssl/ca.key -passin pass:test1234 -noout -check
# Should output: "RSA key ok"

# Verify hosts.txt exists with correct IP
cat hosts.txt | grep "192.168.1.50"

# Verify docker-compose mounts hosts.txt
grep "hosts.txt:/etc/nginx/hosts.txt:ro" docker-compose.yml

# Verify nginx config has static hosts.txt (no dynamic route)
grep "handle /hosts.txt" nginx/conf.d/xcancel-redirect.conf
# Should output nothing (UniFi doesn't use dynamic hosts)
```

**Pass Criteria:**
- nginx configuration generated
- ca.key exists and is password-encrypted
- hosts.txt contains correct IP (192.168.1.50)
- docker-compose mounts hosts.txt

---

### Test Suite 3: Caddy + Macvlan + Skip SSL + dnsmasq

**Objective:** Test macvlan networking with dnsmasq.

**Steps:**

1. Open `setup-wizard.html` (refresh)
2. Click "Get Started"
3. **Web Server:** Select "Caddy" → Click "Next"
4. **Networking:** Select "Macvlan (Dedicated IP)" → Click "Next"
5. **SSL:** Select "Skip SSL (Not Recommended)" → Click "Next"
6. **DNS:** Verify "Included dnsmasq" is now ENABLED → Select it → Click "Next"
7. **Upstream DNS:** Select "Cloudflare (1.1.1.1, 1.0.0.1)" → Click "Next"
8. **Network Configuration:**
   - LAN Interface: `eth0`
   - LAN Subnet: `192.168.1.0/24`
   - LAN Gateway: `192.168.1.1`
   - Server IP: `192.168.1.100`
   - Click "Next"
9. **Review:** Verify configuration
10. Download ZIP

**Expected Results:**

- ✅ dnsmasq option is enabled for macvlan
- ✅ Network configuration step appears
- ✅ All network fields required
- ✅ IP address step is skipped (macvlan provides static IP)

**Validation:**

```bash
unzip xcancel-config.zip -d test3
cd test3/xcancel-forwarder

# Verify dnsmasq directory exists
ls -la dnsmasq/

# Verify dnsmasq.conf
cat dnsmasq/dnsmasq.conf

# Check upstream DNS
grep "server=1.1.1.1" dnsmasq/dnsmasq.conf
grep "server=1.0.0.1" dnsmasq/dnsmasq.conf

# Check DNS overrides point to server IP
grep "address=/twitter.com/192.168.1.100" dnsmasq/dnsmasq.conf
grep "address=/x.com/192.168.1.100" dnsmasq/dnsmasq.conf

# Verify docker-compose has macvlan network
grep "driver: macvlan" docker-compose.yml
grep "parent: eth0" docker-compose.yml
grep "subnet: 192.168.1.0/24" docker-compose.yml
grep "gateway: 192.168.1.1" docker-compose.yml

# Verify dnsmasq service exists
grep "dnsmasq:" docker-compose.yml

# Verify Caddyfile is HTTP-only
grep "tls" caddy/Caddyfile
# Should output nothing (SSL skipped)

# Verify no SSL directory
ls caddy/ssl 2>/dev/null
# Should output: "No such file or directory"
```

**Pass Criteria:**
- dnsmasq.conf generated with correct DNS servers
- macvlan network configured in docker-compose
- dnsmasq service included
- No SSL configuration present

---

### Test Suite 4: Skip Button & Navigation

**Objective:** Test skip button on IP address step and breadcrumb navigation.

**Steps:**

1. Open `setup-wizard.html` (refresh)
2. Click "Get Started"
3. **Web Server:** Select "Caddy" → Click "Next"
4. **Networking:** Select "Bridge" → Click "Next"
5. **SSL:** Select "Skip SSL" → Click "Next"
6. **DNS:** Select "Manual (Hosts File)" → Click "Next"
7. **Docker Host IP:** Click "Skip" button
8. **Review:** Verify configuration shows no IP
9. Click "Back" button (test breadcrumbs)
10. Should return to DNS Configuration (not IP address step)
11. Click "Next" to return to review
12. Download ZIP

**Expected Results:**

- ✅ Skip button present on IP address step
- ✅ Skip button styled correctly (gray background)
- ✅ Back navigation skips IP address step when skipped
- ✅ Breadcrumb navigation works correctly

**Validation:**

```bash
unzip xcancel-config.zip -d test4
cd test4/xcancel-forwarder

# Verify NO hosts.txt file
ls hosts.txt 2>/dev/null
# Should output: "No such file or directory"

# Verify docker-compose does NOT mount hosts.txt
grep "hosts.txt" docker-compose.yml
# Should output nothing
```

**Pass Criteria:**
- No hosts.txt file generated
- docker-compose has no hosts.txt mount
- Navigation works correctly with skip

---

### Test Suite 5: mkcert Instructions

**Objective:** Test mkcert instructions generation.

**Steps:**

1. Open `setup-wizard.html` (refresh)
2. Click "Get Started"
3. Select: Caddy → Bridge → "mkcert (Recommended)" → Pi-hole
4. Download ZIP

**Expected Results:**

- ✅ Certificate generation step is skipped
- ✅ Goes directly from SSL selection to DNS
- ✅ Instructions included in ZIP

**Validation:**

```bash
unzip xcancel-config.zip -d test5
cd test5/xcancel-forwarder

# Verify instructions exist
ls -la caddy/ssl/

# Should contain:
# - README.md
# - INSTALL_CA.md (template)
# - No certificate files

# Check README mentions mkcert
grep "mkcert" README.md

# Verify no certificates exist
ls caddy/ssl/*.pem 2>/dev/null
# Should output: "No such file or directory"
```

**Pass Criteria:**
- Instructions present
- No certificate files included
- README mentions mkcert setup

---

### Test Suite 6: Manual OpenSSL Script

**Objective:** Test manual OpenSSL script generation.

**Steps:**

1. Open `setup-wizard.html` (refresh)
2. Click "Get Started"
3. Select: nginx → Bridge → "Manual OpenSSL" → Router DNS
4. Modify certificate parameters:
   - Validity: 5 years
5. Enter IP: `10.0.0.50`
6. Download ZIP

**Expected Results:**

- ✅ OpenSSL commands displayed in wizard
- ✅ Commands include custom parameters
- ✅ Generated script included

**Validation:**

```bash
unzip xcancel-config.zip -d test6
cd test6/xcancel-forwarder

# Verify OpenSSL script exists
ls -la generate-certs.sh

# Verify script is executable
test -x generate-certs.sh && echo "Executable"

# Check script contains correct parameters
grep "days 1825" generate-certs.sh  # 5 years * 365 days

# Verify no certificates exist yet
ls nginx/ssl/*.pem 2>/dev/null
# Should output: "No such file or directory"

# Run the script to verify it works
./generate-certs.sh

# Verify certificates were created
ls -lh nginx/ssl/ca.pem nginx/ssl/ca.crt nginx/ssl/ca.cer
ls -lh nginx/ssl/twitter_bundle.pem nginx/ssl/twitter_key.pem

# Verify all three CA formats
openssl x509 -in nginx/ssl/ca.pem -noout -subject
openssl x509 -in nginx/ssl/ca.crt -noout -subject
openssl x509 -in nginx/ssl/ca.cer -inform DER -noout -subject
```

**Pass Criteria:**
- generate-certs.sh script included and executable
- Script contains correct parameters
- Running script generates all certificate formats
- All three CA formats valid

---

## CLI Script Tests

### Test Suite 7: CLI Interactive Mode (Basic Path)

**Objective:** Test interactive CLI with Caddy + Bridge + Auto SSL + Pi-hole.

**Steps:**

1. Run the setup script:
   ```bash
   ./setup.sh
   ```

2. Follow prompts:
   - Dependency check (should pass)
   - Web Server: Enter `1` (Caddy)
   - Networking: Enter `1` (Bridge)
   - SSL: Enter `1` (Auto-generate)
   - CA Key: Enter `1` (Discard)
   - Certificate parameters: Press Enter to accept defaults
   - DNS: Enter `1` (Pi-hole)
   - Confirm configuration: `y`

3. Wait for generation

**Expected Results:**

- ✅ Colorized output with emojis
- ✅ Progress indicators during cert generation
- ✅ Auto-detected Docker IP shown
- ✅ Files generated in `xcancel-config/` directory

**Validation:**

```bash
cd xcancel-config

# Verify structure (same as HTML wizard)
ls -la

# Verify all three CA cert formats
ls -lh caddy/ssl/ca.*

# Verify ca.pem and ca.crt are identical
diff caddy/ssl/ca.pem caddy/ssl/ca.crt

# Verify ca.cer is valid DER
openssl x509 -in caddy/ssl/ca.cer -inform DER -noout -subject

# Verify NO ca.key (discarded)
ls caddy/ssl/ca.key 2>/dev/null
# Should output: "No such file or directory"

# Verify README generated
cat README.md | head -20

# Verify INSTALL_CA.md mentions multiple formats
grep "Multiple formats" caddy/ssl/INSTALL_CA.md
```

**Pass Criteria:**
- All files generated correctly
- Three CA certificate formats present and valid
- Output is colorized and user-friendly
- Configuration matches selections

---

### Test Suite 8: CLI Non-Interactive Mode

**Objective:** Test fully automated CLI mode.

**Steps:**

Run with all flags:

```bash
./setup.sh --non-interactive \
           --web-server=nginx \
           --networking=bridge \
           --ssl=auto \
           --dns=unifi \
           --docker-ip=192.168.1.75 \
           --output=test-cli-output
```

**Expected Results:**

- ✅ No prompts shown
- ✅ Runs to completion automatically
- ✅ Files generated in specified directory

**Validation:**

```bash
cd test-cli-output

# Verify nginx configuration
ls -la nginx/

# Verify hosts.txt has correct IP
cat hosts.txt | grep "192.168.1.75"

# Verify all certificate formats
ls -lh nginx/ssl/ca.*

# Verify docker-compose
cat docker-compose.yml | grep nginx

# Verify README reflects configuration
grep "nginx" README.md
grep "unifi" README.md
```

**Pass Criteria:**
- Script completes without interaction
- Correct IP in hosts.txt
- All files generated properly

---

### Test Suite 9: CLI Config File Save/Load

**Objective:** Test configuration file save and load.

**Steps:**

1. Create a test config file:
   ```bash
   cat > test-config.conf <<EOF
   web_server=caddy
   networking=macvlan
   ssl_method=skip
   dns_method=dnsmasq
   lan_interface=eth0
   lan_subnet=192.168.1.0/24
   lan_gateway=192.168.1.1
   server_ip=192.168.1.150
   upstream_dns=8.8.8.8,8.8.4.4
   EOF
   ```

2. Load and use config:
   ```bash
   ./setup.sh --config=test-config.conf --non-interactive --output=test-cli-config
   ```

**Expected Results:**

- ✅ Configuration loaded successfully
- ✅ No prompts for configured values
- ✅ Files generated according to config

**Validation:**

```bash
cd test-cli-config

# Verify macvlan network
grep "driver: macvlan" docker-compose.yml
grep "parent: eth0" docker-compose.yml

# Verify dnsmasq config
cat dnsmasq/dnsmasq.conf | grep "server=8.8.8.8"

# Verify no SSL
ls caddy/ssl 2>/dev/null
# Should output: "No such file or directory"
```

**Pass Criteria:**
- Config file loaded successfully
- All settings applied correctly
- Files match configuration

---

### Test Suite 10: CLI Dry Run Mode

**Objective:** Test dry run without file generation.

**Steps:**

```bash
./setup.sh --non-interactive \
           --web-server=caddy \
           --networking=bridge \
           --ssl=auto \
           --dns=pihole \
           --dry-run \
           --output=test-dry-run
```

**Expected Results:**

- ✅ Shows "DRY RUN MODE" warnings
- ✅ No files created
- ✅ Configuration summary displayed

**Validation:**

```bash
# Verify directory does NOT exist
ls test-dry-run 2>/dev/null
# Should output: "No such file or directory"
```

**Pass Criteria:**
- No files or directories created
- Summary displayed correctly

---

### Test Suite 11: CLI with CA Key Password

**Objective:** Test encrypted CA key generation.

**Steps:**

Run interactively with password:

```bash
./setup.sh --output=test-cli-encrypted
```

- Web Server: Caddy
- Networking: Bridge
- SSL: Auto-generate
- CA Key: Keep (option 2)
- Encrypt key: Yes
- Password: `secure123`
- DNS: Pi-hole
- Confirm: y

**Expected Results:**

- ✅ Password prompt appears
- ✅ CA key encrypted with password
- ✅ Message confirms encryption

**Validation:**

```bash
cd test-cli-encrypted

# Verify ca.key exists
ls -lh caddy/ssl/ca.key

# Verify key is encrypted (requires password)
openssl rsa -in caddy/ssl/ca.key -noout 2>&1 | grep -i "pass phrase"

# Verify with correct password
openssl rsa -in caddy/ssl/ca.key -passin pass:secure123 -noout -check
# Should output: "RSA key ok"
```

**Pass Criteria:**
- ca.key file exists
- Key is encrypted (cannot read without password)
- Correct password decrypts key successfully

---

### Test Suite 12: CLI Auto-Detection

**Objective:** Test Docker IP and interface auto-detection.

**Steps:**

```bash
./setup.sh --verbose --output=test-cli-autodetect
```

- Watch for auto-detection messages in verbose output
- Verify detected values are shown
- Accept detected values

**Expected Results:**

- ✅ Docker host IP detected and shown
- ✅ Network interfaces detected (if macvlan selected)
- ✅ Verbose output shows detection methods

**Validation:**

```bash
# Compare detected IP with actual
./setup.sh --help  # Reset
hostname -I | awk '{print $1}'  # Compare with detected IP from wizard

# Verify detected IP matches system IP
cd test-cli-autodetect
cat hosts.txt  # Should show auto-detected IP
```

**Pass Criteria:**
- Correct IP detected
- Detected values shown to user
- Configuration uses detected values

---

## Cross-Validation Tests

### Test Suite 13: HTML vs CLI Output Comparison

**Objective:** Verify HTML wizard and CLI script generate identical configurations.

**Steps:**

1. **HTML Wizard:**
   - Caddy + Bridge + Auto SSL (discard key) + Pi-hole
   - Download as `html-output.zip`

2. **CLI Script:**
   ```bash
   ./setup.sh --non-interactive \
              --web-server=caddy \
              --networking=bridge \
              --ssl=auto \
              --dns=pihole \
              --output=cli-output
   ```

3. **Compare outputs:**

```bash
# Extract HTML output
unzip html-output.zip -d html-compare
cd html-compare/xcancel-forwarder

# Compare Caddyfile structure (ignoring whitespace differences)
diff -w caddy/Caddyfile ../../cli-output/caddy/Caddyfile

# Compare docker-compose structure
diff -w docker-compose.yml ../../cli-output/docker-compose.yml

# Verify both have three CA cert formats
ls -1 caddy/ssl/ca.* | wc -l  # Should be 3
ls -1 ../../cli-output/caddy/ssl/ca.* | wc -l  # Should be 3

# Verify INSTALL_CA.md mentions multiple formats in both
grep "Multiple formats" caddy/ssl/INSTALL_CA.md
grep "Multiple formats" ../../cli-output/caddy/ssl/INSTALL_CA.md
```

**Expected Results:**

- ✅ Caddyfile structure matches (content may differ slightly in comments)
- ✅ docker-compose.yml structure matches
- ✅ Both generate 3 CA certificate formats
- ✅ Both include INSTALL_CA.md with format descriptions
- ✅ Certificate fingerprints differ (different keys) but formats match

**Pass Criteria:**
- File structures identical
- Configuration logic matches
- Both generate complete, valid configs

---

### Test Suite 14: Certificate Format Validation

**Objective:** Verify all certificate formats across both tools.

**Test Matrix:**

| Source | CA Formats | Server Cert | Bundle | Key Handling |
|--------|-----------|-------------|--------|--------------|
| HTML (auto) | ✅ PEM, CRT, DER | ✅ | ✅ | ✅ Discard/Keep |
| HTML (manual script) | ✅ PEM, CRT, DER | ✅ | ✅ | ✅ |
| CLI (auto) | ✅ PEM, CRT, DER | ✅ | ✅ | ✅ Discard/Keep |
| CLI (manual script) | ✅ PEM, CRT, DER | ✅ | ✅ | ✅ |

**Validation Commands:**

```bash
# For each output directory, verify:

# 1. All three CA formats exist
ls -lh */ssl/ca.{pem,crt,cer}

# 2. PEM and CRT are identical
diff */ssl/ca.pem */ssl/ca.crt

# 3. DER is valid
openssl x509 -in */ssl/ca.cer -inform DER -noout -text

# 4. DER is smaller (binary vs base64)
stat -f%z */ssl/ca.cer  # Should be ~950-1000 bytes
stat -f%z */ssl/ca.pem  # Should be ~1300-1400 bytes

# 5. All formats have same content (different encoding)
openssl x509 -in */ssl/ca.pem -noout -modulus > pem-modulus.txt
openssl x509 -in */ssl/ca.crt -noout -modulus > crt-modulus.txt
openssl x509 -in */ssl/ca.cer -inform DER -noout -modulus > cer-modulus.txt
diff pem-modulus.txt crt-modulus.txt
diff pem-modulus.txt cer-modulus.txt

# 6. Server certificate is valid
openssl x509 -in */ssl/twitter_bundle.pem -noout -text | grep "Subject:"

# 7. Bundle contains both certs
grep -c "BEGIN CERTIFICATE" */ssl/twitter_bundle.pem
# Should output: 2 (server cert + CA cert)
```

**Pass Criteria:**
- All three CA formats generated by both tools
- Formats are valid and contain identical data
- DER format is binary (smaller size)
- Bundle contains both certificates

---

## Test Results Template

Use this template to record your test results:

```markdown
## Test Execution Results

**Tester:** [Your Name]
**Date:** [YYYY-MM-DD]
**Environment:** [macOS/Linux/WSL]
**Browser:** [For HTML tests]

### HTML Wizard Tests

| Test Suite | Status | Notes |
|------------|--------|-------|
| TS1: Happy Path (Caddy + Pi-hole) | ⬜ PASS / ⬜ FAIL | |
| TS2: nginx + UniFi | ⬜ PASS / ⬜ FAIL | |
| TS3: Macvlan + dnsmasq | ⬜ PASS / ⬜ FAIL | |
| TS4: Skip Button & Navigation | ⬜ PASS / ⬜ FAIL | |
| TS5: mkcert Instructions | ⬜ PASS / ⬜ FAIL | |
| TS6: Manual OpenSSL Script | ⬜ PASS / ⬜ FAIL | |

### CLI Script Tests

| Test Suite | Status | Notes |
|------------|--------|-------|
| TS7: Interactive Mode | ⬜ PASS / ⬜ FAIL | |
| TS8: Non-Interactive Mode | ⬜ PASS / ⬜ FAIL | |
| TS9: Config File Save/Load | ⬜ PASS / ⬜ FAIL | |
| TS10: Dry Run Mode | ⬜ PASS / ⬜ FAIL | |
| TS11: CA Key Password | ⬜ PASS / ⬜ FAIL | |
| TS12: Auto-Detection | ⬜ PASS / ⬜ FAIL | |

### Cross-Validation Tests

| Test Suite | Status | Notes |
|------------|--------|-------|
| TS13: HTML vs CLI Comparison | ⬜ PASS / ⬜ FAIL | |
| TS14: Certificate Formats | ⬜ PASS / ⬜ FAIL | |

### Issues Found

| Issue # | Severity | Test Suite | Description | Status |
|---------|----------|-----------|-------------|--------|
| 1 | | | | |
| 2 | | | | |

### Summary

**Total Tests:** 14
**Passed:** ___ / 14
**Failed:** ___ / 14
**Success Rate:** ___%

**Recommendation:** ⬜ APPROVE FOR RELEASE / ⬜ NEEDS FIXES
```

---

## Cleanup

After testing, clean up generated directories:

```bash
# Remove all test outputs
rm -rf xcancel-config test* cli-output html-compare
rm -f *.zip test-config.conf *-modulus.txt
```

---

## Notes

- **Estimated Testing Time:** 2-3 hours for complete suite
- **Quick Smoke Test:** Run TS1 and TS7 only (~15 minutes)
- **Critical Path Tests:** TS1, TS2, TS7, TS8, TS13, TS14
- **Optional Tests:** TS3, TS5, TS6, TS10 (edge cases and less common paths)

## Known Limitations

These features are intentionally not tested:

1. **Actual Docker container deployment** - Tests only verify config generation
2. **Real network connectivity** - Would require network infrastructure
3. **Pi-hole integration** - Would require running Pi-hole instance
4. **mkcert actual execution** - Would require mkcert installation
5. **Certificate installation on devices** - Manual process per platform
6. **Browser certificate validation** - Would require full deployment

These can be validated in a separate integration/E2E test suite if needed.

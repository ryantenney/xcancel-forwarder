# SSL Setup with mkcert (Simplified)

This guide uses [mkcert](https://github.com/FiloSottile/mkcert) - a simple tool that automatically creates and installs a local Certificate Authority, then generates trusted certificates. Much easier than manual OpenSSL!

## Why mkcert?

**mkcert advantages:**

- ✅ Automatic CA creation and installation
- ✅ Certificates trusted immediately (no manual CA installation)
- ✅ Cross-platform (macOS, Linux, Windows)
- ✅ Perfect for local development and network tools
- ✅ Simple three-command setup

**vs. Manual OpenSSL (see [SSL_SETUP.md](SSL_SETUP.md)):**

- ⚠️ Manual CA creation and signing
- ⚠️ Manual trust store installation on every device
- ⚠️ More complex certificate configuration
- ✅ More control over certificate parameters
- ✅ Works in environments without mkcert

Choose mkcert for simplicity, manual OpenSSL for maximum control.

## Prerequisites

- **macOS**: Homebrew installed
- **Linux**: Build tools (see installation section)
- **Windows**: Chocolatey or Scoop (see installation section)

## Installation

### macOS

```bash
brew install mkcert
brew install nss  # For Firefox support
```

### Linux (Debian/Ubuntu)

```bash
# Install certutil for Firefox support
sudo apt install libnss3-tools

# Install mkcert
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
```

### Linux (Arch/Manjaro)

```bash
sudo pacman -S mkcert
```

### Windows

```powershell
# Using Chocolatey
choco install mkcert

# Or using Scoop
scoop bucket add extras
scoop install mkcert
```

Verify installation:

```bash
mkcert -version
# Should show: v1.4.4 or later
```

## Part 1: Create and Install Local CA

This is a one-time setup that creates your Certificate Authority and installs it in your system trust store.

```bash
# Create local CA and install in system trust store
mkcert -install
```

**Output:**

```
Created a new local CA 💥
The local CA is now installed in the system trust store! ⚡️
The local CA is now installed in the Firefox trust store (requires browser restart)! 🦊
```

**What this does:**

- Creates a local CA in `~/.local/share/mkcert` (Linux) or `~/Library/Application Support/mkcert` (macOS)
- Installs the CA in your system keychain
- Installs the CA in Firefox's certificate store (if NSS tools installed)

**Find your CA files:**

```bash
# macOS
ls -la ~/Library/Application\ Support/mkcert/

# Linux
ls -la ~/.local/share/mkcert/

# Look for:
# rootCA.pem (CA certificate)
# rootCA-key.pem (CA private key - KEEP SECURE!)
```

## Part 2: Generate Certificates for Twitter/X Domains

```bash
# Generate certificate for all domains
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"
```

**Output:**

```
Created a new certificate valid for the following names 📜
 - "twitter.com"
 - "x.com"
 - "*.twitter.com"
 - "*.x.com"
 - "t.co"
 - "*.t.co"

The certificate is at "./twitter.com+5.pem" and the key at "./twitter.com+5-key.pem" ✅
```

**What you get:**

- `twitter.com+5.pem` - Certificate with all SANs
- `twitter.com+5-key.pem` - Private key

The "+5" means 5 additional SANs beyond the first domain.

## Part 3: Install Certificates in nginx

```bash
# Navigate to your xcancel-forwarder directory
cd /path/to/xcancel-forwarder

# Copy certificates to nginx
cp twitter.com+5.pem nginx/ssl/twitter_bundle.pem
cp twitter.com+5-key.pem nginx/ssl/twitter_key.pem

# Set proper permissions
chmod 644 nginx/ssl/twitter_bundle.pem
chmod 600 nginx/ssl/twitter_key.pem
```

**Verify nginx configuration** (`nginx/conf.d/xcancel-redirect.conf`):

```nginx
ssl_certificate     /etc/nginx/ssl/twitter_bundle.pem;
ssl_certificate_key /etc/nginx/ssl/twitter_key.pem;
```

**Restart nginx:**

```bash
docker compose restart nginx
```

## Part 4: Test on This Device

Your current device (where you ran mkcert) should already trust the certificates.

```bash
# Test certificate
openssl s_client -connect twitter.com:443 -servername twitter.com < /dev/null

# Look for:
# Verify return code: 0 (ok)
```

**Browser test:**

1. Visit `https://twitter.com`
2. Should redirect to xcancel.com with NO security warnings
3. Check padlock icon - certificate should be trusted

## Part 5: Install CA on Other Devices

For other devices on your network to trust your certificates, you need to install the CA certificate.

### Locate Your CA Certificate

```bash
# macOS
CA_CERT=~/Library/Application\ Support/mkcert/rootCA.pem

# Linux
CA_CERT=~/.local/share/mkcert/rootCA.pem

# Copy it somewhere accessible
cp "$CA_CERT" ~/Desktop/mkcert-ca.pem
```

### iOS/iPadOS

1. Email `mkcert-ca.pem` to yourself or upload to a web server
2. Open the file on your iOS device
3. Settings → General → VPN & Device Management
4. Tap the profile and install it
5. Settings → General → About → Certificate Trust Settings
6. Enable full trust for the certificate

### Android

1. Transfer `mkcert-ca.pem` to your device
2. Settings → Security → Encryption & credentials
3. Install from storage → CA certificate
4. Navigate to and select `mkcert-ca.pem`

### Windows (Other Computers)

```powershell
# Run PowerShell as Administrator
certutil -addstore -f "ROOT" mkcert-ca.pem
```

### Linux (Other Computers)

```bash
# Debian/Ubuntu
sudo cp mkcert-ca.pem /usr/local/share/ca-certificates/mkcert-ca.crt
sudo update-ca-certificates

# Arch/Manjaro
sudo trust anchor --store mkcert-ca.pem
```

### macOS (Other Computers)

```bash
# GUI method
open mkcert-ca.pem
# In Keychain Access, set to "Always Trust"

# Command line
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain mkcert-ca.pem
```

## Regenerating Certificates

If you need to regenerate (e.g., certificate expires or you need different domains):

```bash
# Generate new certificate (overwrites existing files)
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Copy to nginx
cp twitter.com+5.pem nginx/ssl/twitter_bundle.pem
cp twitter.com+5-key.pem nginx/ssl/twitter_key.pem

# Restart nginx
docker compose restart nginx
```

No need to reinstall CA on devices - it stays valid.

## Certificate Validity

mkcert certificates are valid for **825 days** (about 2.25 years) by default.

**Check expiration:**

```bash
openssl x509 -in twitter.com+5.pem -noout -dates
```

**Set reminder** to regenerate before expiration.

## Uninstalling mkcert CA

If you want to remove the CA from your system:

```bash
# Uninstall CA from system trust store
mkcert -uninstall

# Remove CA files
rm -rf ~/.local/share/mkcert  # Linux
rm -rf ~/Library/Application\ Support/mkcert  # macOS
```

You'll also need to manually remove the CA from any other devices where you installed it.

## Troubleshooting

### "mkcert is not configured for automatic CA installation"

You're on a system without GUI access or proper NSS tools.

**Solution:** Manually install the CA:

```bash
# Find CA location
mkcert -CAROOT

# Install manually (see Part 5 above)
```

### Certificates Not Trusted on This Device

```bash
# Reinstall CA
mkcert -uninstall
mkcert -install

# Restart browser
```

### Firefox Still Shows Warnings

```bash
# Install NSS tools
# macOS
brew install nss

# Linux
sudo apt install libnss3-tools

# Reinstall mkcert CA
mkcert -install
```

### Certificate Works on Some Devices, Not Others

Each device needs the CA installed independently (see Part 5).

### Wrong Domains in Certificate

Regenerate with correct domain list:

```bash
mkcert twitter.com x.com www.twitter.com www.x.com t.co www.t.co "*.twitter.com" "*.x.com"
```

## Security Considerations

### CA Private Key Security

mkcert stores your CA private key at:

- macOS: `~/Library/Application Support/mkcert/rootCA-key.pem`
- Linux: `~/.local/share/mkcert/rootCA-key.pem`

**KEEP THIS SECURE!** Anyone with this file can create trusted certificates for any domain on your devices.

**Best practices:**

- Don't commit to git (already in .gitignore)
- Don't store in cloud sync folders
- Backup encrypted to secure location
- Consider separate CA just for this project

### Scope of Trust

The CA only affects devices where you've installed it. It cannot intercept traffic on devices you don't control.

## Advantages Over Manual OpenSSL

**mkcert pros:**

- Automatic trust store installation
- Simple three-command setup
- Built-in Firefox support
- Cross-platform
- Proper certificate chain handling

**mkcert cons:**

- Requires installation (not available everywhere)
- Less control over certificate parameters
- CA tied to specific tool

## When to Use Manual OpenSSL Instead

Use [SSL_SETUP.md](SSL_SETUP.md) instead if:

- You can't install mkcert (restricted environment)
- You need specific certificate parameters
- You want maximum control over the CA
- You're learning about PKI/certificates
- You need to integrate with existing CA infrastructure

## Additional Resources

- [mkcert GitHub](https://github.com/FiloSottile/mkcert)
- [mkcert Documentation](https://github.com/FiloSottile/mkcert#readme)

## Quick Reference

```bash
# One-time setup
brew install mkcert
mkcert -install

# Generate certificates
mkcert twitter.com x.com "*.twitter.com" "*.x.com" t.co "*.t.co"

# Install in nginx
cp twitter.com+5.pem nginx/ssl/twitter_bundle.pem
cp twitter.com+5-key.pem nginx/ssl/twitter_key.pem
chmod 644 nginx/ssl/twitter_bundle.pem
chmod 600 nginx/ssl/twitter_key.pem

# Restart nginx
docker compose restart nginx

# Export CA for other devices
cp "$(mkcert -CAROOT)/rootCA.pem" ~/Desktop/mkcert-ca.pem
```

Done! Much simpler than OpenSSL, and certificates are immediately trusted on your current device.

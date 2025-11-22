#!/bin/bash
set -e

# X/Twitter → xcancel Setup Script
# Full-featured CLI alternative to setup-wizard.html

VERSION="1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration variables
WEB_SERVER=""
NETWORKING=""
SSL_METHOD=""
DNS_METHOD=""
DOCKER_HOST_IP=""
LAN_INTERFACE=""
LAN_SUBNET=""
LAN_GATEWAY=""
SERVER_IP=""
UPSTREAM_DNS=""
CA_KEY_HANDLING="discard"
CA_KEY_PASSWORD=""
SKIP_HOSTS_FILE=false
CERT_COUNTRY="US"
CERT_STATE="Local"
CERT_LOCALITY="Local"
CERT_ORG="xcancel-forwarder"
CERT_OU="Local Network"
CERT_VALIDITY_YEARS=10

# Runtime flags
NON_INTERACTIVE=false
DRY_RUN=false
START_AFTER_SETUP=false
CONFIG_FILE=""
SAVE_CONFIG=""
VERBOSE=false

# Output directory
OUTPUT_DIR="xcancel-config"

###########################################
# Helper Functions
###########################################

print_header() {
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║    🦅 X/Twitter → xcancel Setup Script           ║"
    echo "║    Version $VERSION                               ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${MAGENTA}▶ $1${NC}"
    echo -e "${MAGENTA}$(printf '─%.0s' {1..50})${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${CYAN}${spin:$i:1}${NC} $message"
        sleep 0.1
    done
    printf "\r"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
        local pattern="^[Nn]"
    else
        prompt="$prompt [y/N]: "
        local pattern="^[Yy]"
    fi

    read -p "$prompt" response

    if [ -z "$response" ] && [ "$default" = "y" ]; then
        return 0
    fi

    if [[ $response =~ $pattern ]]; then
        return 0
    fi

    return 1
}

###########################################
# Dependency Checking
###########################################

check_dependencies() {
    print_section "Checking Dependencies"

    local missing_deps=()

    # Check for required commands
    local required_cmds=("docker" "openssl")

    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "$cmd is installed"
        else
            print_error "$cmd is not installed"
            missing_deps+=("$cmd")
        fi
    done

    # Check for docker-compose or docker compose
    if command -v docker-compose &> /dev/null; then
        print_success "docker-compose is installed"
    elif docker compose version &> /dev/null 2>&1; then
        print_success "docker compose (plugin) is installed"
    else
        print_error "docker-compose is not installed"
        missing_deps+=("docker-compose")
    fi

    # Check for optional commands
    if command -v mkcert &> /dev/null; then
        print_info "mkcert is installed (optional)"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install missing dependencies and try again"
        exit 1
    fi
}

###########################################
# System Auto-Detection
###########################################

detect_docker_host_ip() {
    # Try multiple methods to detect Docker host IP
    local ip=""

    # Method 1: hostname -I (Linux)
    if command -v hostname &> /dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    # Method 2: ipconfig getifaddr en0 (macOS WiFi)
    if [ -z "$ip" ] && command -v ipconfig &> /dev/null; then
        ip=$(ipconfig getifaddr en0 2>/dev/null)
    fi

    # Method 3: ipconfig getifaddr en1 (macOS Ethernet)
    if [ -z "$ip" ]; then
        ip=$(ipconfig getifaddr en1 2>/dev/null)
    fi

    # Method 4: ip route (Linux)
    if [ -z "$ip" ] && command -v ip &> /dev/null; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    fi

    echo "$ip"
}

detect_network_interfaces() {
    local interfaces=()

    # Try ip command (Linux)
    if command -v ip &> /dev/null; then
        while IFS= read -r line; do
            interfaces+=("$line")
        done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
    # Try ifconfig (macOS/BSD)
    elif command -v ifconfig &> /dev/null; then
        while IFS= read -r line; do
            interfaces+=("$line")
        done < <(ifconfig -l | tr ' ' '\n' | grep -v '^lo0$')
    fi

    printf '%s\n' "${interfaces[@]}"
}

###########################################
# Interactive Configuration
###########################################

configure_web_server() {
    print_section "Web Server Selection"

    if [ "$NON_INTERACTIVE" = true ] && [ -n "$WEB_SERVER" ]; then
        print_info "Using web server: $WEB_SERVER"
        return
    fi

    echo ""
    echo "Choose your web server:"
    echo "  1) Caddy - Modern, automatic HTTPS, simpler configuration"
    echo "  2) nginx - Battle-tested, widely used, industry standard"
    echo ""

    PS3="Select web server [1-2]: "
    select choice in "Caddy" "nginx"; do
        case $choice in
            Caddy)
                WEB_SERVER="caddy"
                print_success "Selected: Caddy"
                break
                ;;
            nginx)
                WEB_SERVER="nginx"
                print_success "Selected: nginx"
                break
                ;;
        esac
    done
}

configure_networking() {
    print_section "Network Configuration"

    if [ "$NON_INTERACTIVE" = true ] && [ -n "$NETWORKING" ]; then
        print_info "Using networking mode: $NETWORKING"
        return
    fi

    echo ""
    echo "How should the container connect to your network?"
    echo "  1) Bridge - Simple port forwarding (easier setup)"
    echo "  2) Macvlan - Dedicated IP on LAN (required for dnsmasq)"
    echo ""

    PS3="Select networking mode [1-2]: "
    select choice in "Bridge" "Macvlan"; do
        case $choice in
            Bridge)
                NETWORKING="bridge"
                print_success "Selected: Bridge networking"
                break
                ;;
            Macvlan)
                NETWORKING="macvlan"
                print_success "Selected: Macvlan networking"
                break
                ;;
        esac
    done
}

configure_ssl() {
    print_section "SSL Configuration"

    if [ "$NON_INTERACTIVE" = true ] && [ -n "$SSL_METHOD" ]; then
        print_info "Using SSL method: $SSL_METHOD"
        return
    fi

    echo ""
    echo "SSL certificate options:"
    echo "  1) Auto-generate - Generate certificates using OpenSSL (recommended)"
    echo "  2) mkcert - Use mkcert for automatic CA and certificate generation"
    echo "  3) Manual - Generate OpenSSL commands for manual certificate creation"
    echo "  4) Skip - HTTP-only redirect (not recommended)"
    echo ""

    PS3="Select SSL method [1-4]: "
    select choice in "Auto-generate" "mkcert" "Manual" "Skip"; do
        case $choice in
            "Auto-generate")
                SSL_METHOD="auto"
                print_success "Selected: Auto-generate with OpenSSL"
                configure_ca_key_handling
                configure_cert_parameters
                break
                ;;
            mkcert)
                if ! command -v mkcert &> /dev/null; then
                    print_warning "mkcert is not installed"
                    if confirm "Install mkcert instructions will be provided. Continue?"; then
                        SSL_METHOD="mkcert"
                        print_success "Selected: mkcert"
                        break
                    fi
                else
                    SSL_METHOD="mkcert"
                    print_success "Selected: mkcert"
                    break
                fi
                ;;
            Manual)
                SSL_METHOD="manual"
                print_success "Selected: Manual OpenSSL"
                configure_cert_parameters
                break
                ;;
            Skip)
                if confirm "Skip SSL setup? This will use HTTP-only (not secure)" "n"; then
                    SSL_METHOD="skip"
                    print_warning "SSL disabled - HTTP-only mode"
                    break
                fi
                ;;
        esac
    done
}

configure_ca_key_handling() {
    echo ""
    echo "CA Private Key Handling:"
    echo "  1) Discard - More secure, but certificates cannot be renewed"
    echo "  2) Keep - Include CA key in output (allows renewal, requires secure storage)"
    echo ""

    PS3="CA key handling [1-2]: "
    select choice in "Discard" "Keep"; do
        case $choice in
            Discard)
                CA_KEY_HANDLING="discard"
                print_success "CA key will be discarded after signing"
                break
                ;;
            Keep)
                CA_KEY_HANDLING="keep"
                if confirm "Encrypt CA key with password?" "y"; then
                    read -sp "Enter password for CA key: " CA_KEY_PASSWORD
                    echo ""
                    print_success "CA key will be encrypted with password"
                else
                    print_warning "CA key will be stored unencrypted"
                fi
                break
                ;;
        esac
    done
}

configure_cert_parameters() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return
    fi

    echo ""
    echo "Certificate Parameters (press Enter to use defaults):"

    read -p "Country (C) [$CERT_COUNTRY]: " input
    CERT_COUNTRY="${input:-$CERT_COUNTRY}"

    read -p "State/Province (ST) [$CERT_STATE]: " input
    CERT_STATE="${input:-$CERT_STATE}"

    read -p "Locality/City (L) [$CERT_LOCALITY]: " input
    CERT_LOCALITY="${input:-$CERT_LOCALITY}"

    read -p "Organization (O) [$CERT_ORG]: " input
    CERT_ORG="${input:-$CERT_ORG}"

    read -p "Organizational Unit (OU) [$CERT_OU]: " input
    CERT_OU="${input:-$CERT_OU}"

    read -p "Certificate validity (years) [$CERT_VALIDITY_YEARS]: " input
    CERT_VALIDITY_YEARS="${input:-$CERT_VALIDITY_YEARS}"
}

configure_dns() {
    print_section "DNS Configuration"

    if [ "$NON_INTERACTIVE" = true ] && [ -n "$DNS_METHOD" ]; then
        print_info "Using DNS method: $DNS_METHOD"
        return
    fi

    echo ""
    echo "How will you configure DNS?"
    echo "  1) Pi-hole - Network-wide ad blocking with DNS override"

    if [ "$NETWORKING" = "macvlan" ]; then
        echo "  2) Included dnsmasq - Run a DNS server container"
    else
        echo "  2) Included dnsmasq - (requires macvlan networking)"
    fi

    echo "  3) UniFi/Ubiquiti - UniFi Dream Machine or USG"
    echo "  4) Router - Use router's built-in DNS override"
    echo "  5) Manual - Edit /etc/hosts on each device"
    echo ""

    PS3="Select DNS method [1-5]: "
    select choice in "Pi-hole" "dnsmasq" "UniFi" "Router" "Manual"; do
        case $choice in
            Pi-hole)
                DNS_METHOD="pihole"
                print_success "Selected: Pi-hole (dynamic hosts file)"
                break
                ;;
            dnsmasq)
                if [ "$NETWORKING" != "macvlan" ]; then
                    print_error "dnsmasq requires macvlan networking"
                    continue
                fi
                DNS_METHOD="dnsmasq"
                print_success "Selected: Included dnsmasq"
                configure_dnsmasq
                break
                ;;
            UniFi|Router|Manual)
                DNS_METHOD=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
                print_success "Selected: $choice"

                # These methods need Docker host IP (unless macvlan)
                if [ "$NETWORKING" != "macvlan" ]; then
                    configure_docker_host_ip
                fi
                break
                ;;
        esac
    done
}

configure_docker_host_ip() {
    local detected_ip
    detected_ip=$(detect_docker_host_ip)

    echo ""
    print_info "Docker Host IP Address"
    echo "This IP will be used in the generated hosts file to redirect"
    echo "twitter.com/x.com traffic to your proxy."
    echo ""

    if [ -n "$detected_ip" ]; then
        echo "Detected IP: $detected_ip"
    fi

    if [ "$NON_INTERACTIVE" = true ]; then
        DOCKER_HOST_IP="${DOCKER_HOST_IP:-$detected_ip}"
        print_info "Using Docker host IP: $DOCKER_HOST_IP"
        return
    fi

    while true; do
        read -p "Docker host IP address [$detected_ip]: " input
        DOCKER_HOST_IP="${input:-$detected_ip}"

        # Validate IP address
        if [[ $DOCKER_HOST_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            print_success "Using Docker host IP: $DOCKER_HOST_IP"
            break
        else
            print_error "Invalid IP address format"
        fi
    done

    if confirm "Skip hosts file generation?" "n"; then
        SKIP_HOSTS_FILE=true
        print_info "Hosts file will not be generated"
    fi
}

configure_dnsmasq() {
    echo ""
    print_info "dnsmasq Configuration"

    # Upstream DNS
    echo ""
    echo "Upstream DNS servers:"
    echo "  1) Cloudflare (1.1.1.1, 1.0.0.1)"
    echo "  2) Google (8.8.8.8, 8.8.4.4)"
    echo "  3) Quad9 (9.9.9.9, 149.112.112.112)"
    echo "  4) Custom"
    echo ""

    PS3="Select upstream DNS [1-4]: "
    select choice in "Cloudflare" "Google" "Quad9" "Custom"; do
        case $choice in
            Cloudflare)
                UPSTREAM_DNS="1.1.1.1,1.0.0.1"
                print_success "Using Cloudflare DNS"
                break
                ;;
            Google)
                UPSTREAM_DNS="8.8.8.8,8.8.4.4"
                print_success "Using Google DNS"
                break
                ;;
            Quad9)
                UPSTREAM_DNS="9.9.9.9,149.112.112.112"
                print_success "Using Quad9 DNS"
                break
                ;;
            Custom)
                read -p "Enter upstream DNS servers (comma-separated): " UPSTREAM_DNS
                print_success "Using custom DNS: $UPSTREAM_DNS"
                break
                ;;
        esac
    done

    configure_macvlan_network
}

configure_macvlan_network() {
    echo ""
    print_info "Macvlan Network Configuration"

    # Detect network interfaces
    local interfaces
    mapfile -t interfaces < <(detect_network_interfaces)

    if [ ${#interfaces[@]} -eq 0 ]; then
        print_warning "Could not auto-detect network interfaces"
        read -p "Enter LAN interface name: " LAN_INTERFACE
    else
        echo ""
        echo "Available network interfaces:"
        PS3="Select LAN interface: "
        select iface in "${interfaces[@]}"; do
            if [ -n "$iface" ]; then
                LAN_INTERFACE="$iface"
                print_success "Selected interface: $LAN_INTERFACE"
                break
            fi
        done
    fi

    # LAN subnet
    echo ""
    read -p "LAN subnet (e.g., 192.168.1.0/24): " LAN_SUBNET
    while [[ ! $LAN_SUBNET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; do
        print_error "Invalid subnet format"
        read -p "LAN subnet (e.g., 192.168.1.0/24): " LAN_SUBNET
    done

    # LAN gateway
    read -p "LAN gateway (e.g., 192.168.1.1): " LAN_GATEWAY
    while [[ ! $LAN_GATEWAY =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
        print_error "Invalid IP address format"
        read -p "LAN gateway: " LAN_GATEWAY
    done

    # Server IP
    read -p "Server IP address (on LAN): " SERVER_IP
    while [[ ! $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
        print_error "Invalid IP address format"
        read -p "Server IP address: " SERVER_IP
    done

    print_success "Macvlan network configured"
}

###########################################
# Configuration Summary
###########################################

show_summary() {
    print_section "Configuration Summary"

    echo ""
    echo -e "${BOLD}Your Configuration:${NC}"
    echo ""
    echo "  Web Server:    $WEB_SERVER"
    echo "  Networking:    $NETWORKING"
    echo "  SSL:           $SSL_METHOD"
    echo "  DNS:           $DNS_METHOD"

    if [ "$NETWORKING" = "macvlan" ]; then
        echo ""
        echo "  LAN Interface: $LAN_INTERFACE"
        echo "  LAN Subnet:    $LAN_SUBNET"
        echo "  LAN Gateway:   $LAN_GATEWAY"
        echo "  Server IP:     $SERVER_IP"
    fi

    if [ "$DNS_METHOD" = "dnsmasq" ]; then
        echo "  Upstream DNS:  $UPSTREAM_DNS"
    fi

    if [ -n "$DOCKER_HOST_IP" ]; then
        echo "  Docker IP:     $DOCKER_HOST_IP"
    fi

    if [ "$SSL_METHOD" = "auto" ]; then
        echo ""
        echo "  CA Key:        $CA_KEY_HANDLING"
        if [ "$CA_KEY_HANDLING" = "keep" ] && [ -n "$CA_KEY_PASSWORD" ]; then
            echo "  CA Encrypted:  Yes"
        fi
    fi

    echo ""
}

###########################################
# File Generation
###########################################

generate_configs() {
    print_section "Generating Configuration Files"

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No files will be created"
        return
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    print_success "Created directory: $OUTPUT_DIR"

    # Generate files based on configuration
    generate_env_file
    generate_docker_compose
    generate_web_server_config

    if [ "$DNS_METHOD" = "dnsmasq" ]; then
        generate_dnsmasq_config
    fi

    if [ "$DNS_METHOD" != "dnsmasq" ] && [ "$DNS_METHOD" != "pihole" ] && [ "$SKIP_HOSTS_FILE" = false ]; then
        generate_hosts_file
    fi

    if [ "$SSL_METHOD" = "auto" ]; then
        generate_ssl_certificates
    elif [ "$SSL_METHOD" = "manual" ]; then
        generate_openssl_script
    elif [ "$SSL_METHOD" = "mkcert" ]; then
        generate_mkcert_instructions
    fi

    generate_readme

    print_success "Configuration files generated in: $OUTPUT_DIR"
}

generate_env_file() {
    print_verbose "Generating xcancel.env"

    cat > "$OUTPUT_DIR/xcancel.env" <<'EOF'
# xcancel Environment Configuration
# This file contains environment variables for the xcancel proxy service

# Target URL for redirection
XCANCEL_URL=https://xcancel.com

# Add any additional environment variables here
EOF

    print_success "Generated: xcancel.env"
}

generate_docker_compose() {
    print_verbose "Generating docker-compose.yml"

    local compose_file="$OUTPUT_DIR/docker-compose.yml"

    cat > "$compose_file" <<EOF
version: '3.8'

services:
EOF

    # Add web server service
    if [ "$WEB_SERVER" = "caddy" ]; then
        cat >> "$compose_file" <<EOF
  caddy:
    image: caddy:latest
    container_name: xcancel-caddy
    restart: unless-stopped
EOF
    else
        cat >> "$compose_file" <<EOF
  nginx:
    image: nginx:latest
    container_name: xcancel-nginx
    restart: unless-stopped
EOF
    fi

    # Add ports
    if [ "$NETWORKING" = "bridge" ]; then
        cat >> "$compose_file" <<EOF
    ports:
      - "80:80"
      - "443:443"
EOF
    fi

    # Add volumes
    cat >> "$compose_file" <<EOF
    volumes:
      - ./xcancel.env:/etc/xcancel.env:ro
EOF

    if [ "$WEB_SERVER" = "caddy" ]; then
        cat >> "$compose_file" <<EOF
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
EOF

        if [ "$SSL_METHOD" != "skip" ]; then
            cat >> "$compose_file" <<EOF
      - ./caddy/ssl:/etc/caddy/ssl:ro
EOF
        fi

        # Add hosts.txt for non-Pi-hole DNS methods
        if [ "$DNS_METHOD" != "dnsmasq" ] && [ "$DNS_METHOD" != "pihole" ] && [ "$SKIP_HOSTS_FILE" = false ]; then
            cat >> "$compose_file" <<EOF
      - ./hosts.txt:/etc/caddy/hosts.txt:ro
EOF
        fi
    else
        cat >> "$compose_file" <<EOF
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/logs:/var/log/nginx
EOF

        if [ "$SSL_METHOD" != "skip" ]; then
            cat >> "$compose_file" <<EOF
      - ./nginx/ssl:/etc/nginx/ssl:ro
EOF
        fi

        # Add hosts.txt for non-Pi-hole DNS methods
        if [ "$DNS_METHOD" != "dnsmasq" ] && [ "$DNS_METHOD" != "pihole" ] && [ "$SKIP_HOSTS_FILE" = false ]; then
            cat >> "$compose_file" <<EOF
      - ./nginx/hosts.txt:/etc/nginx/hosts.txt:ro
EOF
        fi
    fi

    # Add network configuration
    if [ "$NETWORKING" = "macvlan" ]; then
        cat >> "$compose_file" <<EOF
    networks:
      xcancel_net:
        ipv4_address: $SERVER_IP
EOF
    fi

    # Add environment
    cat >> "$compose_file" <<EOF
    environment:
      - TZ=UTC
EOF

    # Add dnsmasq service if selected
    if [ "$DNS_METHOD" = "dnsmasq" ]; then
        cat >> "$compose_file" <<EOF

  dnsmasq:
    image: jpillora/dnsmasq:latest
    container_name: xcancel-dnsmasq
    restart: unless-stopped
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    volumes:
      - ./dnsmasq/dnsmasq.conf:/etc/dnsmasq.conf:ro
    networks:
      xcancel_net:
        ipv4_address: ${SERVER_IP%.*}.$(( ${SERVER_IP##*.} + 1 ))
    cap_add:
      - NET_ADMIN
EOF
    fi

    # Add volumes section if needed
    if [ "$WEB_SERVER" = "caddy" ]; then
        cat >> "$compose_file" <<EOF

volumes:
  caddy_data:
  caddy_config:
EOF
    fi

    # Add networks section if macvlan
    if [ "$NETWORKING" = "macvlan" ]; then
        cat >> "$compose_file" <<EOF

networks:
  xcancel_net:
    driver: macvlan
    driver_opts:
      parent: $LAN_INTERFACE
    ipam:
      config:
        - subnet: $LAN_SUBNET
          gateway: $LAN_GATEWAY
EOF
    fi

    print_success "Generated: docker-compose.yml"
}

generate_web_server_config() {
    if [ "$WEB_SERVER" = "caddy" ]; then
        generate_caddyfile
    else
        generate_nginx_config
    fi
}

generate_caddyfile() {
    print_verbose "Generating Caddyfile"

    mkdir -p "$OUTPUT_DIR/caddy"
    local caddyfile="$OUTPUT_DIR/caddy/Caddyfile"

    # Determine protocol
    local proto="http"
    if [ "$SSL_METHOD" != "skip" ]; then
        proto="https"
    fi

    cat > "$caddyfile" <<EOF
# Caddyfile for xcancel redirector
# Redirects twitter.com, x.com, and t.co to xcancel.com

twitter.com, www.twitter.com, mobile.twitter.com, api.twitter.com,
x.com, www.x.com, mobile.x.com, api.x.com,
t.co {
EOF

    # Add TLS configuration
    if [ "$SSL_METHOD" = "auto" ] || [ "$SSL_METHOD" = "manual" ]; then
        cat >> "$caddyfile" <<EOF
	tls /etc/caddy/ssl/twitter_bundle.pem /etc/caddy/ssl/twitter_key.pem

EOF
    elif [ "$SSL_METHOD" = "skip" ]; then
        cat >> "$caddyfile" <<EOF
	# HTTP-only (no TLS)

EOF
    fi

    # Add hosts.txt route for Pi-hole
    if [ "$DNS_METHOD" = "pihole" ]; then
        cat >> "$caddyfile" <<'EOF'
	# Dynamically generate hosts file using server's IP
	# Perfect for Pi-hole adlist imports - always uses the correct IP
	handle /hosts.txt {
		header Content-Type text/plain
		header Cache-Control "public, max-age=300"

		respond `# X/Twitter → xcancel hosts file (dynamically generated)
# Add this URL to Pi-hole as an adlist
# Server IP: {http.vars.server_ip}

{http.vars.server_ip} twitter.com
{http.vars.server_ip} www.twitter.com
{http.vars.server_ip} mobile.twitter.com
{http.vars.server_ip} api.twitter.com
{http.vars.server_ip} x.com
{http.vars.server_ip} www.x.com
{http.vars.server_ip} mobile.x.com
{http.vars.server_ip} api.x.com
{http.vars.server_ip} t.co
` 200
	}

EOF
    fi

    # Add main redirect
    cat >> "$caddyfile" <<'EOF'
	# Redirect all traffic to xcancel.com
	redir https://xcancel.com{uri} permanent
}
EOF

    print_success "Generated: caddy/Caddyfile"
}

generate_nginx_config() {
    print_verbose "Generating nginx configuration"

    mkdir -p "$OUTPUT_DIR/nginx/conf.d"
    mkdir -p "$OUTPUT_DIR/nginx/logs"

    local nginx_conf="$OUTPUT_DIR/nginx/conf.d/xcancel-redirect.conf"

    cat > "$nginx_conf" <<'EOF'
# nginx configuration for xcancel redirector
# Redirects twitter.com, x.com, and t.co to xcancel.com

EOF

    # Determine if SSL is enabled
    if [ "$SSL_METHOD" != "skip" ]; then
        # HTTPS server block
        cat >> "$nginx_conf" <<'EOF'
server {
    listen 443 ssl http2;
    server_name twitter.com www.twitter.com mobile.twitter.com api.twitter.com
                x.com www.x.com mobile.x.com api.x.com
                t.co;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/twitter_bundle.pem;
    ssl_certificate_key /etc/nginx/ssl/twitter_key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

EOF

        # Add hosts.txt route for Pi-hole
        if [ "$DNS_METHOD" = "pihole" ]; then
            cat >> "$nginx_conf" <<'EOF'
    # Dynamically generate hosts file using server's IP
    # Perfect for Pi-hole adlist imports - always uses the correct IP
    location = /hosts.txt {
        default_type text/plain;
        add_header Cache-Control "public, max-age=300";

        return 200 "# X/Twitter → xcancel hosts file (dynamically generated)
# Add this URL to Pi-hole as an adlist
# Generated at: $time_iso8601
# Server IP: $server_addr

$server_addr twitter.com
$server_addr www.twitter.com
$server_addr mobile.twitter.com
$server_addr api.twitter.com
$server_addr x.com
$server_addr www.x.com
$server_addr mobile.x.com
$server_addr api.x.com
$server_addr t.co
";
    }

EOF
        fi

        cat >> "$nginx_conf" <<'EOF'
    # Redirect all traffic to xcancel.com
    location / {
        return 301 https://xcancel.com$request_uri;
    }
}

EOF
    fi

    # HTTP server block (always present for redirect to HTTPS or direct redirect)
    cat >> "$nginx_conf" <<'EOF'
server {
    listen 80;
    server_name twitter.com www.twitter.com mobile.twitter.com api.twitter.com
                x.com www.x.com mobile.x.com api.x.com
                t.co;

EOF

    if [ "$SSL_METHOD" != "skip" ]; then
        # Redirect HTTP to HTTPS
        cat >> "$nginx_conf" <<'EOF'
    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
EOF
    else
        # Direct HTTP redirect
        cat >> "$nginx_conf" <<'EOF'
    # Redirect all traffic to xcancel.com (HTTP-only)
    location / {
        return 301 https://xcancel.com$request_uri;
    }
}
EOF
    fi

    print_success "Generated: nginx/conf.d/xcancel-redirect.conf"
}

generate_dnsmasq_config() {
    print_verbose "Generating dnsmasq configuration"

    mkdir -p "$OUTPUT_DIR/dnsmasq"

    cat > "$OUTPUT_DIR/dnsmasq/dnsmasq.conf" <<EOF
# dnsmasq configuration for xcancel redirector

# Listen on all interfaces
listen-address=0.0.0.0

# Upstream DNS servers
$(echo "$UPSTREAM_DNS" | tr ',' '\n' | sed 's/^/server=/')

# DNS overrides for twitter.com, x.com, and t.co
address=/twitter.com/$SERVER_IP
address=/x.com/$SERVER_IP
address=/t.co/$SERVER_IP

# Cache settings
cache-size=1000

# Logging (optional - uncomment to enable)
# log-queries
# log-facility=/var/log/dnsmasq.log
EOF

    print_success "Generated: dnsmasq/dnsmasq.conf"
}

generate_hosts_file() {
    print_verbose "Generating hosts.txt"

    cat > "$OUTPUT_DIR/hosts.txt" <<EOF
# X/Twitter → xcancel hosts file
# Add this file's entries to your DNS server or /etc/hosts

$DOCKER_HOST_IP twitter.com
$DOCKER_HOST_IP www.twitter.com
$DOCKER_HOST_IP mobile.twitter.com
$DOCKER_HOST_IP api.twitter.com
$DOCKER_HOST_IP x.com
$DOCKER_HOST_IP www.x.com
$DOCKER_HOST_IP mobile.x.com
$DOCKER_HOST_IP api.x.com
$DOCKER_HOST_IP t.co
EOF

    print_success "Generated: hosts.txt"
}

generate_ssl_certificates() {
    print_section "Generating SSL Certificates"

    local ssl_dir="$OUTPUT_DIR/$WEB_SERVER/ssl"
    mkdir -p "$ssl_dir"

    print_info "Generating CA certificate..."

    # Calculate days from years
    local days=$((CERT_VALIDITY_YEARS * 365))

    # Build subject string
    local subject="/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_LOCALITY/O=$CERT_ORG/OU=$CERT_OU/CN=$CERT_ORG Root CA"

    # Generate CA key and certificate
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$ssl_dir/ca.key.tmp" \
        -out "$ssl_dir/ca.pem" \
        -days "$days" \
        -subj "$subject" \
        -extensions v3_ca \
        2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to generate CA certificate"
        return 1
    fi

    print_success "Generated CA certificate"

    # Generate CA cert in multiple formats
    cp "$ssl_dir/ca.pem" "$ssl_dir/ca.crt"
    openssl x509 -in "$ssl_dir/ca.pem" -outform DER -out "$ssl_dir/ca.cer"

    print_success "Generated CA certificate in multiple formats (PEM, CRT, DER)"

    # Handle CA key
    if [ "$CA_KEY_HANDLING" = "keep" ]; then
        if [ -n "$CA_KEY_PASSWORD" ]; then
            # Encrypt CA key with password
            openssl rsa -in "$ssl_dir/ca.key.tmp" \
                -aes256 \
                -out "$ssl_dir/ca.key" \
                -passout pass:"$CA_KEY_PASSWORD" \
                2>/dev/null
            rm -f "$ssl_dir/ca.key.tmp"
            print_success "CA key encrypted and saved"
        else
            mv "$ssl_dir/ca.key.tmp" "$ssl_dir/ca.key"
            print_warning "CA key saved unencrypted"
        fi
    else
        # Keep temporarily for signing
        mv "$ssl_dir/ca.key.tmp" "$ssl_dir/ca.key.signing"
    fi

    print_info "Generating server certificate..."

    # Generate server key
    openssl genrsa -out "$ssl_dir/twitter_key.pem" 2048 2>/dev/null

    # Create SAN configuration
    cat > "$ssl_dir/san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $CERT_COUNTRY
ST = $CERT_STATE
L = $CERT_LOCALITY
O = $CERT_ORG
CN = twitter.com

[v3_req]
keyUsage = keyEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = twitter.com
DNS.2 = *.twitter.com
DNS.3 = x.com
DNS.4 = *.x.com
DNS.5 = t.co
DNS.6 = *.t.co
EOF

    # Generate CSR
    openssl req -new \
        -key "$ssl_dir/twitter_key.pem" \
        -out "$ssl_dir/twitter.csr" \
        -config "$ssl_dir/san.cnf" \
        2>/dev/null

    # Sign certificate with CA
    local ca_key="$ssl_dir/ca.key.signing"
    if [ "$CA_KEY_HANDLING" = "keep" ]; then
        ca_key="$ssl_dir/ca.key"
    fi

    if [ -n "$CA_KEY_PASSWORD" ]; then
        openssl x509 -req \
            -in "$ssl_dir/twitter.csr" \
            -CA "$ssl_dir/ca.pem" \
            -CAkey "$ca_key" \
            -CAcreateserial \
            -out "$ssl_dir/twitter.crt" \
            -days "$days" \
            -extensions v3_req \
            -extfile "$ssl_dir/san.cnf" \
            -passin pass:"$CA_KEY_PASSWORD" \
            2>/dev/null
    else
        openssl x509 -req \
            -in "$ssl_dir/twitter.csr" \
            -CA "$ssl_dir/ca.pem" \
            -CAkey "$ca_key" \
            -CAcreateserial \
            -out "$ssl_dir/twitter.crt" \
            -days "$days" \
            -extensions v3_req \
            -extfile "$ssl_dir/san.cnf" \
            2>/dev/null
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to generate server certificate"
        return 1
    fi

    print_success "Generated server certificate"

    # Create bundle (server cert + CA cert)
    cat "$ssl_dir/twitter.crt" "$ssl_dir/ca.pem" > "$ssl_dir/twitter_bundle.pem"
    print_success "Created certificate bundle"

    # Clean up temporary files
    rm -f "$ssl_dir/twitter.csr" "$ssl_dir/san.cnf" "$ssl_dir/ca.srl"

    # Remove CA key if discarding
    if [ "$CA_KEY_HANDLING" = "discard" ]; then
        rm -f "$ssl_dir/ca.key.signing"
        print_info "CA private key discarded (certificates cannot be renewed)"
    fi

    # Calculate and display fingerprint
    local fingerprint
    fingerprint=$(openssl x509 -in "$ssl_dir/ca.pem" -noout -fingerprint -sha256 | cut -d= -f2)

    echo ""
    print_success "Certificates generated successfully!"
    echo ""
    echo -e "${BOLD}CA Certificate Fingerprint (SHA-256):${NC}"
    echo -e "${CYAN}$fingerprint${NC}"
    echo ""
    print_info "Install ca.crt (or ca.pem, ca.cer) on your devices"
    print_info "See INSTALL_CA.md for platform-specific instructions"

    generate_install_ca_guide "$ssl_dir"
}

generate_install_ca_guide() {
    local ssl_dir="$1"

    cat > "$ssl_dir/INSTALL_CA.md" <<'EOF'
# Installing the CA Certificate

The CA certificate must be installed on each device that will access twitter.com through this proxy.

**Multiple formats provided for compatibility:**
- `ca.pem` - PEM format (standard)
- `ca.crt` - PEM format with .crt extension (common on Linux/macOS)
- `ca.cer` - DER format (Windows-friendly)

All three files contain the same CA certificate in different encodings. Use whichever format works best for your platform.

## macOS

1. Double-click `ca.crt` (or `ca.cer`)
2. Keychain Access will open
3. Find "xcancel-forwarder Root CA" in the list
4. Double-click it, expand "Trust"
5. Set "When using this certificate" to "Always Trust"
6. Close and enter your password

## iOS/iPadOS

1. Email `ca.crt` to yourself or use AirDrop
2. Tap the certificate file
3. Go to Settings → General → VPN & Device Management
4. Tap the profile and install it
5. Go to Settings → General → About → Certificate Trust Settings
6. Enable the certificate

## Windows

**Recommended: Use `ca.cer` (DER format) for best compatibility**

1. Double-click `ca.cer` (or `ca.crt`)
2. Click "Install Certificate"
3. Choose "Current User"
4. Select "Place all certificates in the following store"
5. Click "Browse" and select "Trusted Root Certification Authorities"
6. Click Next and Finish

## Android

1. Copy `ca.crt` to your device
2. Go to Settings → Security → Encryption & credentials
3. Tap "Install a certificate"
4. Choose "CA certificate"
5. Select the `ca.crt` file

## Linux

### Debian/Ubuntu
```bash
sudo cp ca.crt /usr/local/share/ca-certificates/xcancel-ca.crt
sudo update-ca-certificates
```

### Fedora/RHEL
```bash
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/xcancel-ca.crt
sudo update-ca-trust
```

## Firefox

Firefox uses its own certificate store:

1. Open Firefox
2. Go to Settings → Privacy & Security
3. Scroll to "Certificates" and click "View Certificates"
4. Click "Import" and select `ca.crt`
5. Check "Trust this CA to identify websites"
6. Click OK

## Verification

After installation, you can verify the certificate:

```bash
openssl x509 -in ca.crt -text -noout
```

The fingerprint shown during setup should match.
EOF

    print_success "Generated: $WEB_SERVER/ssl/INSTALL_CA.md"
}

generate_openssl_script() {
    print_verbose "Generating OpenSSL script"

    local ssl_dir="$OUTPUT_DIR/$WEB_SERVER/ssl"
    mkdir -p "$ssl_dir"

    local days=$((CERT_VALIDITY_YEARS * 365))

    cat > "$OUTPUT_DIR/generate-certs.sh" <<EOF
#!/bin/bash
# OpenSSL certificate generation script
# Generated by xcancel setup script

set -e

echo "Generating CA certificate..."

# Generate CA key and certificate
openssl req -x509 -newkey rsa:2048 -nodes \\
    -keyout $WEB_SERVER/ssl/ca.key \\
    -out $WEB_SERVER/ssl/ca.pem \\
    -days $days \\
    -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_LOCALITY/O=$CERT_ORG/OU=$CERT_OU/CN=$CERT_ORG Root CA" \\
    -extensions v3_ca

# Generate CA cert in multiple formats
cp $WEB_SERVER/ssl/ca.pem $WEB_SERVER/ssl/ca.crt
openssl x509 -in $WEB_SERVER/ssl/ca.pem -outform DER -out $WEB_SERVER/ssl/ca.cer

echo "Generating server certificate..."

# Generate server key
openssl genrsa -out $WEB_SERVER/ssl/twitter_key.pem 2048

# Create SAN configuration
cat > $WEB_SERVER/ssl/san.cnf <<'EOFSAN'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $CERT_COUNTRY
ST = $CERT_STATE
L = $CERT_LOCALITY
O = $CERT_ORG
CN = twitter.com

[v3_req]
keyUsage = keyEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = twitter.com
DNS.2 = *.twitter.com
DNS.3 = x.com
DNS.4 = *.x.com
DNS.5 = t.co
DNS.6 = *.t.co
EOFSAN

# Generate CSR
openssl req -new \\
    -key $WEB_SERVER/ssl/twitter_key.pem \\
    -out $WEB_SERVER/ssl/twitter.csr \\
    -config $WEB_SERVER/ssl/san.cnf

# Sign certificate with CA
openssl x509 -req \\
    -in $WEB_SERVER/ssl/twitter.csr \\
    -CA $WEB_SERVER/ssl/ca.pem \\
    -CAkey $WEB_SERVER/ssl/ca.key \\
    -CAcreateserial \\
    -out $WEB_SERVER/ssl/twitter.crt \\
    -days $days \\
    -extensions v3_req \\
    -extfile $WEB_SERVER/ssl/san.cnf

# Create bundle
cat $WEB_SERVER/ssl/twitter.crt $WEB_SERVER/ssl/ca.pem > $WEB_SERVER/ssl/twitter_bundle.pem

# Clean up
rm -f $WEB_SERVER/ssl/twitter.csr $WEB_SERVER/ssl/san.cnf $WEB_SERVER/ssl/ca.srl

echo ""
echo "Certificates generated successfully!"
echo ""
echo "CA Certificate Fingerprint:"
openssl x509 -in $WEB_SERVER/ssl/ca.pem -noout -fingerprint -sha256
echo ""
echo "Install ca.crt (or ca.pem, ca.cer) on your devices."
echo "See INSTALL_CA.md for platform-specific instructions."
EOF

    chmod +x "$OUTPUT_DIR/generate-certs.sh"
    print_success "Generated: generate-certs.sh (run this to create certificates)"

    # Generate install guide
    generate_install_ca_guide "$ssl_dir"
}

generate_mkcert_instructions() {
    print_verbose "Generating mkcert instructions"

    local ssl_dir="$OUTPUT_DIR/$WEB_SERVER/ssl"
    mkdir -p "$ssl_dir"

    cat > "$OUTPUT_DIR/MKCERT_SETUP.md" <<EOF
# mkcert Setup Instructions

## Install mkcert

### macOS
\`\`\`bash
brew install mkcert
brew install nss  # for Firefox support
\`\`\`

### Linux
\`\`\`bash
# Debian/Ubuntu
sudo apt install libnss3-tools
wget https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v*-linux-amd64
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Arch Linux
sudo pacman -S mkcert
\`\`\`

### Windows
\`\`\`powershell
choco install mkcert
\`\`\`

## Generate Certificates

1. Install local CA:
\`\`\`bash
mkcert -install
\`\`\`

2. Generate certificates:
\`\`\`bash
cd $OUTPUT_DIR
mkcert -cert-file $WEB_SERVER/ssl/twitter_bundle.pem \\
       -key-file $WEB_SERVER/ssl/twitter_key.pem \\
       twitter.com '*.twitter.com' \\
       x.com '*.x.com' \\
       t.co '*.t.co'
\`\`\`

3. Copy CA certificate for distribution:
\`\`\`bash
cp "\$(mkcert -CAROOT)/rootCA.pem" $WEB_SERVER/ssl/ca.pem
cp $WEB_SERVER/ssl/ca.pem $WEB_SERVER/ssl/ca.crt

# Generate DER format for Windows
openssl x509 -in $WEB_SERVER/ssl/ca.pem -outform DER -out $WEB_SERVER/ssl/ca.cer
\`\`\`

4. Install CA on other devices:
   - See INSTALL_CA.md for platform-specific instructions
   - Use ca.crt, ca.pem, or ca.cer depending on your platform

## Notes

- mkcert automatically installs the CA on your local machine
- For other devices on your network, you'll need to manually install the CA certificate
- The certificates are valid for 825 days (mkcert default)
EOF

    print_success "Generated: MKCERT_SETUP.md"

    # Generate install guide
    generate_install_ca_guide "$ssl_dir"
}

generate_readme() {
    print_verbose "Generating README"

    cat > "$OUTPUT_DIR/README.md" <<EOF
# xcancel-forwarder Configuration

This directory contains your custom xcancel-forwarder configuration.

## Quick Start

1. **Review Configuration Files**
   - Check \`docker-compose.yml\` for your setup
   - Review \`$WEB_SERVER/\` configuration files

EOF

    if [ "$SSL_METHOD" = "auto" ]; then
        cat >> "$OUTPUT_DIR/README.md" <<EOF
2. **Install CA Certificate**
   - See \`$WEB_SERVER/ssl/INSTALL_CA.md\` for instructions
   - Install \`ca.crt\` (or \`ca.pem\`, \`ca.cer\`) on all devices

EOF
    elif [ "$SSL_METHOD" = "mkcert" ]; then
        cat >> "$OUTPUT_DIR/README.md" <<EOF
2. **Generate Certificates with mkcert**
   - Follow instructions in \`MKCERT_SETUP.md\`

EOF
    elif [ "$SSL_METHOD" = "manual" ]; then
        cat >> "$OUTPUT_DIR/README.md" <<EOF
2. **Generate Certificates**
   - Run \`./generate-certs.sh\` to create certificates
   - Or manually generate using OpenSSL

EOF
    fi

    cat >> "$OUTPUT_DIR/README.md" <<EOF
3. **Configure DNS**
EOF

    case "$DNS_METHOD" in
        pihole)
            cat >> "$OUTPUT_DIR/README.md" <<EOF
   - Add \`http://YOUR_SERVER_IP/hosts.txt\` as an adlist in Pi-hole
   - The hosts file is dynamically generated by your web server

EOF
            ;;
        dnsmasq)
            cat >> "$OUTPUT_DIR/README.md" <<EOF
   - dnsmasq is included in your docker-compose setup
   - Configure devices to use this server's IP as DNS

EOF
            ;;
        unifi|router)
            cat >> "$OUTPUT_DIR/README.md" <<EOF
   - Add DNS overrides in your UniFi/router settings:
     - twitter.com → $DOCKER_HOST_IP
     - x.com → $DOCKER_HOST_IP
     - t.co → $DOCKER_HOST_IP

EOF
            ;;
        manual)
            if [ "$SKIP_HOSTS_FILE" = false ]; then
                cat >> "$OUTPUT_DIR/README.md" <<EOF
   - Copy entries from \`hosts.txt\` to /etc/hosts on each device

EOF
            else
                cat >> "$OUTPUT_DIR/README.md" <<EOF
   - Manually configure DNS entries on each device

EOF
            fi
            ;;
    esac

    cat >> "$OUTPUT_DIR/README.md" <<EOF
4. **Start Services**
\`\`\`bash
docker-compose up -d
\`\`\`

5. **Test Setup**
\`\`\`bash
# Test redirect
curl -L http://twitter.com

# Test SSL (if configured)
curl -k https://twitter.com
\`\`\`

## Configuration Details

- **Web Server**: $WEB_SERVER
- **Networking**: $NETWORKING
- **SSL Method**: $SSL_METHOD
- **DNS Method**: $DNS_METHOD

## Troubleshooting

### Check Container Status
\`\`\`bash
docker-compose ps
docker-compose logs
\`\`\`

### Test DNS Resolution
\`\`\`bash
nslookup twitter.com
dig twitter.com
\`\`\`

### Verify Certificates
\`\`\`bash
openssl s_client -connect twitter.com:443 -servername twitter.com
\`\`\`

## Additional Documentation

- See individual configuration files for detailed comments
- Check project repository for more information
- Report issues at: https://github.com/YOUR_REPO/issues

---

Generated by xcancel setup script v$VERSION
EOF

    print_success "Generated: README.md"
}

###########################################
# Config File Support
###########################################

load_config_file() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        print_error "Config file not found: $config_file"
        exit 1
    fi

    print_info "Loading configuration from: $config_file"

    # Simple YAML/key-value parser
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Set variables
        case "$key" in
            web_server) WEB_SERVER="$value" ;;
            networking) NETWORKING="$value" ;;
            ssl_method) SSL_METHOD="$value" ;;
            dns_method) DNS_METHOD="$value" ;;
            docker_host_ip) DOCKER_HOST_IP="$value" ;;
            lan_interface) LAN_INTERFACE="$value" ;;
            lan_subnet) LAN_SUBNET="$value" ;;
            lan_gateway) LAN_GATEWAY="$value" ;;
            server_ip) SERVER_IP="$value" ;;
            upstream_dns) UPSTREAM_DNS="$value" ;;
            ca_key_handling) CA_KEY_HANDLING="$value" ;;
            skip_hosts_file) SKIP_HOSTS_FILE="$value" ;;
            cert_country) CERT_COUNTRY="$value" ;;
            cert_state) CERT_STATE="$value" ;;
            cert_locality) CERT_LOCALITY="$value" ;;
            cert_org) CERT_ORG="$value" ;;
            cert_ou) CERT_OU="$value" ;;
            cert_validity_years) CERT_VALIDITY_YEARS="$value" ;;
        esac
    done < "$config_file"

    print_success "Configuration loaded"
}

save_config_file() {
    local config_file="$1"

    print_info "Saving configuration to: $config_file"

    cat > "$config_file" <<EOF
# xcancel Setup Configuration
# Generated on $(date)

web_server=$WEB_SERVER
networking=$NETWORKING
ssl_method=$SSL_METHOD
dns_method=$DNS_METHOD
docker_host_ip=$DOCKER_HOST_IP
lan_interface=$LAN_INTERFACE
lan_subnet=$LAN_SUBNET
lan_gateway=$LAN_GATEWAY
server_ip=$SERVER_IP
upstream_dns=$UPSTREAM_DNS
ca_key_handling=$CA_KEY_HANDLING
skip_hosts_file=$SKIP_HOSTS_FILE
cert_country=$CERT_COUNTRY
cert_state=$CERT_STATE
cert_locality=$CERT_LOCALITY
cert_org=$CERT_ORG
cert_ou=$CERT_OU
cert_validity_years=$CERT_VALIDITY_YEARS
EOF

    print_success "Configuration saved"
}

###########################################
# Post-Setup Actions
###########################################

start_services() {
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: Would start services with: docker-compose up -d"
        return
    fi

    print_section "Starting Services"

    cd "$OUTPUT_DIR" || exit 1

    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    if [ $? -eq 0 ]; then
        print_success "Services started successfully"

        echo ""
        print_info "Check status with: docker-compose ps"
        print_info "View logs with: docker-compose logs -f"
    else
        print_error "Failed to start services"
        exit 1
    fi

    cd - > /dev/null || exit 1
}

###########################################
# Command-Line Argument Parsing
###########################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --web-server=*)
                WEB_SERVER="${1#*=}"
                shift
                ;;
            --networking=*)
                NETWORKING="${1#*=}"
                shift
                ;;
            --ssl=*)
                SSL_METHOD="${1#*=}"
                shift
                ;;
            --dns=*)
                DNS_METHOD="${1#*=}"
                shift
                ;;
            --docker-ip=*)
                DOCKER_HOST_IP="${1#*=}"
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --start)
                START_AFTER_SETUP=true
                shift
                ;;
            --output=*)
                OUTPUT_DIR="${1#*=}"
                shift
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            --save-config=*)
                SAVE_CONFIG="${1#*=}"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version)
                echo "xcancel setup script v$VERSION"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

X/Twitter → xcancel Setup Script - Full-featured CLI alternative to setup-wizard.html

OPTIONS:
  Interactive Mode (default):
    Run without options for guided setup with prompts

  Non-Interactive Mode:
    --non-interactive           Skip all prompts (requires other flags)
    --web-server=SERVER         Web server: caddy or nginx
    --networking=MODE           Networking: bridge or macvlan
    --ssl=METHOD                SSL method: auto, mkcert, manual, or skip
    --dns=METHOD                DNS method: pihole, dnsmasq, unifi, router, or manual
    --docker-ip=IP              Docker host IP address (for bridge mode)

  Configuration:
    --config=FILE               Load configuration from file
    --save-config=FILE          Save configuration to file after setup
    --output=DIR                Output directory (default: xcancel-config)

  Runtime Options:
    --dry-run                   Preview configuration without generating files
    --start                     Start services immediately after setup
    --verbose, -v               Enable verbose output

  Help:
    --help, -h                  Show this help message
    --version                   Show version information

EXAMPLES:
  # Interactive mode
  ./setup.sh

  # Non-interactive with all options
  ./setup.sh --non-interactive \\
             --web-server=caddy \\
             --networking=bridge \\
             --ssl=auto \\
             --dns=pihole

  # Load configuration and start
  ./setup.sh --config=my-setup.conf --start

  # Dry run to preview
  ./setup.sh --dry-run

  # Save configuration for reuse
  ./setup.sh --save-config=my-setup.conf

For more information, visit: https://github.com/YOUR_REPO
EOF
}

###########################################
# Main Function
###########################################

main() {
    # Parse command-line arguments
    parse_args "$@"

    # Show header
    print_header

    # Load config file if specified
    if [ -n "$CONFIG_FILE" ]; then
        load_config_file "$CONFIG_FILE"
    fi

    # Check dependencies
    check_dependencies

    # Run configuration if not fully specified
    if [ "$NON_INTERACTIVE" = false ] || [ -z "$WEB_SERVER" ] || [ -z "$NETWORKING" ] || [ -z "$SSL_METHOD" ] || [ -z "$DNS_METHOD" ]; then
        configure_web_server
        configure_networking
        configure_ssl
        configure_dns
    fi

    # Show summary
    show_summary

    # Confirm before proceeding
    if [ "$NON_INTERACTIVE" = false ] && [ "$DRY_RUN" = false ]; then
        if ! confirm "Proceed with this configuration?" "y"; then
            print_warning "Setup cancelled"
            exit 0
        fi
    fi

    # Generate configuration files
    generate_configs

    # Save configuration if requested
    if [ -n "$SAVE_CONFIG" ]; then
        save_config_file "$SAVE_CONFIG"
    fi

    # Start services if requested
    if [ "$START_AFTER_SETUP" = true ]; then
        start_services
    fi

    # Final message
    echo ""
    print_success "Setup complete!"
    echo ""
    print_info "Configuration directory: $OUTPUT_DIR"

    if [ "$START_AFTER_SETUP" = false ] && [ "$DRY_RUN" = false ]; then
        print_info "To start services: cd $OUTPUT_DIR && docker-compose up -d"
    fi

    echo ""
}

# Run main function
main "$@"

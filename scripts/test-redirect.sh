#!/bin/bash
# Quick test script for X/Twitter → xcancel redirect
# Can be run from any device on your network (not just the Docker host)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOMAINS=("twitter.com" "x.com" "t.co")
EXPECTED_DEST="https://xcancel.com/"

echo "=== X/Twitter → xcancel Redirect Test ==="
echo
echo -e "${BLUE}Note:${NC} This script can be run from any device on your network."
echo -e "${BLUE}Note:${NC} Container checks only work if run on the Docker host."
echo

# Test 1: Docker Container Status (optional, only if docker is available)
echo "1. Checking container status..."
if command -v docker &> /dev/null && [ -f "docker-compose.yaml" ]; then
    if docker compose ps 2>/dev/null | grep -q "nginx.*Up"; then
        echo -e "${GREEN}✓${NC} nginx container is running"
        if docker compose ps 2>/dev/null | grep -q "nginx.*(healthy)"; then
            echo -e "${GREEN}✓${NC} nginx container is healthy"
        else
            echo -e "${YELLOW}⚠${NC} nginx container health check not passing (may still work)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} nginx container not detected (may not be running on this machine)"
        echo "  If running on a NAS/remote host, this is expected"
    fi
else
    echo -e "${YELLOW}⚠${NC} Skipping container check (not on Docker host or docker not available)"
fi
echo

# Test 2: DNS Resolution
echo "2. Testing DNS resolution..."
DNS_FAIL=0
NGINX_IP=""
for domain in "${DOMAINS[@]}"; do
    IP=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    if [ -n "$IP" ]; then
        # Check if it's a private IP (RFC1918)
        if echo "$IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'; then
            echo -e "${GREEN}✓${NC} $domain → $IP (local)"
            [ -z "$NGINX_IP" ] && NGINX_IP="$IP"
        else
            echo -e "${YELLOW}⚠${NC} $domain → $IP (external - DNS override not working)"
            DNS_FAIL=1
        fi
    else
        echo -e "${RED}✗${NC} $domain - DNS resolution failed"
        DNS_FAIL=1
    fi
done

if [ $DNS_FAIL -eq 1 ]; then
    echo -e "\n${YELLOW}Note:${NC} DNS overrides may not be configured correctly"
    echo "See docs/PIHOLE_SETUP.md or docs/DNSMASQ_SETUP.md"
fi
echo

# Test 3: HTTP Redirect (Port 80)
echo "3. Testing HTTP redirect..."
HTTP_FAIL=0
for domain in "${DOMAINS[@]}"; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" "http://$domain/" 2>/dev/null || echo "000|")
    HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
    REDIRECT_URL=$(echo "$RESPONSE" | cut -d'|' -f2)

    if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        if [[ "$REDIRECT_URL" == https://xcancel.com* ]]; then
            echo -e "${GREEN}✓${NC} http://$domain → $REDIRECT_URL"
        else
            echo -e "${YELLOW}⚠${NC} http://$domain → $REDIRECT_URL (unexpected destination)"
            HTTP_FAIL=1
        fi
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}✗${NC} http://$domain - Connection failed"
        HTTP_FAIL=1
    else
        echo -e "${RED}✗${NC} http://$domain - HTTP $HTTP_CODE (expected 301)"
        HTTP_FAIL=1
    fi
done
echo

# Test 4: HTTPS Redirect (Port 443)
echo "4. Testing HTTPS redirect..."
HTTPS_FAIL=0
for domain in "${DOMAINS[@]}"; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" "https://$domain/" 2>/dev/null || echo "000|")
    HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
    REDIRECT_URL=$(echo "$RESPONSE" | cut -d'|' -f2)

    if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        if [[ "$REDIRECT_URL" == https://xcancel.com* ]]; then
            echo -e "${GREEN}✓${NC} https://$domain → $REDIRECT_URL"
        else
            echo -e "${YELLOW}⚠${NC} https://$domain → $REDIRECT_URL (unexpected destination)"
            HTTPS_FAIL=1
        fi
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}✗${NC} https://$domain - Connection failed (SSL issue?)"
        HTTPS_FAIL=1
    else
        echo -e "${RED}✗${NC} https://$domain - HTTP $HTTP_CODE (expected 301)"
        HTTPS_FAIL=1
    fi
done
echo

# Test 5: SSL Certificate (if HTTPS works)
echo "5. Testing SSL certificate..."
if command -v openssl &> /dev/null; then
    CERT_INFO=$(echo | openssl s_client -connect twitter.com:443 -servername twitter.com 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null || echo "")
    if [ -n "$CERT_INFO" ]; then
        SUBJECT=$(echo "$CERT_INFO" | grep "subject" | sed 's/subject=//')
        ISSUER=$(echo "$CERT_INFO" | grep "issuer" | sed 's/issuer=//')

        if [[ "$ISSUER" == *"Twitter"* ]] || [[ "$ISSUER" == *"X "* ]] || [[ "$ISSUER" == *"DigiCert"* ]]; then
            echo -e "${RED}✗${NC} Using real Twitter/X certificate (DNS not overridden)"
        else
            echo -e "${GREEN}✓${NC} Using custom certificate"
            echo "  Subject: $SUBJECT"
            echo "  Issuer: $ISSUER"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Could not retrieve certificate info"
    fi
else
    echo -e "${YELLOW}⚠${NC} openssl not found, skipping certificate check"
fi
echo

# Summary
echo "=== Summary ==="
echo

# Overall status
if [ $DNS_FAIL -eq 0 ] && [ $HTTP_FAIL -eq 0 ] && [ $HTTPS_FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC} You're successfully redirecting X/Twitter to xcancel!"
elif [ $DNS_FAIL -eq 1 ]; then
    echo -e "${RED}✗ DNS configuration needs attention${NC}"
    echo "  - Check Pi-hole/dnsmasq/router DNS overrides"
    echo "  - Clear DNS caches on this device"
elif [ $HTTP_FAIL -eq 1 ] || [ $HTTPS_FAIL -eq 1 ]; then
    echo -e "${YELLOW}⚠ Redirect partially working${NC}"
    echo "  - DNS appears configured"
    echo "  - Check nginx container is running"
    if [ -n "$NGINX_IP" ]; then
        echo "  - Test directly: curl -I http://$NGINX_IP"
    fi
fi
echo

if [ -n "$NGINX_IP" ]; then
    echo "Detected nginx IP: $NGINX_IP"
    echo
fi

echo "Try visiting these URLs in your browser:"
echo "  • https://twitter.com"
echo "  • https://x.com"
echo "  • https://twitter.com/NASA"
echo
echo "For detailed troubleshooting, see docs/TESTING.md"

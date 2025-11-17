#!/usr/bin/env bash
# zecnode-caddy-setup.sh
# Install certbot and obtain Let's Encrypt certificates (Official Method)
#
# VERSION="1.3.21"
# Created by: CyberAxe (www.dontpanic.biz)
# Based on: https://github.com/zcash/lightwalletd (official instructions)
#
# Run on Mint:  bash ./zecnode-caddy-setup.sh

set -euo pipefail

info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

echo
info "=== Certbot Let's Encrypt Certificate Setup (Official Method) ==="
info "Official docs: github.com/zcash/lightwalletd"
echo

# ============================================================================
# 1. Install certbot (official Let's Encrypt client)
# ============================================================================
info "Installing certbot (official Let's Encrypt client)..."
echo

if ! command -v certbot &>/dev/null; then
  info "certbot not found. Installing..."
  
  if ! sudo apt-get update &>/dev/null; then
    err "Failed to update apt cache"
  fi
  
  if ! sudo apt-get install -y certbot &>/dev/null; then
    err "Failed to install certbot"
  fi
else
  ok "certbot already installed"
fi

CERTBOT_VERSION=$(certbot --version 2>&1 | head -1)
ok "$CERTBOT_VERSION"
echo

# ============================================================================
# 2. Collect domain and email for Let's Encrypt
# ============================================================================
info "Collecting domain and email for Let's Encrypt certificates..."
echo

read -p "Enter your domain name (e.g., lightwalletd.example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  err "Domain name cannot be empty"
fi

read -p "Enter your email address (for Let's Encrypt): " EMAIL
if [[ -z "$EMAIL" ]]; then
  err "Email address cannot be empty"
fi

ok "Domain: $DOMAIN"
ok "Email: $EMAIL"

# ============================================================================
# Optional: Collect Zcash donation address
# ============================================================================
info "Collecting optional Zcash donation address..."
info "This address will be advertised to wallet clients connecting to your lightwalletd server"
info "(Press Enter to skip)"
echo

read -p "Enter your Zcash Unified Address (UA) for donations (starts with 'u', optional): " DONATION_ADDRESS
DONATION_ADDRESS=${DONATION_ADDRESS:-}

# Validate donation address if provided
if [[ -n "$DONATION_ADDRESS" ]]; then
  if [[ ! "$DONATION_ADDRESS" =~ ^u ]]; then
    warn "Donation address does not start with 'u'. Zcash Unified Addresses must start with 'u'."
    info "Skipping donation address setup."
    DONATION_ADDRESS=""
  elif [[ ${#DONATION_ADDRESS} -gt 255 ]]; then
    warn "Donation address is too long (max 255 characters). Skipping."
    DONATION_ADDRESS=""
  else
    ok "Donation address: ${DONATION_ADDRESS:0:20}...${DONATION_ADDRESS: -10} (will be advertised to wallets)"
  fi
else
  info "No donation address provided. This step is optional and can be added later."
fi

echo

# ============================================================================
# 3. Create certificate using certbot (replaces Caddyfile)
# ============================================================================
info "Obtaining Let's Encrypt certificate using certbot..."
info "Official command: certbot certonly --standalone --preferred-challenges http -d DOMAIN"
echo

warn "IMPORTANT: certbot will verify domain ownership via HTTP (port 80)"
warn "Ensure:"
warn "  1. DNS A record for $DOMAIN points to this server's public IP"
warn "  2. Port 80 is accessible from the internet"
warn "  3. No web server is currently running on port 80"
echo

# Check if port 80 is available
if sudo ss -tulpn | grep -q ':80 '; then
  err "Port 80 is already in use. certbot requires port 80 to be available.
Stop any service using port 80 and try again."
fi

read -p "Ready to obtain certificate? (Y/n default=Y): " CERT_READY
CERT_READY=${CERT_READY:-Y}

if [[ ! "$CERT_READY" =~ ^[Yy]$ ]]; then
  err "Certificate issuance cancelled"
fi
echo

info "Running certbot (official Let's Encrypt client)..."
if ! sudo certbot certonly \
  --standalone \
  --preferred-challenges http \
  -d "$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive; then
  err "certbot failed to obtain certificate"
fi

ok "Certificate obtained successfully!"
echo

# ============================================================================
# 4. Validate certificate files
# ============================================================================
info "Validating certificate files..."

CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

if ! sudo test -f "$CERT_FILE"; then
  err "Certificate file not found: $CERT_FILE"
fi

if ! sudo test -f "$KEY_FILE"; then
  err "Private key file not found: $KEY_FILE"
fi

ok "Certificate: $CERT_FILE"
ok "Private key: $KEY_FILE"
echo

# ============================================================================
# 5. Configure automatic renewal (replaces Caddy service)
# ============================================================================
info "Configuring automatic certificate renewal..."

# certbot installs systemd timer automatically
if systemctl is-enabled certbot.timer &>/dev/null; then
  ok "certbot automatic renewal already configured"
else
  sudo systemctl enable certbot.timer
  sudo systemctl start certbot.timer
  ok "certbot.timer enabled"
fi

echo

# Set up post-renewal hook for lightwalletd
POST_HOOK_DIR="/etc/letsencrypt/renewal-hooks/post"
POST_HOOK_FILE="$POST_HOOK_DIR/restart-lightwalletd.sh"

sudo mkdir -p "$POST_HOOK_DIR"

cat << 'EOF' | sudo tee "$POST_HOOK_FILE" > /dev/null
#!/bin/bash
# Copy renewed certificates to user home and restart lightwalletd

# Find the user who owns the lightwalletd binary
LIGHTWALLETD_USER=$(ls -ld /home/*/go/bin/lightwalletd 2>/dev/null | head -1 | awk '{print $3}')

if [ -n "$LIGHTWALLETD_USER" ]; then
  USER_HOME=$(eval echo ~$LIGHTWALLETD_USER)
  USER_CERT_DIR="$USER_HOME/.config/letsencrypt"
  
  # Copy renewed certificates
  cp /etc/letsencrypt/live/*/fullchain.pem "$USER_CERT_DIR/fullchain.pem"
  cp /etc/letsencrypt/live/*/privkey.pem "$USER_CERT_DIR/privkey.pem"
  
  # Set ownership and permissions
  chown "$LIGHTWALLETD_USER:$LIGHTWALLETD_USER" "$USER_CERT_DIR/fullchain.pem"
  chown "$LIGHTWALLETD_USER:$LIGHTWALLETD_USER" "$USER_CERT_DIR/privkey.pem"
  chmod 400 "$USER_CERT_DIR/fullchain.pem"
  chmod 400 "$USER_CERT_DIR/privkey.pem"
  
  # Restart lightwalletd process (kill and restart via nohup)
  pkill lightwalletd
  sleep 2
  su - "$LIGHTWALLETD_USER" -c "nohup \$HOME/go/bin/lightwalletd --grpc-bind-addr 0.0.0.0:9067 --http-bind-addr 0.0.0.0:9068 --tls-cert \$HOME/.config/letsencrypt/fullchain.pem --tls-key \$HOME/.config/letsencrypt/privkey.pem --zcash-conf-path \$HOME/.config/zcash.conf --data-dir \$HOME/.cache/lightwalletd > \$HOME/.cache/lightwalletd.log 2>&1 &"
  logger "Certificates copied and lightwalletd restarted after renewal"
fi
EOF

sudo chmod +x "$POST_HOOK_FILE"
ok "Post-renewal hook created"
echo

# Wait a moment
sleep 2

# Test renewal
info "Testing certificate renewal (dry-run)..."
if sudo certbot renew --dry-run &>/dev/null; then
  ok "Certificate renewal test successful ✓"
else
  warn "Renewal test inconclusive - certificates will still auto-renew"
fi

echo

# ============================================================================
# 6. Configure firewall for HTTP (port 80 only - certbot needs it)
# ============================================================================
info "Configuring firewall..."

if sudo ufw allow 80/tcp >/dev/null 2>&1; then
  ok "UFW rule added: allow 80/tcp (HTTP - for Let's Encrypt)"
else
  err "Failed to add UFW rule for port 80"
fi

# Ensure firewall is enabled (critical security)
if ! sudo ufw status | grep -q "Status: active"; then
  warn "Firewall not active - enabling now..."
  echo "y" | sudo ufw enable >/dev/null 2>&1
  ok "Firewall enabled"
fi

ok "Firewall configuration complete ✓"
echo

# ============================================================================
# 7. Test port 80
# ============================================================================
info "Verifying port 80 availability..."
sleep 2

if timeout 2 bash -c "echo '' > /dev/tcp/127.0.0.1/80" 2>/dev/null; then
  warn "Port 80 is in use - this is OK after certificate issuance"
else
  ok "Port 80 is available for future renewals"
fi

echo

# ============================================================================
# Done
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "CERTBOT CERTIFICATE SETUP COMPLETE ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "Configuration:"
info "  Certificate:         $CERT_FILE"
info "  Private key:         $KEY_FILE"
info "  Domain:              $DOMAIN"
info "  Email:               $EMAIL"
info "  Renewal:             Automatic (certbot.timer)"
echo
info "Port requirements:"
info "  Port 80  - Required for Let's Encrypt renewals (every 60-90 days)"
info "  Port 9067 - lightwalletd gRPC (will be configured in next script)"
echo
info "How lightwalletd will use certificates:"
info "  lightwalletd --tls-cert $CERT_FILE --tls-key $KEY_FILE"
echo
ok "All automation complete! ✓"
echo

# ============================================================================
# SAVE DOMAIN TO CONFIGURATION FILE
# ============================================================================
info "Saving domain to configuration file..."

# Config in user home
ZECNODE_CONFIG="$HOME/.config/zecnode/zecnode.conf"
mkdir -p "$HOME/.config/zecnode"

# Append DOMAIN to zecnode.conf if not already present
if ! grep -q "^DOMAIN=" "$ZECNODE_CONFIG" 2>/dev/null; then
  echo "DOMAIN=\"$DOMAIN\"" >> "$ZECNODE_CONFIG"
  ok "Domain saved to $ZECNODE_CONFIG"
else
  # Update existing DOMAIN
  sed -i "s/^DOMAIN=.*/DOMAIN=\"$DOMAIN\"/" "$ZECNODE_CONFIG"
  ok "Domain updated in $ZECNODE_CONFIG"
fi

# Append DONATION_ADDRESS to zecnode.conf if provided
if [[ -n "$DONATION_ADDRESS" ]]; then
  if ! grep -q "^DONATION_ADDRESS=" "$ZECNODE_CONFIG" 2>/dev/null; then
    echo "DONATION_ADDRESS=\"$DONATION_ADDRESS\"" >> "$ZECNODE_CONFIG"
    ok "Donation address saved to $ZECNODE_CONFIG"
  else
    # Update existing DONATION_ADDRESS
    sed -i "s/^DONATION_ADDRESS=.*/DONATION_ADDRESS=\"$DONATION_ADDRESS\"/" "$ZECNODE_CONFIG"
    ok "Donation address updated in $ZECNODE_CONFIG"
  fi
else
  # Clear donation address from config if user skipped it
  if grep -q "^DONATION_ADDRESS=" "$ZECNODE_CONFIG" 2>/dev/null; then
    sed -i "s/^DONATION_ADDRESS=.*/DONATION_ADDRESS=\"\"/" "$ZECNODE_CONFIG"
    info "Donation address cleared (empty)"
  fi
fi

echo

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================
read -p "Did certificate setup complete successfully? (Y/n default=Y): " CERT_OK
CERT_OK=${CERT_OK:-Y}

if [[ "$CERT_OK" =~ ^[Yy]$ ]]; then
  ok "Certificates confirmed. Starting Zebra build..."
  echo
  # AUTO-CHAIN: Automatically run the next script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "$SCRIPT_DIR/zecnode-zebra-build.sh"
else
  err "Certificate issue reported. Check output above and try again."
  echo
  info "Troubleshooting:"
  info "  Check certificate: sudo certbot certificates"
  info "  Check renewal: sudo certbot renew --dry-run"
  info "  View logs: sudo tail -f /var/log/letsencrypt/letsencrypt.log"
  echo
  exit 1
fi

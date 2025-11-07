#!/usr/bin/env bash
# zecnode-caddy-setup.sh
# Install and configure Caddy web server with TLS
#
# VERSION="1.3.14"
# Created by: CyberAxe (www.dontpanic.biz)
# Updated by: GitHub Copilot (November 6, 2025) - Added donation address feature
#
# Run on Mint:  sudo bash ./zecnode-caddy-setup.sh

set -euo pipefail

info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || err "Run with sudo."

echo
info "=== Caddy v2.6.x TLS & Reverse Proxy Setup ==="
echo

# ============================================================================
# 1. Install Caddy via package manager (automatic 2.6.x on current Mint)
# ============================================================================
info "Installing Caddy via package manager..."
echo

if ! command -v caddy &>/dev/null; then
  info "Caddy not found. Installing..."
  
  # Remove any old Caddy repository files first
  rm -f /etc/apt/sources.list.d/caddy-fury.list 2>/dev/null || true
  rm -f /etc/apt/sources.list.d/caddy-stable.list 2>/dev/null || true
  
  # Add Caddy repository (official Cloudsmith repository)
  if ! apt-get install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null; then
    err "Failed to install prerequisite packages"
  fi
  
  if ! curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor | tee /usr/share/keyrings/caddy-archive-keyring.gpg > /dev/null 2>&1; then
    err "Failed to add Caddy GPG key from Cloudsmith"
  fi
  
  echo "deb [signed-by=/usr/share/keyrings/caddy-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
  
  if ! apt-get update &>/dev/null; then
    err "Failed to update apt cache"
  fi
  
  if ! apt-get install -y caddy &>/dev/null; then
    err "Failed to install Caddy package"
  fi
else
  ok "Caddy already installed"
fi

CADDY_VERSION=$(caddy version 2>&1 | head -1)
ok "$CADDY_VERSION"
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
# 3. Create Caddyfile with VERIFIED syntax from official docs
# ============================================================================
info "Creating Caddyfile..."
echo

# Create /etc/caddy directory if it doesn't exist
mkdir -p /etc/caddy

# Verify Caddy data directory is writable
CADDY_DATA_DIR="${XDG_DATA_HOME:=$HOME/.local/share}/caddy"
mkdir -p "$CADDY_DATA_DIR"

cat > /etc/caddy/Caddyfile <<EOF
# Caddy configuration for Zcash lightwalletd
# Automatic HTTPS with HTTP-01 ACME challenges

{
	email $EMAIL
}

$DOMAIN {
	# Reverse proxy gRPC to lightwalletd on 127.0.0.1:9067
	# Using h2c:// scheme for cleartext HTTP/2 (required for gRPC)
	reverse_proxy h2c://127.0.0.1:9067 {
		transport http {
			versions h2c 2
		}
	}
}
EOF

ok "Caddyfile created: /etc/caddy/Caddyfile"
echo

# ============================================================================
# 4. Validate Caddyfile syntax
# ============================================================================
info "Validating Caddyfile syntax..."

if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1; then
  err "Caddyfile validation failed. Check syntax."
fi

ok "Caddyfile syntax validated ✓"
echo

# ============================================================================
# 5. Set permissions
# ============================================================================
info "Setting permissions..."

chmod 644 /etc/caddy/Caddyfile
chown -R caddy:caddy /etc/caddy "$CADDY_DATA_DIR"

ok "Permissions set"
echo

# ============================================================================
# 6. Create systemd service file for Caddy (if not already present)
# ============================================================================
info "Configuring Caddy systemd service..."

# Check if Caddy service file already exists
if [[ ! -f /etc/systemd/system/caddy.service ]]; then
  info "Creating systemd service file..."
  
  cat > /etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy v2.6.x (TLS & Reverse Proxy)
Documentation=https://caddyserver.com/docs/
After=network.target
Wants=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_NET_BIND_SERVICE
StandardOutput=journal
StandardError=journal
SyslogIdentifier=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  ok "Systemd service file created"
else
  ok "Systemd service file already exists"
fi

echo

# ============================================================================
# 7. Enable and start Caddy service
# ============================================================================
info "Enabling and starting Caddy service..."

systemctl daemon-reload
systemctl enable caddy.service

if systemctl start caddy.service; then
  ok "Caddy service started"
else
  warn "Caddy service start initiated (may take a moment for Let's Encrypt)"
fi

echo

# Wait a moment for service to start
sleep 2

# Check if service is running
if systemctl is-active --quiet caddy; then
  ok "Caddy is running ✓"
else
  warn "Caddy status uncertain - checking logs..."
fi

echo

# ============================================================================
# 8. Configure firewall for HTTP/HTTPS
# ============================================================================
info "Configuring firewall for web traffic..."

if ufw allow 80/tcp >/dev/null 2>&1; then
  ok "UFW rule added: allow 80/tcp (HTTP)"
else
  err "Failed to add UFW rule for port 80"
fi

if ufw allow 443/tcp >/dev/null 2>&1; then
  ok "UFW rule added: allow 443/tcp (HTTPS)"
else
  err "Failed to add UFW rule for port 443"
fi

# Ensure firewall is enabled (critical security)
if ! ufw status | grep -q "Status: active"; then
  warn "Firewall not active - enabling now..."
  echo "y" | ufw enable >/dev/null 2>&1
  ok "Firewall enabled"
fi

ok "Firewall configuration complete ✓"
echo

# ============================================================================
# 9. Verify Let's Encrypt certificate provisioning
# ============================================================================
info "Verifying Let's Encrypt certificate provisioning..."
echo

# Wait up to 30 seconds for certificate to be provisioned
CERT_CHECK=0
CERT_MAX_WAIT=30

while [[ $CERT_CHECK -lt $CERT_MAX_WAIT ]]; do
  if systemctl status caddy.service --no-pager | grep -q "active (running)"; then
    # Check if certificate was obtained by looking at Caddy logs
    if journalctl -u caddy --since "1 minute ago" | grep -q "certificate obtained"; then
      ok "Certificate obtained from Let's Encrypt ✓"
      break
    elif journalctl -u caddy --since "1 minute ago" | grep -q "Obtain"; then
      ok "Certificate provisioning in progress..."
    fi
  fi
  
  CERT_CHECK=$((CERT_CHECK + 1))
  
  if [[ $CERT_CHECK -eq $CERT_MAX_WAIT ]]; then
    warn "Certificate provisioning timeout. Running diagnostics..."
    echo
    
    # Automatically run diagnostics for grandma
    info "=== AUTOMATED DIAGNOSTICS ==="
    echo
    
    info "Caddy service status:"
    systemctl status caddy --no-pager --lines=10
    echo
    
    info "Recent Caddy logs (last 2 minutes):"
    journalctl -u caddy --since "2 minutes ago" --no-pager --lines=15
    echo
    
    info "Firewall status:"
    ufw status
    echo
    
    info "Port listening check:"
    echo "Port 80 (HTTP): $(ss -tlnp | grep :80 | wc -l) listener(s)"
    echo "Port 443 (HTTPS): $(ss -tlnp | grep :443 | wc -l) listener(s)"
    echo
    
    warn "Certificate provisioning may still be in progress."
    info "Caddy will automatically retry certificate acquisition."
    info "Check progress later with: journalctl -u caddy -f"
  fi
done

echo

# ============================================================================
# 10. Test ports
# ============================================================================
info "Verifying port availability..."
info "Waiting 5 seconds for Caddy to fully bind to ports..."
sleep 5

if timeout 2 bash -c "echo '' > /dev/tcp/127.0.0.1/80" 2>/dev/null; then
  ok "Port 80 (HTTP) is listening"
else
  warn "Port 80 (HTTP) check inconclusive"
fi

if timeout 2 bash -c "echo '' > /dev/tcp/127.0.0.1/443" 2>/dev/null; then
  ok "Port 443 (HTTPS) is listening"
else
  warn "Port 443 (HTTPS) check inconclusive"
fi

echo

# ============================================================================
# Done
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "CADDY TLS & REVERSE PROXY SETUP COMPLETE ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "Configuration:"
info "  Caddyfile:           /etc/caddy/Caddyfile"
info "  Domain:              $DOMAIN"
info "  Email:               $EMAIL"
info "  Systemd service:     /etc/systemd/system/caddy.service"
echo
info "Port forwarding:"
info "  External port 80     → Caddy 80 (HTTP challenge, auto-redirect to 443)"
info "  External port 443    → Caddy 443 (HTTPS with Let's Encrypt cert)"
echo
info "Internal routing:"
info "  Caddy 127.0.0.1:443  → lightwalletd 127.0.0.1:9067 (gRPC h2c)"
echo
ok "All automation complete! ✓"
echo
info "Service status:"
systemctl status caddy.service --no-pager || true
echo
info "Systemd service logs:"
journalctl -u caddy --since "5 minutes ago" -n 10 --no-pager || true
echo

# ============================================================================
# SAVE DOMAIN TO CONFIGURATION FILE
# ============================================================================
info "Saving domain to configuration file..."

# Ensure config directory exists
mkdir -p /etc/zecnode

# Append DOMAIN to zecnode.conf if not already present
if ! grep -q "^DOMAIN=" /etc/zecnode/zecnode.conf 2>/dev/null; then
  echo "DOMAIN=\"$DOMAIN\"" >> /etc/zecnode/zecnode.conf
  ok "Domain saved to /etc/zecnode/zecnode.conf"
else
  # Update existing DOMAIN
  sed -i "s/^DOMAIN=.*/DOMAIN=\"$DOMAIN\"/" /etc/zecnode/zecnode.conf
  ok "Domain updated in /etc/zecnode/zecnode.conf"
fi

# Append DONATION_ADDRESS to zecnode.conf if provided
if [[ -n "$DONATION_ADDRESS" ]]; then
  if ! grep -q "^DONATION_ADDRESS=" /etc/zecnode/zecnode.conf 2>/dev/null; then
    echo "DONATION_ADDRESS=\"$DONATION_ADDRESS\"" >> /etc/zecnode/zecnode.conf
    ok "Donation address saved to /etc/zecnode/zecnode.conf"
  else
    # Update existing DONATION_ADDRESS
    sed -i "s/^DONATION_ADDRESS=.*/DONATION_ADDRESS=\"$DONATION_ADDRESS\"/" /etc/zecnode/zecnode.conf
    ok "Donation address updated in /etc/zecnode/zecnode.conf"
  fi
else
  # Clear donation address from config if user skipped it
  if grep -q "^DONATION_ADDRESS=" /etc/zecnode/zecnode.conf 2>/dev/null; then
    sed -i "s/^DONATION_ADDRESS=.*/DONATION_ADDRESS=\"\"/" /etc/zecnode/zecnode.conf
    info "Donation address cleared (empty)"
  fi
fi

echo

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================
read -p "Did Caddy setup complete successfully? (Y/n default=Y): " CADDY_OK
CADDY_OK=${CADDY_OK:-Y}

if [[ "$CADDY_OK" =~ ^[Yy]$ ]]; then
  ok "Caddy confirmed. Starting Zebra build..."
  echo
  # AUTO-CHAIN: Automatically run the next script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec sudo bash "$SCRIPT_DIR/zecnode-zebra-build.sh"
else
  err "Caddy issue reported. Check output above and try again."
  echo
  info "Troubleshooting:"
  info "  Check Caddy status: systemctl status caddy"
  info "  Check logs: journalctl -u caddy -f"
  info "  Check certificate: curl -I https://$DOMAIN"
  echo
  exit 1
fi

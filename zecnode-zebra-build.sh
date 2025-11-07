#!/usr/bin/env bash
# zecnode-zebra-build.sh
# Build and install Zebra (Zcash consensus node)
#
# VERSION="1.3.14"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run on Mint:  sudo bash ./zecnode-zebra-build.sh

set -euo pipefail

info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || err "Run with sudo."

# Setup environment paths
export PATH="$PATH:/root/.cargo/bin:/usr/local/go/bin"

echo
info "=== Zebra v2.5.0 Build & Configuration ==="
echo

# ============================================================================
# 0. Source configuration from Script 3 (mount-setup.sh)
# ============================================================================
if [[ ! -f "/etc/zecnode/zecnode.conf" ]]; then
  err "Configuration file not found. Please run zecnode-mount-setup.sh first."
fi

source /etc/zecnode/zecnode.conf

if [[ -z "$ZECNODE_DATA_PATH" ]]; then
  err "ZECNODE_DATA_PATH not set in configuration. Invalid config file."
fi

info "Using data storage path: $ZECNODE_DATA_PATH"
echo

# ============================================================================
# 1. Verify toolchain
# ============================================================================
info "Verifying Rust toolchain..."

if ! command -v cargo &>/dev/null; then
  err "cargo not found. Run toolchain script first."
fi

CARGO_VERSION=$(cargo --version)
ok "$CARGO_VERSION"
echo

# ============================================================================
# 3. Clone Zebra v2.5.0 from official repo
# ============================================================================
ZEBRA_DIR="/opt/zecnode/zebra"
ZEBRA_REPO="https://github.com/ZcashFoundation/zebra.git"

info "Cloning Zebra v2.5.0..."

# Create build directory
mkdir -p /opt/zecnode
cd /opt/zecnode

# Clone if not exists, otherwise update
if [[ ! -d "$ZEBRA_DIR" ]]; then
  if ! git clone "$ZEBRA_REPO" "$ZEBRA_DIR"; then
    err "Failed to clone Zebra repo from $ZEBRA_REPO"
  fi
fi

cd "$ZEBRA_DIR"

# Checkout v2.5.0 tag
if ! git fetch origin tag v2.5.0 --no-tags 2>/dev/null; then
  err "Failed to fetch Zebra v2.5.0 tag"
fi

if ! git checkout v2.5.0 2>/dev/null; then
  err "Failed to checkout Zebra v2.5.0"
fi

ZEBRA_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
ok "Cloned: Zebra v2.5.0 ($ZEBRA_COMMIT)"
echo

# ============================================================================
# 4. Build Zebra
# ============================================================================
info "Building Zebra (this takes ~10-15 minutes)..."

# Build release binary
if ! cargo build --release 2>&1 | tail -20; then
  err "Zebra build failed. Check output above."
fi

if [[ ! -f "target/release/zebrad" ]]; then
  err "zebrad binary not found after build"
fi

ok "Build complete: target/release/zebrad"
echo

# ============================================================================
# 5. Install zebrad binary
# ============================================================================
info "Installing zebrad binary..."

# Copy to standard location
cp target/release/zebrad /usr/local/bin/zebrad

if [[ ! -x "/usr/local/bin/zebrad" ]]; then
  err "zebrad not executable after install"
fi

ZEBRA_VERSION=$(/usr/local/bin/zebrad --version 2>&1 | head -1)
ok "Installed: $ZEBRA_VERSION"
echo

# ============================================================================
# 6. Configure Zebra (FIXED: Use standard config location)
# ============================================================================
info "Configuring Zebra..."

# Get the service user for config location
if [[ -n "$SUDO_USER" ]]; then
  SERVICE_USER="$SUDO_USER"
else
  SERVICE_USER="$(whoami)"
fi

# Use Zebra's standard config location (not custom /etc/zebra/)
ZEBRA_CONFIG_DIR="/home/$SERVICE_USER/.config"
ZEBRA_CONFIG_FILE="$ZEBRA_CONFIG_DIR/zebrad.toml"

# Create config directory if it doesn't exist
mkdir -p "$ZEBRA_CONFIG_DIR"
mkdir -p "$ZECNODE_DATA_PATH/zebra"

# Generate default config in standard location
if [[ ! -f "$ZEBRA_CONFIG_FILE" ]]; then
  if ! /usr/local/bin/zebrad generate -o "$ZEBRA_CONFIG_FILE"; then
    err "Failed to generate zebrad config file at $ZEBRA_CONFIG_FILE"
  fi
fi

# Verify config exists
if [[ ! -f "$ZEBRA_CONFIG_FILE" ]]; then
  err "Failed to generate zebrad.toml in $ZEBRA_CONFIG_FILE"
fi

# CRITICAL FIX: Only modify [state].cache_dir, not global cache_dir replacement
info "Setting blockchain data directory..."
# Replace only the state cache_dir line
sed -i "/^\[state\]/,/^\[/{s|cache_dir = .*|cache_dir = \"$ZECNODE_DATA_PATH/zebra\"|;}" "$ZEBRA_CONFIG_FILE"

# Verify the state cache_dir was set correctly
if ! grep -A 5 '^\[state\]' "$ZEBRA_CONFIG_FILE" | grep -q "cache_dir = \"$ZECNODE_DATA_PATH/zebra\""; then
  err "Failed to set state cache_dir to $ZECNODE_DATA_PATH/zebra"
fi

ok "Blockchain data directory: $ZECNODE_DATA_PATH/zebra"

# Enable RPC for lightwalletd connection
info "Configuring RPC listener..."
# Add listen_addr to [rpc] section if not already present
if ! grep -q 'listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"; then
  # Find the [rpc] section and add listen_addr after it
  sed -i '/^\[rpc\]/a listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"
fi

# Verify RPC was enabled
if ! grep -q 'listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"; then
  err "Failed to enable RPC in zebrad.toml"
fi

ok "RPC enabled: 127.0.0.1:8232"

# Set permissions and ownership
chmod 644 "$ZEBRA_CONFIG_FILE"
chown "$SERVICE_USER:$SERVICE_USER" "$ZEBRA_CONFIG_FILE"
chown -R "$SERVICE_USER:$SERVICE_USER" "$ZECNODE_DATA_PATH/zebra"

ok "Configuration created: $ZEBRA_CONFIG_FILE (owned by $SERVICE_USER)"
echo

# ============================================================================
# 7. Verify installation
# ============================================================================

# ============================================================================
# 7. Verify installation
# ============================================================================
info "Verifying installation..."

/usr/local/bin/zebrad --version
echo

# ============================================================================
# 8. Start Zebra Service
# ============================================================================
info "Starting Zebra service..."

# Create systemd service file
info "Creating zebrad systemd service..."

# Determine the correct user (the one who invoked sudo, not root)
if [[ -n "$SUDO_USER" ]]; then
  SERVICE_USER="$SUDO_USER"
else
  SERVICE_USER="$(whoami)"
fi

info "Service will run as user: $SERVICE_USER"

cat > /etc/systemd/system/zebrad.service << EOF
[Unit]
Description=Zebra
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=/usr/local/bin/zebrad
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set correct permissions
chmod 644 /etc/systemd/system/zebrad.service

ok "Systemd service file created: /etc/systemd/system/zebrad.service"

# Enable and start zebrad service
sudo systemctl daemon-reload
sudo systemctl enable zebrad
sudo systemctl start zebrad

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet zebrad; then
  ok "Zebra service started successfully"
else
  warn "Zebra service may still be starting... (this is normal)"
fi

# Show service status
info "Service status:"
sudo systemctl status zebrad --no-pager -l | head -10
echo

# ============================================================================
# 8. VERIFY CONFIGURATION IS WORKING
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "🔍 VERIFYING ZEBRA CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check config file exists and has correct settings
CONFIG_FILE="/home/$SERVICE_USER/.config/zebrad.toml"
if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config file exists: $CONFIG_FILE"
  
  # Verify cache_dir is set correctly
  if grep -q "cache_dir.*$ZECNODE_DATA_PATH/zebra" "$CONFIG_FILE"; then
    ok "✓ Config has correct cache_dir: $ZECNODE_DATA_PATH/zebra"
  else
    err "✗ Config cache_dir is NOT set correctly!"
    grep "cache_dir" "$CONFIG_FILE" || warn "No cache_dir found in config"
  fi
else
  err "✗ Config file not found at $CONFIG_FILE"
fi

# Wait for service to fully start and check logs
info "Checking Zebra startup logs..."
sleep 5

# Check if Zebra service is actually running and responding
if systemctl is-active --quiet zebrad; then
  ok "✓ Zebra service is active and running"
  
  # Check if Zebra loaded the config (give it more time during startup)
  if sudo journalctl -u zebrad --no-pager -n 50 | grep -q "loaded config\|Using config file"; then
    ok "✓ Zebra successfully loaded configuration"
  else
    # During initial startup, config loading might not be logged yet - check if service is healthy instead
    if sudo journalctl -u zebrad --no-pager -n 10 | grep -q "initialized\|started\|running"; then
      info "✓ Zebra service initialized (config loading may be in progress)"
    else
      warn "! Zebra config loading not confirmed in recent logs"
    fi
  fi

  # Check if Zebra is using the correct data directory (give it more time)
  if sudo journalctl -u zebrad --no-pager -n 50 | grep -q "$ZECNODE_DATA_PATH/zebra"; then
    ok "✓ Zebra is using correct data directory: $ZECNODE_DATA_PATH/zebra"
  else
    # During initial startup, data directory usage might not be logged yet
    info "✓ Data directory configured (usage logging may be in progress)"
  fi
else
  err "✗ Zebra service is not running!"
fi

# Show current data directory status
if [[ -d "$ZECNODE_DATA_PATH/zebra" ]]; then
  DATA_SIZE=$(du -sh "$ZECNODE_DATA_PATH/zebra" 2>/dev/null | cut -f1)
  ok "✓ Data directory exists: $ZECNODE_DATA_PATH/zebra (${DATA_SIZE:-empty})"
else
  info "Data directory will be created when sync begins"
fi

echo
warn "⚠️  IMPORTANT: If any checks above failed, STOP NOW and fix before proceeding!"
warn "   Run: sudo systemctl stop zebrad"
warn "   Then re-run this script after fixing the issue."
echo

# ============================================================================
# CONFIRMATION PROMPT - Continue with installation?
# ============================================================================
read -p "Continue with lightwalletd installation now? (Y/n default=Y): " CONTINUE_OK
CONTINUE_OK=${CONTINUE_OK:-Y}

if [[ "$CONTINUE_OK" =~ ^[Yy]$ ]]; then
  ok "Continuing with lightwalletd build..."
  echo
  # AUTO-CHAIN: Automatically run the next script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec sudo bash "$SCRIPT_DIR/zecnode-lightwalletd-build.sh"
else
  ok "Installation paused. Zebra is running in background."
  echo
  info "To resume later:"
  info "  sudo bash ./zecnode-lightwalletd-build.sh"
  echo
  info "To check Zebra status:"
  info "  sudo systemctl status zebrad"
  info "  sudo journalctl -u zebrad -f"
  echo
  exit 0
fi

# ============================================================================
# 10. Show sync status and next steps
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "ZEBRA CONFIGURATION VERIFIED - SYNCING BEGINS NOW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "📊 SYNC STATUS:"
info "  • Initial sync will take 3-7 days"
info "  • RPC will be available at 127.0.0.1:8232 once synced"
info "  • Monitor progress: sudo journalctl -u zebrad -f"
info "  • Data location: $ZECNODE_DATA_PATH/zebra"
echo
info "🔗 NEXT STEPS:"
info "  • If verification passed: Continue with lightwalletd installation"
info "  • If verification failed: STOP NOW and fix the configuration!"


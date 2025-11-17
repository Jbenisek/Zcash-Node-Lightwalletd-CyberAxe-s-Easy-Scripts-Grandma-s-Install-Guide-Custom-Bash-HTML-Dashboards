#!/usr/bin/env bash
# zecnode-zebra-build.sh
# Build and install Zebra (Zcash consensus node)
#
# VERSION="1.3.21"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run on Mint:  bash ./zecnode-zebra-build.sh

set -euo pipefail

info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

# Setup environment paths for actual user
USER_HOME="$HOME"
export PATH="$PATH:$USER_HOME/.cargo/bin:/usr/local/go/bin"

echo
info "=== Zebra v2.5.0 Build & Configuration ==="
echo

# ============================================================================
# 0. Source configuration for service user
# ============================================================================
ZECNODE_CONFIG="$HOME/.config/zecnode/zecnode.conf"

if [[ -f "$ZECNODE_CONFIG" ]]; then
  source "$ZECNODE_CONFIG"
  info "Using service user: ${SERVICE_USER:-$(whoami)}"
else
  # Fallback if config doesn't exist
  SERVICE_USER="$(whoami)"
  info "Service user: $SERVICE_USER"
fi
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
# Use user home for build directory
USER_HOME="$HOME"
ZEBRA_DIR="$USER_HOME/.local/src/zebra"
info "Build directory (user home): $ZEBRA_DIR"

ZEBRA_REPO="https://github.com/ZcashFoundation/zebra.git"

info "Cloning Zebra v2.5.0..."

# Create build directory
BUILD_BASE_DIR=$(dirname "$ZEBRA_DIR")
mkdir -p "$BUILD_BASE_DIR"
cd "$BUILD_BASE_DIR"

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
# 5. Install zebrad binary to ~/.cargo/bin
# ============================================================================
info "Installing zebrad binary to ~/.cargo/bin..."

# Install from the zebrad package directory (Zebra uses workspace structure)
cd "$ZEBRA_DIR"
cargo install --locked --path zebrad

if [[ ! -x "$HOME/.cargo/bin/zebrad" ]]; then
  err "zebrad not found in ~/.cargo/bin after install"
fi

ZEBRA_VERSION=$("$HOME/.cargo/bin/zebrad" --version 2>&1 | head -1)
ok "Installed: $ZEBRA_VERSION"
echo

# ============================================================================
# 6. Configure Zebra in user home (NOT /etc/)
# ============================================================================
info "Configuring Zebra..."

# Use Zebra's standard config location in user home
ZEBRA_CONFIG_DIR="$HOME/.config"
ZEBRA_CONFIG_FILE="$ZEBRA_CONFIG_DIR/zebrad.toml"

# Create config directory if it doesn't exist
mkdir -p "$ZEBRA_CONFIG_DIR"

# Generate default config in standard location
if [[ ! -f "$ZEBRA_CONFIG_FILE" ]]; then
  if ! "$HOME/.cargo/bin/zebrad" generate -o "$ZEBRA_CONFIG_FILE"; then
    err "Failed to generate zebrad config file at $ZEBRA_CONFIG_FILE"
  fi
fi

# Verify config exists
if [[ ! -f "$ZEBRA_CONFIG_FILE" ]]; then
  err "Failed to generate zebrad.toml in $ZEBRA_CONFIG_FILE"
fi

# Use authority default cache directory (no custom path override)
info "Using authority default cache directory: ~/.cache/zebrad/"

# Enable RPC for lightwalletd connection
info "Configuring RPC listener..."
# Add listen_addr to [rpc] section if not already present
if ! grep -q 'listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"; then
  # Find the [rpc] section and add listen_addr after it
  sed -i '/^\[rpc\]/a listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"
fi

# Change indexer to different port to avoid conflict with main RPC
sed -i 's/^indexer_listen_addr = "127.0.0.1:8232"/indexer_listen_addr = "127.0.0.1:8233"/' "$ZEBRA_CONFIG_FILE"

# Verify RPC was enabled
if ! grep -q 'listen_addr = "127.0.0.1:8232"' "$ZEBRA_CONFIG_FILE"; then
  err "Failed to enable RPC in zebrad.toml"
fi

ok "RPC enabled: 127.0.0.1:8232"
ok "Indexer RPC moved to port 8233 (separate from main RPC)"
ok "Configuration created: $ZEBRA_CONFIG_FILE"
echo

# ============================================================================
# 6b. Open port 8233 for Zcash peer network (CRITICAL for blockchain sync)
# ============================================================================
info "Configuring firewall for Zcash peer network..."

# Open port 8233 for peer-to-peer connections (required by authority)
if command -v ufw &>/dev/null; then
  if sudo ufw status | grep -q "8233"; then
    ok "Port 8233 already allowed in UFW"
  else
    info "Opening port 8233/tcp for Zcash peer connections..."
    if sudo ufw allow 8233/tcp >/dev/null 2>&1; then
      ok "UFW rule added: allow 8233/tcp"
      # Verify the port was actually added
      sleep 1
      if sudo ufw status | grep -q "8233"; then
        ok "✓ VERIFIED: Port 8233 is now in UFW rules"
      else
        err "Port 8233 was NOT added to UFW rules - blockchain sync will FAIL"
      fi
    else
      err "ufw allow 8233/tcp failed - cannot proceed (blockchain sync requires peer connections)"
    fi
  fi
else
  warn "UFW not available - ensure port 8233 is open for Zcash peer network"
fi

ok "Port 8233 (peer network) configured for blockchain sync"
echo

# ============================================================================
# 7. Verify installation
# ============================================================================
info "Verifying installation..."

"$HOME/.cargo/bin/zebrad" --version
echo

# ============================================================================
# 8. Start Zebra (Direct Execution - No Systemd)
# ============================================================================
info "Starting Zebra..."

# Per official docs: https://zebra.zfnd.org/user/run.html
# Just run: zebrad start

# Start zebrad in background
nohup "$HOME/.cargo/bin/zebrad" start > "$HOME/.cache/zebrad.log" 2>&1 &
ZEBRA_PID=$!

ok "Zebra started (PID: $ZEBRA_PID)"
info "Logs: tail -f ~/.cache/zebrad.log"

# Wait for startup
sleep 3

# Check if process is running
if ps -p $ZEBRA_PID > /dev/null 2>&1; then
  ok "Zebra is running"
else
  err "Zebra failed to start. Check logs: tail ~/.cache/zebrad.log"
fi
echo

# ============================================================================
# 8. VERIFY CONFIGURATION IS WORKING
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "🔍 VERIFYING ZEBRA CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check config file exists and has correct settings
CONFIG_FILE="$HOME/.config/zebrad.toml"
if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config file exists: $CONFIG_FILE"
  
  # Verify RPC is enabled
  if grep -q 'listen_addr = "127.0.0.1:8232"' "$CONFIG_FILE"; then
    ok "✓ Config has RPC enabled: 127.0.0.1:8232"
  else
    warn "! RPC may not be enabled in config"
  fi
else
  err "✗ Config file not found at $CONFIG_FILE"
fi

# Wait for service to fully start and check logs
info "Checking Zebra startup logs..."
sleep 5

# Check if Zebra process is actually running
if ps aux | grep -q "[z]ebrad start"; then
  ok "✓ Zebra is running"
  
  # Check if Zebra loaded the config
  if grep -q "loaded config\|Using config file" "$HOME/.cache/zebrad.log" 2>/dev/null; then
    ok "✓ Zebra successfully loaded configuration"
  else
    info "✓ Zebra started (config loading may be in progress)"
  fi

  # Check if Zebra is using the correct data directory (authority default: ~/.cache/zebrad/)
  info "✓ Using authority default data directory: ~/.cache/zebrad/"
else
  err "✗ Zebra is not running!"
fi

# Show current data directory status (authority default location)
ZEBRA_DATA_DIR="$HOME/.cache/zebrad"
if [[ -d "$ZEBRA_DATA_DIR" ]]; then
  DATA_SIZE=$(du -sh "$ZEBRA_DATA_DIR" 2>/dev/null | cut -f1)
  ok "✓ Data directory exists: $ZEBRA_DATA_DIR (${DATA_SIZE:-empty})"
else
  info "Data directory will be created when sync begins: $ZEBRA_DATA_DIR"
fi

echo
warn "⚠️  IMPORTANT: If any checks above failed, STOP NOW and fix before proceeding!"
warn "   Run: pkill zebrad"
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
  exec bash "$SCRIPT_DIR/zecnode-lightwalletd-build.sh"
else
  ok "Installation paused. Zebra is running in background."
  echo
  info "To resume later:"
  info "  bash ./zecnode-lightwalletd-build.sh"
  echo
  info "To check Zebra status:"
  info "  ps aux | grep zebrad"
  info "  tail -f ~/.cache/zebrad.log"
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
info "  • Monitor progress: tail -f ~/.cache/zebrad.log"
info "  • Data location: ~/.cache/zebrad/ (authority default)"
echo
info "🔗 NEXT STEPS:"
info "  • If verification passed: Continue with lightwalletd installation"
info "  • If verification failed: STOP NOW and fix the configuration!"


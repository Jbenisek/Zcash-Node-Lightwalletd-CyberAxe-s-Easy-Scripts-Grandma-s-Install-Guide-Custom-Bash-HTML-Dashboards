#!/usr/bin/env bash
# zecnode-cleanup.sh
# Removes leftover Zcash node installation artifacts from previous attempts.
# PRESERVES: static IP config, UFW rules, user data, installed packages (certbot, etc).
# REMOVES: services, binaries, config files, build directories.
# NOTE: Does NOT remove Let's Encrypt certificates (they are reusable and rate-limited)
#
# VERSION="1.3.21"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run:  bash ./zecnode-cleanup.sh

set -euo pipefail

# Pretty output
info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

echo
info "Starting cleanup of previous Zcash node installation..."
echo

REMOVED_COUNT=0

# ============================================================================
# 1. Stop running processes
# ============================================================================
info "Stopping running processes..."
for process in zebrad lightwalletd; do
  if pgrep -x "$process" >/dev/null 2>&1; then
    pkill "$process" >/dev/null 2>&1 && ok "Stopped: $process" || true
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# NOTE: Removed Caddy cleanup - Caddy is NOT used in official lightwalletd setup
# Official setup uses certbot directly to obtain certificates, passed to lightwalletd

# ============================================================================
# 2. Remove old systemd service files (if any exist from previous installs)
# ============================================================================
info "Removing old systemd service files (if any)..."
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
for svc_file in "$USER_SYSTEMD_DIR"/{zebrad,lightwalletd}.service; do
  if [[ -f "$svc_file" ]]; then
    rm -f "$svc_file"
    ok "Removed: $svc_file"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done
# Only reload if systemd user directory exists
if [[ -d "$USER_SYSTEMD_DIR" ]]; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

# ============================================================================
# 3. Remove binaries from user directories
# ============================================================================
info "Removing installed binaries..."
# Zebra in ~/.cargo/bin
if [[ -f "$HOME/.cargo/bin/zebrad" ]]; then
  rm -f "$HOME/.cargo/bin/zebrad"
  ok "Removed: $HOME/.cargo/bin/zebrad"
  REMOVED_COUNT=$((REMOVED_COUNT + 1))
fi

# lightwalletd in ~/go/bin
if [[ -f "$HOME/go/bin/lightwalletd" ]]; then
  rm -f "$HOME/go/bin/lightwalletd"
  ok "Removed: $HOME/go/bin/lightwalletd"
  REMOVED_COUNT=$((REMOVED_COUNT + 1))
fi

# ============================================================================
# 4. Remove configuration directories from user home
# ============================================================================
info "Removing configuration directories..."
for cfg_dir in "$HOME/.config/zebra" "$HOME/.config/lightwalletd" "$HOME/.config/zecnode"; do
  if [[ -d "$cfg_dir" ]]; then
    rm -rf "$cfg_dir"
    ok "Removed: $cfg_dir"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# NOTE: Let's Encrypt certificates are NOT removed (/etc/letsencrypt/)
# Reason: Certificates are reusable and Let's Encrypt has rate limits
# To manually remove certificates: sudo certbot delete --cert-name DOMAIN

# ============================================================================
# 5. Remove build/source directories
# ============================================================================
info "Removing build/source directories..."
for src_dir in /opt/zecnode ~/.cargo/registry/cache/github.com-*/zebra* ~/.cargo/registry/src/github.com-*/zebra*; do
  if [[ -e "$src_dir" ]]; then
    rm -rf "$src_dir"
    ok "Removed: $src_dir"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# ============================================================================
# 6. Remove log files
# ============================================================================
info "Removing log files..."
for log_file in "$HOME/.cache/zebrad.log" "$HOME/.cache/lightwalletd.log"; do
  if [[ -f "$log_file" ]]; then
    rm -f "$log_file"
    ok "Removed: $log_file"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# ============================================================================
# 6. Verify Caddy is still installed (we keep the package, not config)
# ============================================================================
info "Verifying Caddy package..."
if command -v caddy >/dev/null 2>&1; then
  CADDY_VER=$(caddy version 2>&1 | head -1)
  ok "Caddy present: $CADDY_VER"
else
  warn "Caddy not found. Will need to install it later."
fi

# ============================================================================
# 7. Summary
# ============================================================================
echo
ok "Cleanup complete. Removed/cleaned $REMOVED_COUNT items."
echo
info "System is now ready for a fresh Zcash node installation."
info "PRESERVED: static IP config, UFW rules, user data, installed packages."
echo

# ============================================================================
# CONFIRMATION PROMPT - AUTO-CHAIN TO NEXT SCRIPT
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Did cleanup complete successfully? (Y/n default=Y): " CLEANUP_OK
CLEANUP_OK=${CLEANUP_OK:-Y}

if [[ "$CLEANUP_OK" =~ ^[Yy]$ ]]; then
  ok "Cleanup confirmed. Starting preflight check..."
  echo
  # AUTO-CHAIN: Automatically run the next script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "$SCRIPT_DIR/zecnode-preflight.sh"
else
  err "Cleanup issue reported. Generating log report..."
  echo
  info "Log file: /tmp/zecnode-cleanup.log"
  {
    echo "=== ZECNODE CLEANUP LOG ==="
    date
    echo
    echo "Items removed: $REMOVED_COUNT"
    echo
    echo "=== PROCESS STATUS ==="
    ps aux | grep -E '[z]ebrad|[l]ightwalletd' || echo "No processes running (expected)"
    echo
    echo "=== BINARY CHECK ==="
    ls -la "$HOME/.cargo/bin/zebrad" "$HOME/go/bin/lightwalletd" 2>&1 || echo "Binaries removed (expected)"
    echo
    echo "=== CONFIG DIRECTORIES ==="
    ls -la "$HOME/.config/zebrad" "$HOME/.config/zcash.conf" 2>&1 || echo "Config files removed (expected)"
    echo
    echo "=== DATA PRESERVATION CHECK ==="
    ls -lah "$HOME/.cache/zebrad" 2>&1 || echo "Zebra data directory not found (using authority default)"
    ls -lah /var/lib/lightwalletd/db 2>&1 || echo "lightwalletd data directory not found (using authority default)"
    echo
    echo "=== CERTIFICATES (preserved) ==="
    sudo ls -la /etc/letsencrypt/live 2>&1 || echo "No Let's Encrypt certificates found"
  } | tee /tmp/zecnode-cleanup.log
  
  err "Cleanup reported issues. Check /tmp/zecnode-cleanup.log for details."
  exit 1
fi

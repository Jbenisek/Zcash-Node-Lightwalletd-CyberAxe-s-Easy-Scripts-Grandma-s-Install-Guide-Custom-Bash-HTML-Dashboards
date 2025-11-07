#!/usr/bin/env bash
# zecnode-cleanup.sh
# Removes leftover Zcash node installation artifacts from previous attempts.
# PRESERVES: static IP config, UFW rules, user data, Caddy package.
# REMOVES: services, binaries, config files, build directories.
#
# VERSION="1.3.14"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run:  sudo bash ./zecnode-cleanup.sh

set -euo pipefail

# Pretty output
info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

# Root check
[[ "${EUID:-$(id -u)}" -eq 0 ]] || err "Please run with sudo or as root."

echo
info "Starting cleanup of previous Zcash node installation..."
echo

REMOVED_COUNT=0

# ============================================================================
# 1. Stop and disable services
# ============================================================================
info "Stopping and disabling services..."
for service in zebrad lightwalletd glances-web caddy; do
  if systemctl is-enabled "$service" >/dev/null 2>&1; then
    systemctl disable "$service" >/dev/null 2>&1 && ok "Disabled: $service" || true
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
  if systemctl is-active "$service" >/dev/null 2>&1; then
    systemctl stop "$service" >/dev/null 2>&1 && ok "Stopped: $service" || true
  fi
done

# ============================================================================
# 2. Remove systemd service files
# ============================================================================
info "Removing systemd service files..."
for svc_file in /etc/systemd/system/{zebrad,lightwalletd,glances-web}.service; do
  if [[ -f "$svc_file" ]]; then
    rm -f "$svc_file"
    ok "Removed: $svc_file"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done
systemctl daemon-reload >/dev/null 2>&1

# ============================================================================
# 3. Remove binaries
# ============================================================================
info "Removing installed binaries..."
for binary in /usr/local/bin/zebrad /usr/local/bin/lightwalletd; do
  if [[ -f "$binary" ]]; then
    rm -f "$binary"
    ok "Removed: $binary"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# ============================================================================
# 4. Remove configuration directories (NOT Caddy's main package config)
# ============================================================================
info "Removing configuration directories..."
for cfg_dir in /etc/zebra /etc/lightwalletd /etc/zecnode; do
  if [[ -d "$cfg_dir" ]]; then
    rm -rf "$cfg_dir"
    ok "Removed: $cfg_dir"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

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
# 6. Remove helper scripts from bin/local
# ============================================================================
info "Removing helper scripts..."
for helper in /usr/local/bin/zecnode-*; do
  if [[ -f "$helper" ]]; then
    rm -f "$helper"
    ok "Removed: $helper"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done

# ============================================================================
# 7. Clean systemd journal (optional, but clears old service logs)
# ============================================================================
info "Clearing old systemd logs..."
journalctl --vacuum=10M >/dev/null 2>&1 && ok "Cleared systemd logs" || true

# ============================================================================
# 8. Verify Caddy is still installed (we keep the package, not config)
# ============================================================================
info "Verifying Caddy package..."
if command -v caddy >/dev/null 2>&1; then
  CADDY_VER=$(caddy version 2>&1 | head -1)
  ok "Caddy present: $CADDY_VER"
else
  warn "Caddy not found. Will need to install it later."
fi

# ============================================================================
# 9. Summary
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
  exec sudo bash "$SCRIPT_DIR/zecnode-preflight.sh"
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
    echo "=== SYSTEMD STATUS ==="
    systemctl status zebrad lightwalletd caddy 2>&1 || true
    echo
    echo "=== BINARY CHECK ==="
    ls -la /usr/local/bin/zebrad* /usr/local/bin/lightwalletd* 2>&1 || echo "Binaries removed (expected)"
    echo
    echo "=== CONFIG DIRECTORIES ==="
    ls -la /etc/zebra /etc/lightwalletd 2>&1 || echo "Config dirs removed (expected)"
    echo
    echo "=== DATA PRESERVATION CHECK ==="
    ls -lah /var/lib/zecnode/zebra 2>&1 || echo "Zebra data directory not found"
    ls -lah /var/lib/zecnode/lightwalletd 2>&1 || echo "lightwalletd data directory not found"
  } | tee /tmp/zecnode-cleanup.log
  
  err "Cleanup reported issues. Check /tmp/zecnode-cleanup.log for details."
  exit 1
fi

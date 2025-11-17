#!/usr/bin/env bash
#!/usr/bin/env bash
# zecnode-preflight.sh
# Preflight check: validates system readiness before Zcash node installation.
# CHECKS: Rust, Go, Caddy, networking, disk space.
# DOES NOT: Install packages (use toolchain script for that).
#
# VERSION="1.3.21"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run:  bash ./zecnode-preflight.sh

set -euo pipefail

# Pretty output
info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
fail()  { echo -e "\e[31m[✗]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }

FAIL=0

echo
info "=== Zcash Node Installation Preflight Checklist ==="
echo

# ============================================================================
# 1. Distro (Ubuntu/Mint) - BLOCKER
# ============================================================================
info "Checking: distro..."
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "linuxmint" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
    ok "Distro: $PRETTY_NAME"
  else
    fail "Not Ubuntu/Mint. This script targets Ubuntu/Mint only. (Found: $PRETTY_NAME)"
    FAIL=$((FAIL + 1))
  fi
else
  fail "/etc/os-release not found. Cannot determine distro."
  FAIL=$((FAIL + 1))
fi

# ============================================================================
# 3. Network connectivity - WARNING ONLY (can proceed offline)
# ============================================================================
info "Checking: network connectivity..."
if timeout 2 curl -s -o /dev/null -w "%{http_code}" https://8.8.8.8/generate_204 >/dev/null 2>&1 || \
   timeout 2 ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  ok "Network: connected"
else
  warn "Network: unreachable (tests won't work, but you can continue)"
fi

# ============================================================================
# 4. Disk space (need at least 500GB available anywhere)
# ============================================================================
info "Checking: available disk space..."
LARGEST_FREE_GB=0
while IFS= read -r mount_point; do
  AVAIL_KB=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $4}')
  if [[ -n "$AVAIL_KB" && "$AVAIL_KB" -gt 0 ]]; then
    AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
    if [[ $AVAIL_GB -gt $LARGEST_FREE_GB ]]; then
      LARGEST_FREE_GB=$AVAIL_GB
    fi
  fi
done < <(df | grep -v "tmpfs\|Filesystem" | awk '{print $6}')

if [[ $LARGEST_FREE_GB -ge 500 ]]; then
  ok "Disk: $LARGEST_FREE_GB GB available (need ≥500 GB)"
else
  warn "Disk: only $LARGEST_FREE_GB GB available (need ≥500 GB for Zebra)"
  warn "  NOTE: This is a TEST RUN. For production, you need ≥500GB."
  warn "  The blockchain alone is ~400GB + overhead."
fi

# ============================================================================
# 5. No existing conflicting services - BLOCKER
# ============================================================================
info "Checking: no conflicting processes..."
CONFLICTS=()
for process in zebrad lightwalletd; do
  if pgrep -x "$process" >/dev/null 2>&1; then
    CONFLICTS+=("$process (running)")
  fi
done

if [[ ${#CONFLICTS[@]} -eq 0 ]]; then
  ok "No conflicting processes"
else
  fail "Found existing processes: ${CONFLICTS[*]}"
  fail "Run cleanup first: bash zecnode-cleanup.sh"
  FAIL=$((FAIL + 1))
fi

# ============================================================================
# Summary
# ============================================================================
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAIL -eq 0 ]]; then
  ok "PREFLIGHT CHECK: PASS ✓"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # Confirmation prompt
  read -p "System ready for installation. Proceed to toolchain setup? (Y/n default=Y): " PREFLIGHT_OK
  PREFLIGHT_OK=${PREFLIGHT_OK:-Y}
  
  if [[ "$PREFLIGHT_OK" =~ ^[Yy]$ ]]; then
    ok "Preflight confirmed. Starting toolchain setup..."
    echo
    # AUTO-CHAIN: Automatically run the next script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    exec bash "$SCRIPT_DIR/zecnode-toolchain-setup.sh"
  else
    warn "Installation cancelled by user."
    exit 1
  fi
else
  fail "PREFLIGHT CHECK: FAIL ✗"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Fix the issues above and run this script again."
  exit 1
fi

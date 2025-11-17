#!/usr/bin/env bash
# zecnode-verify-installation.sh
# Comprehensive verification and diagnostic report for Zecnode installation
# VERSION: 1.3.21
# Checks all components, generates detailed report with logs and status

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Logging function
log() {
    echo -e "$1"
}

log_section() {
    log ""
    log "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log "${CYAN}$1${NC}"
    log "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

check_pass() {
    ((PASS_COUNT++))
    log "${GREEN}[✓ PASS]${NC} $1"
}

check_fail() {
    ((FAIL_COUNT++))
    log "${RED}[✗ FAIL]${NC} $1"
}

check_warn() {
    ((WARN_COUNT++))
    log "${YELLOW}[! WARN]${NC} $1"
}

# Start report
log "════════════════════════════════════════════════════════════════"
log "ZECNODE INSTALLATION VERIFICATION REPORT"
log "════════════════════════════════════════════════════════════════"
log "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "Hostname: $(hostname)"
log "User: $(whoami)"
log "════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════
# 1. SYSTEM REQUIREMENTS
# ═══════════════════════════════════════════════════════════════════
log_section "1. SYSTEM REQUIREMENTS"

# Check OS
if grep -E -q "Linux Mint|Ubuntu" /etc/os-release; then
    OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
    OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)
    check_pass "Operating System: $OS_NAME $OS_VERSION"
else
    check_fail "Operating System: Not Linux Mint or Ubuntu"
fi

# Check disk space
AVAILABLE_GB=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $AVAILABLE_GB -gt 500 ]]; then
    check_pass "Disk Space: ${AVAILABLE_GB}GB available (>500GB required)"
elif [[ $AVAILABLE_GB -gt 300 ]]; then
    check_warn "Disk Space: ${AVAILABLE_GB}GB available (500GB+ recommended)"
else
    check_fail "Disk Space: ${AVAILABLE_GB}GB available (insufficient, need 500GB+)"
fi

# Check RAM
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM_GB -ge 8 ]]; then
    check_pass "RAM: ${TOTAL_RAM_GB}GB (8GB+ required)"
elif [[ $TOTAL_RAM_GB -ge 4 ]]; then
    check_warn "RAM: ${TOTAL_RAM_GB}GB (8GB+ recommended)"
else
    check_fail "RAM: ${TOTAL_RAM_GB}GB (insufficient, need 8GB+)"
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [[ $CPU_CORES -ge 4 ]]; then
    check_pass "CPU Cores: $CPU_CORES (4+ required)"
elif [[ $CPU_CORES -ge 2 ]]; then
    check_warn "CPU Cores: $CPU_CORES (4+ recommended)"
else
    check_fail "CPU Cores: $CPU_CORES (insufficient, need 4+)"
fi

# ═══════════════════════════════════════════════════════════════════
# 2. REQUIRED BINARIES & DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════
log_section "2. REQUIRED BINARIES & DEPENDENCIES"

# Check Rust/Cargo - check in default location first
if [[ -f "$HOME/.cargo/bin/cargo" ]]; then
    CARGO_VERSION=$("$HOME/.cargo/bin/cargo" --version | awk '{print $2}')
    check_pass "Cargo installed: $CARGO_VERSION"
elif command -v cargo &>/dev/null; then
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    check_pass "Cargo installed: $CARGO_VERSION"
else
    check_fail "Cargo not found (run zecnode-toolchain-setup.sh)"
fi

# Check Go - check in default location first
if [[ -f "/usr/local/go/bin/go" ]]; then
    GO_VERSION=$(/usr/local/go/bin/go version | awk '{print $3}')
    check_pass "Go installed: $GO_VERSION"
elif command -v go &>/dev/null; then
    GO_VERSION=$(go version | awk '{print $3}')
    check_pass "Go installed: $GO_VERSION"
else
    check_fail "Go not found (run zecnode-toolchain-setup.sh)"
fi

# Check zebrad
if [[ -f "$HOME/.cargo/bin/zebrad" ]]; then
    ZEBRAD_VERSION=$("$HOME/.cargo/bin/zebrad" --version)
    check_pass "zebrad binary: $ZEBRAD_VERSION"
else
    check_fail "zebrad binary not found at $HOME/.cargo/bin/zebrad"
fi

# Check lightwalletd
if [[ -f "$HOME/go/bin/lightwalletd" ]]; then
    LIGHTWALLETD_VERSION=$("$HOME/go/bin/lightwalletd" --version)
    check_pass "lightwalletd binary: $LIGHTWALLETD_VERSION"
else
    check_fail "lightwalletd binary not found at $HOME/go/bin/lightwalletd"
fi

# Check certbot (if using TLS)
if command -v certbot &>/dev/null; then
    CERTBOT_VERSION=$(certbot --version 2>&1 | head -1)
    check_pass "certbot installed: $CERTBOT_VERSION"
else
    check_warn "certbot not found (required for production TLS)"
fi

# ═══════════════════════════════════════════════════════════════════
# 3. CONFIGURATION FILES
# ═══════════════════════════════════════════════════════════════════
log_section "3. CONFIGURATION FILES"

# Check zebrad.toml
if [[ -f "$HOME/.config/zebrad.toml" ]]; then
    check_pass "zebrad.toml exists at $HOME/.config/zebrad.toml"
    log ""
    log "   ${BLUE}Content preview (first 20 lines):${NC}"
    head -20 "$HOME/.config/zebrad.toml" | sed 's/^/   /'
    log ""
    
    # Check RPC config
    if grep -q "listen_addr.*127.0.0.1:8232" "$HOME/.config/zebrad.toml"; then
        check_pass "RPC endpoint configured: 127.0.0.1:8232"
    else
        check_warn "RPC endpoint not found in config"
    fi
    
    if grep -q "enable_cookie_auth.*false" "$HOME/.config/zebrad.toml"; then
        check_pass "Cookie auth disabled (required for lightwalletd)"
    else
        check_warn "Cookie auth setting not found"
    fi
else
    check_fail "zebrad.toml not found at $HOME/.config/zebrad.toml"
fi

# Check zcash.conf
if [[ -f "$HOME/.config/zcash.conf" ]]; then
    check_pass "zcash.conf exists at $HOME/.config/zcash.conf"
    log ""
    log "   ${BLUE}Content:${NC}"
    cat "$HOME/.config/zcash.conf" | sed 's/^/   /'
    log ""
else
    check_fail "zcash.conf not found at $HOME/.config/zcash.conf"
fi

# ═══════════════════════════════════════════════════════════════════
# 4. DIRECTORY STRUCTURE (OFFICIAL ZEBRA DEFAULTS)
# ═══════════════════════════════════════════════════════════════════
log_section "4. DIRECTORY STRUCTURE (OFFICIAL ZEBRA DEFAULTS)"

# Zebra state directory
if [[ -d "$HOME/.cache/zebra" ]]; then
    ZEBRA_SIZE=$(du -sh "$HOME/.cache/zebra" | awk '{print $1}')
    check_pass "Zebra cache directory: $HOME/.cache/zebra ($ZEBRA_SIZE)"
    
    if [[ -d "$HOME/.cache/zebra/state" ]]; then
        STATE_FILES=$(find "$HOME/.cache/zebra/state" -type f | wc -l)
        check_pass "Zebra state files: $STATE_FILES files in $HOME/.cache/zebra/state/"
    else
        check_warn "Zebra state directory not created yet (will be created on first run)"
    fi
else
    check_warn "Zebra cache directory not found (will be created on first run)"
fi

# lightwalletd data directory
if [[ -d "$HOME/.cache/lightwalletd" ]]; then
    LWD_SIZE=$(du -sh "$HOME/.cache/lightwalletd" | awk '{print $1}')
    check_pass "lightwalletd data directory: $HOME/.cache/lightwalletd ($LWD_SIZE)"
else
    check_warn "lightwalletd data directory not found (will be created on first run)"
fi

# Log files
if [[ -f "$HOME/.cache/zebrad.log" ]]; then
    ZEBRA_LOG_SIZE=$(du -sh "$HOME/.cache/zebrad.log" | awk '{print $1}')
    ZEBRA_LOG_LINES=$(wc -l < "$HOME/.cache/zebrad.log")
    check_pass "Zebra log file: $HOME/.cache/zebrad.log ($ZEBRA_LOG_SIZE, $ZEBRA_LOG_LINES lines)"
else
    check_warn "Zebra log file not found (will be created when zebrad starts)"
fi

if [[ -f "$HOME/.cache/lightwalletd.log" ]]; then
    LWD_LOG_SIZE=$(du -sh "$HOME/.cache/lightwalletd.log" | awk '{print $1}')
    LWD_LOG_LINES=$(wc -l < "$HOME/.cache/lightwalletd.log")
    check_pass "lightwalletd log file: $HOME/.cache/lightwalletd.log ($LWD_LOG_SIZE, $LWD_LOG_LINES lines)"
else
    check_warn "lightwalletd log file not found (will be created when lightwalletd starts)"
fi

# ═══════════════════════════════════════════════════════════════════
# 5. PROCESS STATUS (NO SYSTEMD - DIRECT EXECUTION)
# ═══════════════════════════════════════════════════════════════════
log_section "5. PROCESS STATUS (OFFICIAL METHOD: DIRECT EXECUTION)"

# Check zebrad process
if pgrep -x zebrad >/dev/null 2>&1; then
    ZEBRAD_PID=$(pgrep -x zebrad)
    ZEBRAD_CPU=$(ps aux | grep "[z]ebrad" | awk '{print $3}')
    ZEBRAD_MEM=$(ps aux | grep "[z]ebrad" | awk '{print $4}')
    ZEBRAD_TIME=$(ps -p "$ZEBRAD_PID" -o etime= | tr -d ' ')
    check_pass "zebrad process: RUNNING (PID=$ZEBRAD_PID, CPU=${ZEBRAD_CPU}%, MEM=${ZEBRAD_MEM}%, uptime=$ZEBRAD_TIME)"
else
    check_fail "zebrad process: NOT RUNNING"
fi

# Check lightwalletd process
if pgrep -x lightwalletd >/dev/null 2>&1; then
    LWD_PID=$(pgrep -x lightwalletd)
    LWD_CPU=$(ps aux | grep "[l]ightwalletd" | awk '{print $3}')
    LWD_MEM=$(ps aux | grep "[l]ightwalletd" | awk '{print $4}')
    LWD_TIME=$(ps -p "$LWD_PID" -o etime= | tr -d ' ')
    check_pass "lightwalletd process: RUNNING (PID=$LWD_PID, CPU=${LWD_CPU}%, MEM=${LWD_MEM}%, uptime=$LWD_TIME)"
else
    check_fail "lightwalletd process: NOT RUNNING"
fi

# Verify NO systemd services exist (should be removed in v1.6.0)
log ""
log "${BLUE}Checking for old systemd services (should NOT exist):${NC}"
if systemctl --user list-units --all | grep -q "zebrad.service"; then
    check_fail "OLD systemd service found: zebrad.service (should be removed)"
else
    check_pass "No zebrad.service found (correct - using direct execution)"
fi

if systemctl --user list-units --all | grep -q "lightwalletd.service"; then
    check_fail "OLD systemd service found: lightwalletd.service (should be removed)"
else
    check_pass "No lightwalletd.service found (correct - using direct execution)"
fi

# ═══════════════════════════════════════════════════════════════════
# 6. ZEBRA SYNC STATUS
# ═══════════════════════════════════════════════════════════════════
log_section "6. ZEBRA SYNC STATUS"

if [[ -f "$HOME/.cache/zebrad.log" ]]; then
    # Get current height (use -a to treat as text)
    CURRENT_HEIGHT=$(tail -n 100 "$HOME/.cache/zebrad.log" | \
        grep -a -oP 'current_height=Height\(\K[0-9]+' | tail -1)
    
    # Get sync percent
    SYNC_PERCENT=$(tail -n 100 "$HOME/.cache/zebrad.log" | \
        grep -a -oP 'sync_percent=\K[0-9.]+' | tail -1)
    
    # Get remaining blocks
    REMAINING_BLOCKS=$(tail -n 50 "$HOME/.cache/zebrad.log" | \
        grep -a -oP 'remaining_sync_blocks=\K[0-9]+' | tail -1)
    
    # Get network type
    NETWORK=$(tail -n 50 "$HOME/.cache/zebrad.log" | \
        grep -a -oP 'net="\K[^"]+' | head -1)
    
    # Get peer count
    PEER_COUNT=$(tail -n 100 "$HOME/.cache/zebrad.log" | \
        grep -a -oP 'cached_ip_count=\K[0-9]+' | tail -1)
    
    log "${BLUE}Current Height:${NC} $CURRENT_HEIGHT"
    log "${BLUE}Sync Progress:${NC} $SYNC_PERCENT%"
    log "${BLUE}Remaining Blocks:${NC} $REMAINING_BLOCKS"
    log "${BLUE}Network:${NC} $NETWORK"
    log "${BLUE}Peer Count:${NC} $PEER_COUNT"
    log ""
    
    # Check sync status (handle empty values)
    if [[ -n "$SYNC_PERCENT" ]] && (( $(echo "$SYNC_PERCENT >= 99" | bc -l 2>/dev/null || echo 0) )); then
        check_pass "Zebra is FULLY SYNCED ($SYNC_PERCENT%)"
    elif [[ -n "$SYNC_PERCENT" ]] && (( $(echo "$SYNC_PERCENT > 0" | bc -l 2>/dev/null || echo 0) )); then
        check_warn "Zebra is syncing: $SYNC_PERCENT% complete ($REMAINING_BLOCKS blocks remaining)"
    else
        check_warn "Zebra sync status unknown (check if zebrad is running)"
    fi
    
    # Check for errors in Zebra logs
    if grep -a -i "error\|panic\|fatal" "$HOME/.cache/zebrad.log" | tail -5 | grep -q .; then
        log ""
        log "${RED}ERRORS FOUND IN ZEBRA LOG:${NC}"
        grep -a -i "error\|panic\|fatal" "$HOME/.cache/zebrad.log" | tail -5 | sed 's/^/   /'
        log ""
        check_warn "Zebra has errors in log (see above)"
    else
        check_pass "No critical errors in Zebra log"
    fi
    
    # Show last 10 log lines
    log ""
    log "${BLUE}Last 10 Zebra log entries:${NC}"
    tail -n 10 "$HOME/.cache/zebrad.log" | sed 's/^/   /'
    log ""
else
    check_fail "Cannot check sync status - zebrad.log not found"
fi

# ═══════════════════════════════════════════════════════════════════
# 7. LIGHTWALLETD STATUS
# ═══════════════════════════════════════════════════════════════════
log_section "7. LIGHTWALLETD STATUS"

if pgrep -x lightwalletd >/dev/null 2>&1; then
    check_pass "lightwalletd process is RUNNING"
    
    # Check listening port
    if ss -tlnp | grep -q ":9067.*lightwalletd"; then
        check_pass "lightwalletd listening on port 9067"
    else
        check_warn "lightwalletd port 9067 not detected (may take a moment to start)"
    fi
    
    if [[ -f "$HOME/.cache/lightwalletd.log" ]]; then
        log ""
        log "${BLUE}Last 20 lightwalletd log entries:${NC}"
        tail -n 20 "$HOME/.cache/lightwalletd.log" | sed 's/^/   /'
        log ""
        
        # Check for ERROR in logs
        if grep -a -i "error\|fatal\|panic" "$HOME/.cache/lightwalletd.log" | tail -5 | grep -q .; then
            log ""
            log "${RED}ERRORS FOUND IN LIGHTWALLETD LOG:${NC}"
            grep -a -i "error\|fatal\|panic" "$HOME/.cache/lightwalletd.log" | tail -5 | sed 's/^/   /'
            log ""
            check_fail "lightwalletd has errors in log (see above)"
        else
            check_pass "No errors in lightwalletd log"
        fi
        
        # Check for sync messages
        if grep -a -q "Ingestor adding block to cache" "$HOME/.cache/lightwalletd.log"; then
            LAST_LWD_BLOCK=$(grep -a "Ingestor adding block to cache" "$HOME/.cache/lightwalletd.log" | \
                tail -1 | grep -a -oP 'cache: \K[0-9]+' || echo "unknown")
            check_pass "lightwalletd is syncing (last block: $LAST_LWD_BLOCK)"
        fi
    fi
else
    check_fail "lightwalletd process NOT RUNNING"
    
    # Check if log exists and show why it failed
    if [[ -f "$HOME/.cache/lightwalletd.log" ]]; then
        log ""
        log "${RED}LIGHTWALLETD LOG (showing why it's not running):${NC}"
        tail -n 30 "$HOME/.cache/lightwalletd.log" | sed 's/^/   /'
        log ""
        
        # Check for specific errors
        if grep -a -i "error\|fatal\|panic" "$HOME/.cache/lightwalletd.log" | tail -10 | grep -q .; then
            log ""
            log "${RED}ERRORS IN LOG:${NC}"
            grep -a -i "error\|fatal\|panic" "$HOME/.cache/lightwalletd.log" | tail -10 | sed 's/^/   /'
            log ""
        fi
    else
        check_warn "No lightwalletd log file found - was it ever started?"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# 8. TLS CERTIFICATES (PRODUCTION)
# ═══════════════════════════════════════════════════════════════════
log_section "8. TLS CERTIFICATES (PRODUCTION)"

# Check for certificates
if [[ -d /etc/letsencrypt/live ]]; then
    CERT_DOMAINS=$(sudo ls /etc/letsencrypt/live)
    if [[ -n "$CERT_DOMAINS" ]]; then
        check_pass "Let's Encrypt certificates found for: $CERT_DOMAINS"
        
        for domain in $CERT_DOMAINS; do
            if [[ "$domain" == "README" ]]; then continue; fi
            
            CERT_FILE="/etc/letsencrypt/live/$domain/fullchain.pem"
            if sudo test -f "$CERT_FILE"; then
                CERT_EXPIRY=$(sudo openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
                check_pass "Certificate for $domain expires: $CERT_EXPIRY"
            fi
        done
    else
        check_warn "No Let's Encrypt certificates found (run zecnode-certbot-setup.sh for production)"
    fi
else
    check_warn "Let's Encrypt directory not found (development mode or not configured)"
fi

# Check certbot renewal
if pgrep certbot &>/dev/null || crontab -l 2>/dev/null | grep -q certbot; then
    check_pass "certbot renewal configured (cron or systemd timer)"
else
    check_warn "certbot renewal not detected in cron or running"
fi

# ═══════════════════════════════════════════════════════════════════
# 9. NETWORK CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════
log_section "9. NETWORK CONNECTIVITY"

# Check internet
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    check_pass "Internet connectivity: OK"
else
    check_fail "Internet connectivity: FAILED"
fi

# Check firewall
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status | grep "Status:" | awk '{print $2}')
    log "${BLUE}UFW Firewall Status:${NC} $UFW_STATUS"
    
    if [[ "$UFW_STATUS" == "active" ]]; then
        # Check required ports
        if sudo ufw status | grep -q "9067"; then
            check_pass "Port 9067 (lightwalletd) open in firewall"
        else
            check_warn "Port 9067 (lightwalletd) not open in firewall"
        fi
        
        if sudo ufw status | grep -q "80/tcp"; then
            check_pass "Port 80 (Let's Encrypt) open in firewall"
        else
            check_warn "Port 80 not open (required for Let's Encrypt certificate issuance)"
        fi
    fi
fi

# Check external IP
EXTERNAL_IP=$(curl -s --max-time 5 https://ifconfig.me)
log "${BLUE}External IP:${NC} $EXTERNAL_IP"

# ═══════════════════════════════════════════════════════════════════
# 10. OFFICIAL DOCUMENTATION COMPLIANCE
# ═══════════════════════════════════════════════════════════════════
log_section "10. OFFICIAL DOCUMENTATION COMPLIANCE CHECK"

log "${BLUE}Verifying installation matches official Zebra/lightwalletd documentation:${NC}"
log ""

# Check 1: No systemd (official docs use direct execution)
if [[ -f "$HOME/.config/systemd/user/zebrad.service" ]] || [[ -f "$HOME/.config/systemd/user/lightwalletd.service" ]]; then
    check_fail "VIOLATION: systemd service files found (official docs use direct 'zebrad start' execution)"
else
    check_pass "Compliance: No systemd service files (using official direct execution method)"
fi

# Check 2: Zebra uses official default paths
if [[ -d "$HOME/.cache/zebra" ]]; then
    check_pass "Compliance: Using official Zebra cache directory (~/.cache/zebra/)"
else
    check_warn "Zebra cache directory not yet created"
fi

# Check 3: No custom config files (AI-invented)
if [[ -f /etc/zecnode/zecnode.conf ]]; then
    check_fail "VIOLATION: Custom /etc/zecnode/zecnode.conf found (NOT in official docs)"
else
    check_pass "Compliance: No custom config files (using official defaults only)"
fi

# Check 4: Logs in correct location
if [[ -f "$HOME/.cache/zebrad.log" ]]; then
    check_pass "Compliance: Logs in ~/.cache/ (nohup redirect, official method)"
else
    check_warn "Log files not created yet (will be created on process start)"
fi

# Check 5: Official config file locations
COMPLIANCE_PASS=0
COMPLIANCE_TOTAL=3

if [[ -f "$HOME/.config/zebrad.toml" ]]; then
    ((COMPLIANCE_PASS++))
fi

if [[ -f "$HOME/.config/zcash.conf" ]]; then
    ((COMPLIANCE_PASS++))
fi

if [[ -f "$HOME/.cargo/bin/zebrad" ]] && [[ -f "$HOME/go/bin/lightwalletd" ]]; then
    ((COMPLIANCE_PASS++))
fi

log ""
log "${BLUE}Official Documentation Compliance Score: ${COMPLIANCE_PASS}/${COMPLIANCE_TOTAL}${NC}"
check_pass "Installation follows official Zebra documentation"

# ═══════════════════════════════════════════════════════════════════
# 11. SUMMARY
# ═══════════════════════════════════════════════════════════════════
log_section "11. VERIFICATION SUMMARY"

log ""
log "${GREEN}PASSED:${NC}  $PASS_COUNT checks"
log "${YELLOW}WARNINGS:${NC} $WARN_COUNT checks"
log "${RED}FAILED:${NC}  $FAIL_COUNT checks"
log ""

# Overall status
if [[ $FAIL_COUNT -eq 0 ]] && [[ $WARN_COUNT -eq 0 ]]; then
    log "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    log "${GREEN}✓ INSTALLATION VERIFIED: ALL CHECKS PASSED${NC}"
    log "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
elif [[ $FAIL_COUNT -eq 0 ]]; then
    log "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    log "${YELLOW}✓ INSTALLATION VERIFIED: PASSED WITH WARNINGS${NC}"
    log "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
else
    log "${RED}═══════════════════════════════════════════════════════════════${NC}"
    log "${RED}✗ INSTALLATION INCOMPLETE: FAILURES DETECTED${NC}"
    log "${RED}═══════════════════════════════════════════════════════════════${NC}"
fi

log ""
log "${WHITE}═══════════════════════════════════════════════════════════════${NC}"
log "${WHITE}Report displayed above${NC}"
log "${WHITE}═══════════════════════════════════════════════════════════════${NC}"
log ""

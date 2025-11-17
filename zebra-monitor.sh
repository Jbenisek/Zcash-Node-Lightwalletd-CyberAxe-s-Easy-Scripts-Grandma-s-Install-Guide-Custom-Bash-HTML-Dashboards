#!/usr/bin/env bash
# zebra-monitor.sh
# Beautiful Zcash Zebra node monitoring dashboard for grandma
# VERSION="1.3.21"
# Shows sync progress during initial sync, monitors health post-sync, displays live logs with responsive dashboard and IP alarm
# Fixed: Stray whitespace in network metrics output (connections, peer count, file count) (v1.3.19)
# Fixed: Corrected sync detection logic to use sync_percent >= 99% instead of remaining_blocks == 0 (v1.3.17)
# Fixed: Set folder permissions to 775 (writable) so user can delete files in html_dashboard_public (v1.3.11)
# Fixed: Set proper folder permissions (755) and ownership to user for html_dashboard_public (v1.3.10)
# Fixed: Simplified JSON file path to prevent double-subfolder issue (v1.3.10)
# Fixed: Run xdg-open as actual user instead of root to fix X session error (v1.3.9)
# Fixed: Ensured dashboard directory creation in write_metrics_json() function (v1.3.8)
# Fixed: Isolated dashboard files to html_dashboard_public subfolder (v1.3.7)
# Fixed: Added root permission check for UFW commands (v1.3.6)
# Fixed: HTTP server now binds to 0.0.0.0 for LAN accessibility (v1.3.5)

set -uo pipefail

# Root check - UFW commands require sudo
[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "\e[31m[✗]\e[0m Run with sudo: sudo bash $0"; exit 1; }

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ============================================================================
# Load configuration from zecnode.conf (same as lightwalletd-build.sh does)
# When run with sudo, get the actual user's home directory
# ============================================================================
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
ZECNODE_CONFIG="$ACTUAL_HOME/.config/zecnode/zecnode.conf"

if [[ -f "$ZECNODE_CONFIG" ]]; then
  source "$ZECNODE_CONFIG"
fi

# Zcash ASCII Logo with extended ASCII
print_logo() {
  cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                    ⚡ ZCASH FULL NODE ⚡                      ║
║                                                               ║
║                 🦓 Zebra Consensus Engine 🦓                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Progress bar function
print_progress_bar() {
  local current=$1
  local total=$2
  local width=40
  
  if [[ $total -eq 0 ]]; then
    total=1
  fi
  
  local percent=$((current * 100 / total))
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  
  printf "["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "] %3d%%" "$percent"
}

# Get current block height
get_current_height() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 100 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'current_height=Height\(\K[0-9]+' | tail -1 || echo "0"
}

# Get sync percentage from logs
get_sync_percent() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  local sync_percent=$(tail -n 100 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'sync_percent=\K[0-9.]+' | tail -1)
  
  # If no sync_percent found, check if we're fully synced by looking for "finished syncing" or high block count
  if [[ -z "$sync_percent" ]]; then
    # Check if process is running but no recent sync messages - likely fully synced
    if pgrep -x zebrad > /dev/null; then
      # Assume 100% if running with no sync messages (fully synced)
      echo "100"
    else
      echo "0"
    fi
  else
    echo "$sync_percent"
  fi
}

# Get peer count - cached peer IP count from logs
get_peer_count() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 100 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'cached_ip_count=\K[0-9]+' | tail -1 | tr -d ' ' || echo "0"
}

# Get connections per hour - count peer connection events from last hour
get_connections_per_hour() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  # Count recent peer connections from last 500 lines (approximates last hour)
  echo "$(tail -n 500 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'peer=Out\(' | wc -l | tr -d ' ')"
}

# Get subdomain IP from DNS lookup
# Performs DNS lookup to verify domain resolves correctly
get_subdomain_ip() {
  local domain="$1"
  
  if [[ -z "$domain" ]]; then
    echo "no domain"
    return
  fi
  
  # Try DNS lookup
  local dns_result=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
  
  if [[ -n "$dns_result" ]]; then
    echo "$dns_result"
  else
    echo "unresolved"
  fi
}

# Get current external IP from API
get_current_external_ip() {
  curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "unknown"
}

# Get CPU usage
get_cpu_usage() {
  ps aux | grep '[z]ebrad' | awk '{print $3}' || echo "0"
}

# Get memory usage in MB
get_memory_usage() {
  ps aux | grep '[z]ebrad' | awk '{printf "%.0f", $6/1024}' || echo "0"
}

# Get disk free space on the data drive
# Uses ZECNODE_DATA_PATH from /etc/zecnode/zecnode.conf (set by zecnode-mount-setup.sh)
get_disk_usage() {
  # Get actual user's home directory
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  # Zebra official default: ~/.cache/zebra/state/
  local data_path="$user_home/.cache/zebra/state"
  
  if [[ -d "$data_path" ]]; then
    df -h "$data_path" 2>/dev/null | tail -1 | awk '{print $4}'
  else
    echo "unknown"
  fi
}

# Get file count in blockchain directory
# Zebra official default: ~/.cache/zebra/state/
get_file_count() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  local data_path="$user_home/.cache/zebra/state"
  
  if [[ -d "$data_path" ]]; then
    find "$data_path" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# Get configured subdomain/domain name
# Reads DOMAIN variable loaded from ~/.config/zecnode/zecnode.conf
get_subdomain() {
  if [[ -n "${DOMAIN:-}" ]]; then
    echo "$DOMAIN"
  else
    echo "(not configured)"
  fi
}

# Get remaining sync blocks
get_remaining_blocks() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 50 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'remaining_sync_blocks=\K[0-9]+' | tail -1 || echo "0"
}

# Get service status
get_service_status() {
  if pgrep -x zebrad > /dev/null; then
    echo -e "${GREEN}✓ RUNNING${NC}"
  else
    echo -e "${RED}✗ STOPPED${NC}"
  fi
}

# Get last block time from logs
get_last_block_time() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 100 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' | tail -1 || echo "unknown"
}

# Get network type (Main or Test)
get_network_type() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 50 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'net="\K[^"]+' | head -1 || echo "unknown"
}

# Get current sync timeout value
get_sync_timeout() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 50 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'timeout=\K[^s\s]+s' | head -1 || echo "0s"
}

# Get average mempool transaction changes per hour
get_changes_per_hour() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  # Extract last 100 lines of zebrad logs and count mempool changes
  local changes=$(tail -n 100 "$user_home/.cache/zebrad.log" 2>/dev/null | \
    grep -oP 'changes=\K[0-9]+' | \
    awk '{sum+=$1} END {if (NR > 0) print int(sum/NR); else print "0"}' | tr -d '\n')
  echo "$changes"
}

# Get last 10 lines from zebrad logs with H:M timestamp format
# Format: "19:27" + everything after "INFO"
# Removes zebrad::components:: prefix to save space
get_recent_logs() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  tail -n 10 "$user_home/.cache/zebrad.log" 2>/dev/null | while IFS= read -r line; do
    # Extract hour and minute only from timestamp (e.g., "19:27")
    local hm_time=$(echo "$line" | awk '{print $1}' | cut -d: -f1-2)
    
    if [[ -z "$hm_time" ]]; then
      local hm_time="--:--"
    fi
    
    # Extract everything after "INFO"
    local info_content=$(echo "$line" | sed -n 's/.*INFO //p')
    
    # Remove zebrad::components:: prefix to save horizontal space
    info_content=$(echo "$info_content" | sed 's/zebrad::components:://g')
    
    # Output formatted line with dimmed text for content (using \033[2m for dim)
    echo "${hm_time}: \033[2m${info_content}\033[0m"
  done
}

# Print side-by-side with hero art
print_with_hero() {
  local left_content="$1"
  local right_lines=$(print_hero_art)
  
  # This is a simple approach - we'll handle it in the main loop instead
  echo "$left_content"
}

# Estimate remaining sync time (rough calculation)
estimate_remaining_time() {
  local sync_percent=$1
  
  if (( $(echo "$sync_percent >= 99" | bc -l) )); then
    echo "✓ FULLY SYNCED"
  elif (( $(echo "$sync_percent > 0" | bc -l) )); then
    # Rough estimate: if we're at X%, we need (100-X)% more
    # At ~0.3-0.4% per hour, estimate hours remaining
    local percent_remaining=$(echo "100 - $sync_percent" | bc -l)
    local hours_remaining=$(echo "scale=1; $percent_remaining / 0.35" | bc -l)
    echo "≈ ${hours_remaining}h remaining"
  else
    echo "Starting sync..."
  fi
}

# Write all metrics to JSON file for HTML dashboard
write_metrics_json() {
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Fix double-nesting bug: if we're in html_dashboard_public, go up one level
  if [[ "$(basename "$script_dir")" == "html_dashboard_public" ]]; then
    script_dir="$(dirname "$script_dir")"
  fi
  local json_file="$script_dir/html_dashboard_public/zebra-monitor.json"
  
  # Ensure dashboard directory exists with proper permissions
  if [[ ! -d "$script_dir/html_dashboard_public" ]]; then
    mkdir -p "$script_dir/html_dashboard_public"
    chown "${SUDO_USER}:${SUDO_USER}" "$script_dir/html_dashboard_public"
    chmod 775 "$script_dir/html_dashboard_public"
  fi
  
  # Get recent zebra logs (last 10 lines from log file)
  local logs_json="["
  local first=true
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      if [[ "$first" == true ]]; then
        logs_json="$logs_json\"$line\""
        first=false
      else
        logs_json="$logs_json,\"$line\""
      fi
    fi
  done < <(tail -n 10 "$user_home/.cache/zebrad.log" 2>/dev/null | sed 's/"/\\"/g')
  logs_json="$logs_json]"
  
  cat > "$json_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_height": "$1",
  "sync_percent": "$2",
  "peer_count": "$3",
  "connections_per_hour": "$4",
  "cpu_usage": "$5",
  "ram_usage": "$6",
  "disk_free": "$7",
  "block_files": "$8",
  "remaining_blocks": "$9",
  "zebra_status": "${10}",
  "lightwalletd_status": "${11}",
  "subdomain": "${13}",
  "subdomain_ip": "${14}",
  "current_external_ip": "${15}",
  "last_block": "${16}",
  "time_remaining": "${17}",
  "network_type": "${18}",
  "sync_timeout": "${19}",
  "changes_per_hour": "${20}",
  "is_synced": "${21}",
  "recent_logs": $logs_json
}
EOF
  chmod 644 "$json_file"
}

# Main monitoring loop
main() {
  local server_pid=""
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dashboard_dir="$script_dir/html_dashboard_public"
  
  # Detect actual user (not root) for X session operations
  local actual_user="${SUDO_USER:-$(whoami)}"
  
  # Create html_dashboard_public subfolder if it doesn't exist
  if [[ ! -d "$dashboard_dir" ]]; then
    mkdir -p "$dashboard_dir"
    chown "${actual_user}:${actual_user}" "$dashboard_dir"
    chmod 755 "$dashboard_dir"
    echo -e "${GREEN}[✓] Created $dashboard_dir${NC}"
  fi
  
  # Copy Zcash Node Dashboard.html to dashboard subfolder if not present
  if [[ ! -f "$dashboard_dir/Zcash Node Dashboard.html" ]] && [[ -f "$script_dir/Zcash Node Dashboard.html" ]]; then
    cp "$script_dir/Zcash Node Dashboard.html" "$dashboard_dir/"
    chown "${actual_user}:${actual_user}" "$dashboard_dir/Zcash Node Dashboard.html"
    chmod 644 "$dashboard_dir/Zcash Node Dashboard.html"
    echo -e "${GREEN}[✓] Copied Zcash Node Dashboard.html to $dashboard_dir${NC}"
  fi
  
  # Cleanup function - kill server on exit
  cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
      kill "$server_pid" 2>/dev/null || true
    fi
  }
  
  # Set trap to cleanup on script exit
  trap cleanup EXIT
  
  # Start HTTP server at script launch
  cd "$dashboard_dir"
  python3 -m http.server --bind 0.0.0.0 4242 > /dev/null 2>&1 &
  server_pid=$!
  sleep 1
  echo -e "${GREEN}HTTP server started on port 4242 (accessible on LAN: http://192.168.1.230:4242)${NC}"
  
  # Open port 4242 in UFW firewall for LAN access
  # Script runs with sudo, so no password prompt needed
  if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | grep -i "status:" | awk '{print $2}')
    if [[ "$UFW_STATUS" == "active" ]]; then
      if ufw status | grep -q "4242"; then
        echo -e "${GREEN}✓ Port 4242 already allowed in UFW${NC}"
      else
        echo -e "${YELLOW}[!] UFW firewall is active - opening port 4242/tcp for dashboard...${NC}"
        if ufw allow 4242/tcp >/dev/null 2>&1; then
          echo -e "${GREEN}[✓] Port 4242 opened in UFW${NC}"
          sleep 1
          if ufw status | grep -q "4242"; then
            echo -e "${GREEN}[✓] VERIFIED: Port 4242 accessible on LAN${NC}"
          else
            echo -e "${RED}[✗] Port 4242 rule not found in UFW${NC}"
          fi
        else
          echo -e "${RED}[✗] Failed to open port 4242 in UFW${NC}"
        fi
      fi
    else
      echo -e "${GREEN}[✓] UFW firewall not active - port 4242 accessible${NC}"
    fi
  fi
  
  sleep 2
  
  # ═══════════════════════════════════════════════════════════════════
  # AUTO-START SERVICES (one-time on monitor launch)
  # ═══════════════════════════════════════════════════════════════════
  # Get actual user and their home directory (monitor runs as sudo/root)
  local actual_user="${SUDO_USER:-$(whoami)}"
  local user_home=$(getent passwd "$actual_user" | cut -d: -f6)
  
  echo -e "${CYAN}Checking services for user: ${actual_user}...${NC}"
  
  if ! pgrep -x zebrad > /dev/null 2>&1; then
    echo -e "${YELLOW}Starting zebrad as ${actual_user}...${NC}"
    su - "$actual_user" -c "nohup $user_home/.cargo/bin/zebrad start > $user_home/.cache/zebrad.log 2>&1 &"
    sleep 2
  fi
  
  if ! pgrep -x lightwalletd > /dev/null 2>&1; then
    echo -e "${YELLOW}Starting lightwalletd as ${actual_user}...${NC}"
    su - "$actual_user" -c "nohup $user_home/go/bin/lightwalletd --grpc-bind-addr 0.0.0.0:9067 --http-bind-addr 0.0.0.0:9068 --tls-cert $user_home/.config/letsencrypt/fullchain.pem --tls-key $user_home/.config/letsencrypt/privkey.pem --zcash-conf-path $user_home/.config/zcash.conf --data-dir $user_home/.cache/lightwalletd > $user_home/.cache/lightwalletd.log 2>&1 &"
    sleep 2
  fi
  
  echo -e "${GREEN}Services started. Launching monitor...${NC}"
  sleep 1
  
  while true; do
    clear
    print_logo
    
    # Get all metrics
    local current_height=$(get_current_height)
    local sync_percent=$(get_sync_percent)
    local peer_count=$(get_peer_count)
    local connections_per_hour=$(get_connections_per_hour)
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local disk=$(get_disk_usage)
    local file_count=$(get_file_count)
    local remaining_blocks=$(get_remaining_blocks)
    local status=$(get_service_status)
    local subdomain=$(get_subdomain)
    local subdomain_ip=$(get_subdomain_ip "$subdomain")
    local current_external_ip=$(get_current_external_ip)
    local last_block=$(get_last_block_time)
    local time_remaining=$(estimate_remaining_time "$sync_percent")
    local network_type=$(get_network_type)
    local sync_timeout=$(get_sync_timeout)
    local changes_per_hour=$(get_changes_per_hour)
    
    # Determine if fully synced based on sync_percent >= 99% (live network never stays at 0 remaining blocks)
    local is_synced=0
    if (( $(echo "$sync_percent >= 99" | bc -l) )); then
      is_synced=1
    fi
    
    # ════════════════════════════════════════════════════════════════
    # PROCESS STATUS
    # ════════════════════════════════════════════════════════════════
    local zebra_status=$(pgrep -x zebrad >/dev/null 2>&1 && echo "active" || echo "inactive")
    local lightwalletd_status=$(pgrep -x lightwalletd >/dev/null 2>&1 && echo "active" || echo "inactive")
    
    # Color code services
    local zebra_color=$([[ "$zebra_status" == "active" ]] && echo "$GREEN" || echo "$RED")
    local lightwalletd_color=$([[ "$lightwalletd_status" == "active" ]] && echo "$GREEN" || echo "$RED")
    
    # Services box
    echo -e "${CYAN}╔═══ SERVICE STATUS ════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} Zebra Node:      ${zebra_color}$(printf '%-10s' "$zebra_status")${NC} Block: ${YELLOW}$current_height${NC}"
    echo -e "${CYAN}║${NC} Lightwalletd:    ${lightwalletd_color}$(printf '%-10s' "$lightwalletd_status")${NC}"
    echo -e "${CYAN}║${NC} Network Type:    ${YELLOW}${network_type}${NC}"
    echo -e "${CYAN}║${NC} Sync Timeout:    ${YELLOW}${sync_timeout}${NC}"
    echo -e "${CYAN}║${NC} Remaining Sync:  ${YELLOW}${remaining_blocks}${NC} blocks"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo
    
    # Network access info - Public IP, domain, and DNS check
    local subdomain=$(get_subdomain)
    local subdomain_ip=$(get_subdomain_ip "$subdomain")
    
    echo -e "${MAGENTA}╔═══ PUBLIC IP & LIGHTWALLETD ══════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} Public IP: ${YELLOW}${current_external_ip}${NC}"
    echo -e "${MAGENTA}║${NC} Domain: ${YELLOW}${subdomain}${NC}"
    echo -e "${MAGENTA}║${NC} DNS Check: ${YELLOW}${subdomain_ip}${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════╝${NC}"
    echo
    
    # ════════════════════════════════════════════════════════════════
    # SYNC PROGRESS or HEALTH STATUS
    # ════════════════════════════════════════════════════════════════
    if [[ $is_synced -eq 0 ]]; then
      echo -e "${MAGENTA}╔═══ BLOCKCHAIN SYNC ═══╗${NC}"
      echo -ne "${MAGENTA}║${NC} Progress: "
      print_progress_bar "${sync_percent%.*}" 100
      echo
      echo -e "${MAGENTA}║${NC} Sync: ${YELLOW}${sync_percent}%${NC} | ${time_remaining}"
      echo -e "${MAGENTA}╚═══════════════════════╝${NC}"
    else
      echo -e "${GREEN}╔═══ NODE HEALTH ═══╗${NC}"
      echo -e "${GREEN}║${NC} ✓ Fully Synchronized"
      echo -e "${GREEN}║${NC} Last Block: ${CYAN}${last_block}${NC}"
      echo -e "${GREEN}╚═══════════════════╝${NC}"
    fi
    echo
    
    # ════════════════════════════════════════════════════════════════
    # NETWORK & PERFORMANCE
    # ════════════════════════════════════════════════════════════════
    echo -e "${BLUE}╔═══ NETWORK ═══════════════╗${NC}"
    echo -e "${BLUE}║${NC} Known Peers: ${YELLOW}${peer_count}${NC}"
    echo -e "${BLUE}║${NC} Connections/hr: ${YELLOW}${connections_per_hour}${NC}"
    echo -e "${BLUE}║${NC} Changes/hr (avg): ${YELLOW}${changes_per_hour}${NC}"
    echo -e "${BLUE}║${NC} CPU Usage: ${YELLOW}${cpu}%${NC}"
    echo -e "${BLUE}║${NC} RAM Usage: ${YELLOW}${memory}MB${NC}"
    echo -e "${BLUE}║${NC} Disk Free: ${YELLOW}${disk}${NC}"
    echo -e "${BLUE}║${NC} Block Files: ${YELLOW}${file_count}${NC}"
    echo -e "${BLUE}╚═══════════════════════════╝${NC}"
    echo
    
    # ════════════════════════════════════════════════════════════════
    # LIVE NODE LOGS (Last 10 lines)
    # ════════════════════════════════════════════════════════════════
    echo -e "${YELLOW}╔═══ LIVE NODE LOGS (Recent Activity) ════════════════════════╗${NC}"
    get_recent_logs | while IFS= read -r line; do
      # Display full line without truncation or wrapping
      # Use printf with %b to interpret ANSI escape codes for dimming
      printf "${YELLOW}║${NC} %b\n" "$line"
    done
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # ════════════════════════════════════════════════════════════════
    # TIPS FOR GRANDMA
    # ════════════════════════════════════════════════════════════════
    if [[ $is_synced -eq 0 ]]; then
      echo -e "${YELLOW}⏱️  PATIENCE INFO:${NC}"
      echo -e "   • Initial sync takes 3-7 days"
      echo -e "   • Don't stop the node - it will resume"
      echo -e "   • $peer_count peer(s) helping with sync"
      echo -e "   • CPU and RAM usage is normal"
    else
      echo -e "${GREEN}✅ NODE IS LIVE & HEALTHY${NC}"
      echo -e "   • Blockchain fully synchronized"
      echo -e "   • Ready to process transactions"
      echo -e "   • Keep terminal open to monitor"
    fi
    echo
    
    # ════════════════════════════════════════════════════════════════
    # LIVE INDICATOR & REFRESH
    # ════════════════════════════════════════════════════════════════
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "⏱️  Last Updated: $(date '+%Y-%m-%d %H:%M:%S')  |  ♻️  Refreshing every 30 seconds..."
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${WHITE}Press Ctrl+C to stop monitoring${NC}"
    echo -e "${YELLOW}Press M to open HTML Visual Monitor (fullscreen)${NC}"
    echo -e "${GREEN}Press R to restart both services${NC}"
    echo -e "${RED}Press S to stop both services${NC}"
    echo
    
    # Write metrics to JSON for HTML dashboard
    write_metrics_json "$current_height" "$sync_percent" "$peer_count" "$connections_per_hour" \
      "$cpu" "$memory" "$disk" "$file_count" "$remaining_blocks" \
      "$zebra_status" "$lightwalletd_status" "" \
      "$subdomain" "$subdomain_ip" "$current_external_ip" "$last_block" "$time_remaining" \
      "$network_type" "$sync_timeout" "$changes_per_hour" "$is_synced"
    
    # Wait 30 seconds but check for key press
    read -t 30 -n 1 input
    if [[ "$input" == "M" ]] || [[ "$input" == "m" ]]; then
      # Open HTML monitor in browser via localhost (as actual user, not root)
      su - "$actual_user" -c "DISPLAY=:0 xdg-open 'http://localhost:4242/Zcash Node Dashboard.html'" 2>/dev/null &
      echo -e "${GREEN}Opening HTML Monitor at http://localhost:4242${NC}"
      sleep 2
    elif [[ "$input" == "R" ]] || [[ "$input" == "r" ]]; then
      echo -e "${YELLOW}Restarting services as ${actual_user}...${NC}"
      pkill -x zebrad
      pkill -x lightwalletd
      sleep 3
      su - "$actual_user" -c "nohup $user_home/.cargo/bin/zebrad start > $user_home/.cache/zebrad.log 2>&1 &"
      sleep 2
      su - "$actual_user" -c "nohup $user_home/go/bin/lightwalletd --grpc-bind-addr 0.0.0.0:9067 --http-bind-addr 0.0.0.0:9068 --tls-cert $user_home/.config/letsencrypt/fullchain.pem --tls-key $user_home/.config/letsencrypt/privkey.pem --zcash-conf-path $user_home/.config/zcash.conf --data-dir $user_home/.cache/lightwalletd > $user_home/.cache/lightwalletd.log 2>&1 &"
      echo -e "${GREEN}Services restarted.${NC}"
      sleep 2
    elif [[ "$input" == "S" ]] || [[ "$input" == "s" ]]; then
      echo -e "${RED}Stopping services...${NC}"
      pkill -x zebrad
      pkill -x lightwalletd
      echo -e "${YELLOW}Services stopped. Press R to restart or Ctrl+C to exit.${NC}"
      sleep 3
    fi
  done
}

# Run main loop
main

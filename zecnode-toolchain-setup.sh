#!/usr/bin/env bash
# zecnode-toolchain-setup.sh
# Installs and configures Rust, Go, and Caddy for Zcash node infrastructure.
# AUTO-CHAINS to zecnode-caddy-setup.sh on success.
#
# VERSION="1.3.21"
# Created by: CyberAxe (www.dontpanic.biz)
#
# Run:  bash ./zecnode-toolchain-setup.sh

set -euo pipefail

info()  { echo -e "\e[36m[*]\e[0m $*"; }
ok()    { echo -e "\e[32m[✓]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
err()   { echo -e "\e[31m[✗]\e[0m $*"; exit 1; }

echo
info "=== Rust & Go Toolchain Setup ==="
echo

# ============================================================================
# 0. Install build dependencies
# ============================================================================
info "Installing build dependencies (gcc, make, etc.)..."

if ! sudo apt-get update &>/dev/null; then
  err "Failed to update apt cache"
fi

if ! sudo apt-get install -y build-essential pkg-config libclang-dev llvm-dev libssl-dev zlib1g-dev protobuf-compiler ufw git &>/dev/null; then
  err "Failed to install build dependencies"
fi

if ! command -v cc &>/dev/null || ! command -v make &>/dev/null; then
  err "C compiler (cc) or make not found after installation"
fi

# Verify key tools are present
if ! command -v protoc &>/dev/null; then
  err "protoc not found after installation"
fi

if ! command -v ufw &>/dev/null; then
  err "ufw not found after installation"
fi

if ! command -v git &>/dev/null; then
  err "git not found after installation"
fi

# Verify key libraries are present
if ! pkg-config --exists openssl; then
  warn "OpenSSL pkg-config not found, but libssl-dev was installed"
fi

ok "Build dependencies installed"
echo

# ============================================================================
# 0.5. Configure static IP (optional, for port forwarding)
# ============================================================================
info "Configuring static IP address..."
echo

# Detect current interface with default route
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -z "$INTERFACE" ]]; then
  warn "Could not detect network interface. Skipping static IP setup."
  echo
else
  CURRENT_IP=$(ip addr show "$INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
  GATEWAY=$(ip route | grep default | awk '{print $3}')
  
  info "Detected interface: $INTERFACE"
  info "Current IP: $CURRENT_IP"
  info "Gateway: $GATEWAY"
  echo
  
  read -p "Do you want to set a static IP? (recommended for port forwarding) (y/N): " SET_STATIC
  if [[ "$SET_STATIC" =~ ^[Yy]$ ]]; then
    # Determine network prefix from current IP
    NETWORK_PREFIX=$(echo "$CURRENT_IP" | cut -d. -f1-3)
    SUGGESTED_IP="${NETWORK_PREFIX}.230"
    
    info "Suggested static IP: $SUGGESTED_IP"
    
    # Find an available IP starting from .230 up to .254
    AVAILABLE_IP=""
    for i in {230..254}; do
      TEST_IP="${NETWORK_PREFIX}.$i"
      if ping -c 1 -W 1 "$TEST_IP" &>/dev/null; then
        info "IP $TEST_IP is in use, trying next..."
      else
        AVAILABLE_IP="$TEST_IP"
        break
      fi
    done
    
    if [[ -n "$AVAILABLE_IP" ]]; then
      info "Available IP found: $AVAILABLE_IP"
      STATIC_IP="$AVAILABLE_IP"
    else
      warn "No available IPs found in ${NETWORK_PREFIX}.230-.254 range."
      read -p "Enter static IP address manually (or press Enter to skip): " MANUAL_IP
      if [[ -z "$MANUAL_IP" ]]; then
        info "Skipping static IP setup"
        echo
        # Skip to next section
        echo "# ============================================================================
# 1. Install Rust (via rustup)
# ============================================================================"
        return 0
      else
        STATIC_IP="$MANUAL_IP"
      fi
    fi
    
    SUBNET_DEFAULT="24"
    read -p "Enter subnet mask (e.g., 24 for /24) [$SUBNET_DEFAULT]: " SUBNET
    SUBNET=${SUBNET:-$SUBNET_DEFAULT}
    
    DNS_DEFAULT="8.8.8.8,1.1.1.1"
    read -p "Enter DNS servers (e.g., 8.8.8.8,1.1.1.1) [$DNS_DEFAULT]: " DNS_SERVERS
    DNS_SERVERS=${DNS_SERVERS:-$DNS_DEFAULT}
    
    # Backup existing netplan
    if [[ -f /etc/netplan/01-netcfg.yaml ]]; then
      sudo cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup
      info "Backed up existing netplan config"
    fi
    
    # Create new netplan config
    sudo bash -c "cat > /etc/netplan/01-netcfg.yaml" <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $STATIC_IP/$SUBNET
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
EOF
    
    # Apply netplan
    if sudo netplan apply 2>/dev/null; then
      ok "Static IP configured: $STATIC_IP"
      info "Reconnect your SSH session to the new IP if needed."
      sleep 5
    else
      warn "Netplan apply failed. Check configuration."
      # Restore backup
      if [[ -f /etc/netplan/01-netcfg.yaml.backup ]]; then
        sudo mv /etc/netplan/01-netcfg.yaml.backup /etc/netplan/01-netcfg.yaml
        sudo netplan apply 2>/dev/null || true
      fi
    fi
  else
    info "Skipping static IP setup"
  fi
  echo
fi

# ============================================================================
# 1. Install Rust (via rustup)
# ============================================================================
# 1. Install Rust (via rustup)
# ============================================================================
info "Installing Rust toolchain..."

# Always install as current user (script runs as user, not root)
ACTUAL_USER="$(whoami)"
USER_HOME="$HOME"
info "Installing Rust for current user: $ACTUAL_USER"

# Download official rustup installer from verified source
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rustup-init.sh 2>/dev/null || err "Failed to download rustup"

# Install as current user
bash /tmp/rustup-init.sh -y --default-toolchain stable 2>&1 | grep -E "(Installed|latest)" || true

# Source cargo environment
source "$HOME/.cargo/env" 2>/dev/null || true

# Verify installation
if ! command -v cargo &>/dev/null; then
  err "cargo not found after installation"
fi

CARGO_VERSION=$(cargo --version 2>/dev/null)
ok "Rust installed for $ACTUAL_USER: $CARGO_VERSION"
ok "Rust binaries located at: $USER_HOME/.cargo/bin"

# Add to PATH for this session
export PATH="$PATH:$USER_HOME/.cargo/bin"
echo

# ============================================================================
# 2. Install Go
# ============================================================================
info "Installing Go..."

# Detect architecture (amd64 or arm64)
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) GO_ARCH="amd64" ;;
  aarch64) GO_ARCH="arm64" ;;
  *) err "Unsupported architecture: $ARCH" ;;
esac

# Use Go 1.22.0 stable release (verified available)
GO_VERSION="1.22.0"

GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_FILE="/tmp/go-${GO_VERSION}.tar.gz"

# Download Go binary with verification
info "Downloading Go ${GO_VERSION}..."
if ! curl -fL "$GO_URL" -o "$GO_FILE"; then
  err "Failed to download Go from $GO_URL"
fi

if [[ ! -f "$GO_FILE" ]]; then
  err "Go download file not created: $GO_FILE"
fi

# Extract to /usr/local (requires sudo)
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_FILE" || err "Failed to extract Go"
rm -f "$GO_FILE"

# Add to PATH
export PATH="$PATH:/usr/local/go/bin"

# Verify installation
if ! command -v go &>/dev/null; then
  err "go not found after installation"
fi

GO_VERSION_CHECK=$(go version 2>/dev/null)
ok "Go installed: $GO_VERSION_CHECK"
echo

# ============================================================================
# 3. Verify both toolchains
# ============================================================================
info "Verifying toolchain versions..."

echo "Rust:"
rustc --version
cargo --version
echo

echo "Go:"
go version
echo

# ============================================================================
# Done
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "TOOLCHAIN SETUP COMPLETE ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "Rust: $(cargo --version)"
info "Go:   $(go version | awk '{print $3}')"
echo
info "Both toolchains ready for Zebra (Rust) and other builds (Go)"
echo

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================
read -p "Did toolchain setup complete successfully? (Y/n default=Y): " TOOLCHAIN_OK
TOOLCHAIN_OK=${TOOLCHAIN_OK:-Y}

if [[ "$TOOLCHAIN_OK" =~ ^[Yy]$ ]]; then
  ok "Toolchain confirmed. Starting Caddy setup..."
  echo
  # AUTO-CHAIN: Automatically run the next script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "$SCRIPT_DIR/zecnode-caddy-setup.sh"
else
  err "Toolchain issue reported. Check output above and try again."
  echo
  info "Troubleshooting:"
  info "  Check Rust: cargo --version"
  info "  Check Go: go version"
  info "  Check PATH: echo \$PATH"
  echo
  exit 1
fi

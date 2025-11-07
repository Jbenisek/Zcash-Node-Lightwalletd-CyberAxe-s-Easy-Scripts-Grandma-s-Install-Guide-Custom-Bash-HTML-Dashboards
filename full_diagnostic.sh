#!/bin/bash
# COMPREHENSIVE ZCASH NODE DIAGNOSTIC SCRIPT
# Run this ONCE on Linux Mint to gather ALL diagnostic information
# Output will be saved to diagnostic_report.txt for analysis

echo "🔍 COMPREHENSIVE ZCASH NODE DIAGNOSTIC REPORT"
echo "=============================================="
echo "Generated: $(date)"
echo "System: $(uname -a)"
echo ""

# Create diagnostic report file
REPORT_FILE="diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"
echo "📄 Saving full report to: $REPORT_FILE"
echo ""

exec > >(tee "$REPORT_FILE") 2>&1

echo "🔍 COMPREHENSIVE ZCASH NODE DIAGNOSTIC REPORT"
echo "=============================================="
echo "Generated: $(date)"
echo "System: $(uname -a)"
echo ""

echo "📊 SYSTEM INFORMATION:"
echo "======================"
echo "OS Version:"
lsb_release -a 2>/dev/null || cat /etc/os-release
echo ""

echo "Kernel:"
uname -a
echo ""

echo "Memory:"
free -h
echo ""

echo "Disk Usage:"
df -h
echo ""

echo "CPU Info:"
nproc && cat /proc/cpuinfo | grep "model name" | head -1
echo ""

echo "📡 NETWORK INFORMATION:"
echo "======================="
echo "Network Interfaces:"
ip addr show
echo ""

echo "Default Route:"
ip route show
echo ""

echo "DNS Configuration:"
cat /etc/resolv.conf
echo ""

echo "Internet Connectivity Test:"
ping -c 3 8.8.8.8
echo ""

echo "DNS Resolution Test:"
nslookup google.com 2>/dev/null || host google.com
echo ""

echo "🔧 SERVICE CONFIGURATIONS:"
echo "=========================="
echo "Systemd Services Status:"
sudo systemctl status zebrad --no-pager -l 2>/dev/null || echo "zebrad service not found"
echo "---"
sudo systemctl status lightwalletd --no-pager -l 2>/dev/null || echo "lightwalletd service not found"
echo "---"
sudo systemctl status caddy --no-pager -l 2>/dev/null || echo "caddy service not found"
echo ""

echo "Service Files:"
echo "Zebra service file:"
sudo cat /etc/systemd/system/zebrad.service 2>/dev/null || echo "zebrad.service not found"
echo ""

echo "lightwalletd service file:"
sudo cat /etc/systemd/system/lightwalletd.service 2>/dev/null || echo "lightwalletd.service not found"
echo ""

echo "Caddy service file:"
sudo cat /etc/systemd/system/caddy.service 2>/dev/null || echo "caddy.service not found"
echo ""

echo "💾 DATA DIRECTORIES & FILES:"
echo "============================"
echo "Zcash Data Paths:"
ls -la / 2>/dev/null | grep -E "(zebra|lightwalletd)" || echo "No zcash dirs in /"
echo ""

echo "Zebra Data Directory:"
ls -la //zebra 2>/dev/null || echo "//zebra not found"
du -sh //zebra 2>/dev/null || echo "Cannot check //zebra size"
find //zebra -type f -exec ls -lh {} \; 2>/dev/null | head -10 || echo "No files in //zebra"
echo ""

echo "lightwalletd Data Directory:"
ls -la //lightwalletd 2>/dev/null || echo "//lightwalletd not found"
du -sh //lightwalletd 2>/dev/null || echo "Cannot check //lightwalletd size"
find //lightwalletd -type f -exec ls -lh {} \; 2>/dev/null | head -10 || echo "No files in //lightwalletd"
echo ""

echo "🔧 CONFIGURATION FILES:"
echo "======================="
echo "Zebra Config:"
sudo cat /home/root/.config/zebrad.toml 2>/dev/null || echo "Zebra config not found at /home/root/.config/zebrad.toml"
echo ""

echo "lightwalletd Config:"
sudo cat /etc/lightwalletd/zcash.conf 2>/dev/null || echo "lightwalletd config not found"
echo ""

echo "Caddy Config:"
sudo cat /etc/caddy/Caddyfile 2>/dev/null || echo "Caddyfile not found"
echo ""

echo "Zcash Node Config:"
sudo cat /etc/zecnode/zecnode.conf 2>/dev/null || echo "zecnode.conf not found"
echo ""

echo "🌐 NETWORK PORTS & CONNECTIONS:"
echo "==============================="
echo "Listening Ports:"
sudo netstat -tlnp 2>/dev/null | grep -E ":(80|443|8232|9067)" || echo "Required ports not listening"
echo ""

echo "All Listening Ports:"
sudo netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null || echo "Cannot check ports"
echo ""

echo "Firewall Status:"
sudo ufw status verbose 2>/dev/null || sudo iptables -L 2>/dev/null || echo "Cannot check firewall"
echo ""

echo "📝 LOG FILES (Last 50 lines each):"
echo "=================================="
echo "Zebra Logs:"
sudo journalctl -u zebrad -n 50 --no-pager 2>/dev/null || echo "Cannot read zebrad logs"
echo ""

echo "lightwalletd Logs:"
sudo journalctl -u lightwalletd -n 50 --no-pager 2>/dev/null || echo "Cannot read lightwalletd logs"
echo ""

echo "Caddy Logs:"
sudo journalctl -u caddy -n 50 --no-pager 2>/dev/null || echo "Cannot read caddy logs"
echo ""

echo "System Logs (last 20 lines):"
sudo journalctl -n 20 --no-pager 2>/dev/null || echo "Cannot read system logs"
echo ""

echo "🔄 PROCESSES:"
echo "============="
echo "Zcash Related Processes:"
ps aux | grep -E "(zebra|lightwalletd|caddy)" | grep -v grep || echo "No zcash processes found"
echo ""

echo "All Processes (top 20 by memory):"
ps aux --sort=-%mem | head -20
echo ""

echo "📊 RESOURCE USAGE:"
echo "=================="
echo "Disk I/O:"
iostat -x 1 3 2>/dev/null || echo "iostat not available"
echo ""

echo "Network I/O:"
sudo nethogs -t 2>/dev/null || echo "nethogs not available - install with: sudo apt install nethogs"
echo ""

echo "🔍 ZEBRA SPECIFIC DIAGNOSTICS:"
echo "==============================="
echo "Zebra Version:"
/usr/local/bin/zebrad --version 2>/dev/null || echo "zebrad not found"
echo ""

echo "Zebra Help:"
/usr/local/bin/zebrad --help 2>/dev/null | head -20 || echo "Cannot get zebrad help"
echo ""

echo "Test Zebra Config Validation:"
sudo -u root /usr/local/bin/zebrad -c /home/root/.config/zebrad.toml validate-config 2>&1 || echo "Config validation failed"
echo ""

echo "🔍 LIGHTWALLETD SPECIFIC DIAGNOSTICS:"
echo "====================================="
echo "lightwalletd Version:"
/usr/local/bin/lightwalletd --version 2>/dev/null || echo "lightwalletd not found"
echo ""

echo "Test lightwalletd Config:"
/usr/local/bin/lightwalletd --help 2>/dev/null | head -10 || echo "Cannot get lightwalletd help"
echo ""

echo "🔍 CADDY SPECIFIC DIAGNOSTICS:"
echo "=============================="
echo "Caddy Version:"
caddy version 2>/dev/null || echo "caddy not found"
echo ""

echo "Caddy Config Test:"
caddy validate --config /etc/caddy/Caddyfile 2>/dev/null || echo "Caddy config invalid"
echo ""

echo "📋 INSTALLED PACKAGES:"
echo "======================"
echo "Zcash Related Packages:"
dpkg -l | grep -E "(zebra|lightwalletd|caddy|rust|go)" || echo "No zcash packages found"
echo ""

echo "Build Tools:"
dpkg -l | grep -E "(gcc|make|pkg-config|git)" || echo "Build tools not found"
echo ""

echo "🕐 TIMING & PERFORMANCE:"
echo "========================"
echo "System Uptime:"
uptime
echo ""

echo "Service Uptime:"
sudo systemctl show zebrad -p ActiveEnterTimestamp 2>/dev/null || echo "zebrad uptime unknown"
sudo systemctl show lightwalletd -p ActiveEnterTimestamp 2>/dev/null || echo "lightwalletd uptime unknown"
sudo systemctl show caddy -p ActiveEnterTimestamp 2>/dev/null || echo "caddy uptime unknown"
echo ""

echo "⏰ TIME SYNCHRONIZATION:"
echo "======================="
echo "System Time:"
date
echo ""

echo "NTP Status:"
timedatectl status 2>/dev/null || echo "timedatectl not available"
echo ""

echo "🎯 FINAL SUMMARY:"
echo "================="
echo "Report generated: $(date)"
echo "Report saved to: $REPORT_FILE"
echo ""
echo "Please upload this entire report for analysis."
echo "It contains ALL diagnostic information needed to fix the Zcash node."
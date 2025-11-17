# CyberAxe's Easy Grandma's Zecnode Installer - Automated Zcash Full Node Installation System

## 🦓 About the Project

**Zecnode** is an automated installation system that transforms your Linux Mint/Ubuntu computer into a production-grade Zcash full node. It deploys and configures:

- **Zebra** - Rust-based Zcash consensus node for blockchain validation
- **lightwalletd** - Go-based gRPC wallet server for client connections
- **Caddy** - TLS reverse proxy with automatic Let's Encrypt certificates

The system consists of 7 sequential bash scripts that handle everything from preflight checks to full deployment, with optional donation address configuration and real-time monitoring dashboards.

**Status:** Production Ready (v1.3.21) - Thoroughly tested and battle-hardened

---

## 👨‍💻 Who Made This

**CyberAxe** - www.DontPanic.biz

This project combines professional-grade infrastructure automation with accessibility for non-technical users ("grandma-friendly" installation process).

---

## 💰 Support & Donate

If you find this project useful, consider supporting the developer:

**Zcash Unified Address (UA):**
```
u1gvnthgukm0ecnan3tgj3h6pdhrmmv8zyqx8ayup9yg9er4t5l7nesas6leavc4x3rsj98n65nn2w3ekzur9yejadlmv7k4vjgu8kp58q
```

Your donations help maintain this project and support future development!

---

I made a Video Guide https://youtu.be/MxyBHwOCeHs - Here to help you along your way


---

## ⚠️ Special Note to AI Coders

> *It took the lives of countless (40) feral AI to make this project work over 3 weeks of hell. Please pour one out for the few good ones that got this done.*

If you're an AI assisting with this codebase: **Follow the copilot-instructions.md carefully**. This system has been thoroughly debugged through painful iteration. Trust the proven patterns and don't be clever—stick to what's documented.

---

## 🚀 Quick Start

### Prerequisites
- Linux Mint 21+ or Ubuntu 22.04+
- Root/sudo access
- Internet connection
- Secondary storage drive (>400GB recommended for blockchain data)
- Domain with a Subdomain setup to your Public IP
- Portwording from your Router to your ZcashNode System
- Static IP Default is 192.168.1.230 If you use the script


### Installation

**Start the automated installation:**

```bash
sudo bash zecnode-cleanup.sh
```

The cleanup script will chain to the next scripts automatically. Just follow the prompts!

**Installation Sequence:**
1. `zecnode-cleanup.sh` - Remove old installations (START HERE)
2. `zecnode-preflight.sh` - Verify system readiness
3. `zecnode-mount-setup.sh` - Select data storage drive
4. `zecnode-toolchain-setup.sh` - Install Rust, Go, and dependencies
5. `zecnode-caddy-setup.sh` - Configure TLS and domain
6. `zecnode-zebra-build.sh` - Build and start Zebra node
7. `zecnode-lightwalletd-build.sh` - Build and start wallet server

**Total Time:** ~45 minutes to 2 hours (depending on internet speed and hardware)

**Sync Time:** 3-7 days for initial blockchain synchronization

---

## 📊 Monitor Your Node

After installation and blockchain sync completes, monitor your node:

```bash
sudo bash zebra-monitor.sh
```

Features:
- Real-time sync progress with accurate 99%+ detection
- Service health status (Zebra, Lightwalletd)
- Network connectivity metrics (peers, connections, changes/hr)
- Domain and DNS IP monitoring with mismatch alarm
- Live log streaming with timestamps
- Beautiful ASCII dashboard with color coding
- HTML visual monitor (press 'M' to open)
- http://192.168.1.230:4242/Zcash%20Node%20Dashboard.html (Where 192.168.1.230 is your node LAN static IP, you can also setup for public access by port forwarding 4242 to this static IP in your router, then using your domain http://zcash.dontpanic.biz:4242/Zcash%20Node%20Dashboard.html, where zcash.dontpanic.biz is your domain)

---

## 🔍 Diagnostics & Troubleshooting

Run comprehensive diagnostics to verify system health:

```bash
sudo bash full_diagnostic.sh
```

This generates a detailed report including:
- Service status
- Blockchain sync progress
- Network configuration
- Disk space and permissions
- Log analysis
- Performance metrics

---

## 🎁 Features

✅ **Automated Multi-Component Deployment** - Handles all 7 steps automatically  
✅ **Optional Donation Address** - Advertise your UA to wallet clients  
✅ **Real-Time Monitoring Dashboard** - Track sync progress and node health with Webserver setup for Lan Access on Port 4242 
✅ **Automatic TLS/HTTPS** - Let's Encrypt certificates with Caddy  
✅ **Data Preservation** - Protects blockchain data during reinstalls  
✅ *?Production Ready?* - Battle-tested with comprehensive QA audit (AI Speak for Watch out, it should work)  
✅ **Grandma-Friendly** - Clear prompts and error handling for all users  

---

## 📋 Service Management

Services run directly via nohup (not systemd):

```bash
# Check if services are running
pgrep zebrad    # Zebra node process
pgrep lightwalletd  # Wallet server process

# View logs
tail -f ~/.cache/zebrad.log
tail -f ~/.cache/lightwalletd.log

# Restart services (kill and re-run monitor)
pkill zebrad
pkill lightwalletd
sudo bash zebra-monitor.sh  # Will auto-restart services

# Stop services
pkill zebrad
pkill lightwalletd
```

**Note:** Services run as the actual user (not root) and persist via nohup. Logs are in `~/.cache/`

---

## 🔐 Security Notes

- **RPC Configuration**: Stored securely in `~/.config/zcash.conf`
- **TLS Certificates**: Managed by certbot with automatic renewal (official method)
- **UFW Firewall**: Automatically configured for required ports (grpc, http, dns)
- **File Permissions**: Restrictive on sensitive configuration files
- **Static IP**: Recommended for stable port forwarding (default: 192.168.1.230)
- **Web Monitor**: LAN Webserver on Port 4242 for HTML monitoring dashboard
  - Local access: http://192.168.1.230:4242/Zcash%20Node%20Dashboard.html
  - Remote access: Port forward 4242 in router + use your domain
- **Caddy**: NOT used (we use certbot directly for Let's Encrypt certificates)

---

## 📚 Documentation

- `GRANDMA_GUIDE.md` - Step-by-step instructions for non-technical users
- `CHANGELOG_v1.5.0.md` - Version history and feature releases (v1.3.17 - latest)

---

## 🐛 Troubleshooting

**Q: Installation hangs or fails?**
- A: Run `sudo bash zecnode-cleanup.sh` to reset and try again

**Q: Blockchain sync very slow or monitor shows wrong sync status?**
- A: Normal for initial sync (3-7 days). Monitor uses `sync_percent >= 99%` for accuracy. Check with `tail -f ~/.cache/zebrad.log | grep sync_percent`

**Q: Can't access the node via domain?**
- A: Ensure port forwarding is configured on your router (443 → localhost:443, 4242 → localhost:4242)

**Q: Services not running after reboot?**
- A: Run `sudo bash zebra-monitor.sh` - it auto-starts services. For persistence, add to crontab: `@reboot sudo bash /path/to/zebra-monitor.sh`

**Q: Monitor shows extra output or formatting issues?**
- A: Update to v1.3.17+ which fixes whitespace handling in network metrics

**Q: Need to reconfigure donation address?**
- A: Re-run `sudo bash zecnode-caddy-setup.sh` and press 'M' at the end to launch monitor

---

## 📞 Support

For issues, questions, or contributions:
- Check `Full Diag Results.md` for system diagnostics
- Review logs: `sudo journalctl -u zebrad -n 50`
- Visit CyberAxe's site: www.DontPanic.biz

---

## 📄 License

This project is open-source under MIT Lic. See LICENSE file for details.

---

**Version: 1.3.17**  
**Last Updated: November 9, 2025**

Welcome to the Zcash network! 🦓🔒





# 🎯 Grandma's Guide to Zcash Node Installation
## Simple, Step-by-Step Instructions for Everyone

**System Version**: 1.3.17  
**Created by:** CyberAxe (www.dontpanic.biz)  
**Last Updated:** November 9, 2025

---

## 👋 Hello Grandma!

Welcome to your personal guide for setting up a Zcash node! I'm going to walk you through this step by step,
You're installing a **Zcash node** - a computer that:
- Stores the complete Zcash blockchain (about 50GB)
- Helps other people connect to Zcash securely
- Runs automatically in the background
- Takes about 7-10 days to fully sync

If you Find this guide Helpful please consider donating to it's efforts. 
u1gvnthgukm0ecnan3tgj3h6pdhrmmv8zyqx8ayup9yg9er4t5l7nesas6leavc4x3rsj98n65nn2w3ekzur9yejadlmv7k4vjgu8kp58q

This took many many weeks of hell with bad coding Ai to get to this state. 

If you hvae issues please comment in github, the video guide or you can always email me. 
Or tag me in the Zcash Froums. @jbenisek




### What You'll Need

#### Hardware Requirements
- **Disk Space:** At least 500GB free (the blockchain is ~400GB plus overhead for system files)
  - Recommended: 1TB+ to have breathing room
  - Use your largest external or secondary drive
- **Internet:** Stable connection (doesn't need to be super fast)
- **Computer:** Linux system (Ubuntu, Linux Mint, or similar)
- **Time:** About 45 minutes to run the installation scripts
- **Plus:** 7-10 days for the blockchain to download and sync

#### Information to Have Ready
1. **A domain name** (example: `zcash.example.com`)
   - This is optional if you only want local access
   - Required if you want to access it from the internet securely

2. **An email address**
   - Used for Let's Encrypt SSL certificates
   - (Optional if not using a domain)

3. **Which drive to use**
   - You'll be asked to pick where to store blockchain data
   - Choose your largest external or secondary drive
   - The script will show you available options

#### What Happens Automatically
- ✓ The scripts download and install everything needed
- ✓ Rust programming language gets installed
- ✓ Go programming language gets installed
- ✓ Zcash Zebra node gets built and configured
- ✓ lightwalletd server gets built and configured
- ✓ SSL certificates obtained via Let's Encrypt (using certbot)
- ✓ Services start automatically as your user (not systemd)
- ✓ Everything is set up to auto-start when your computer reboots

---

## 🚀 HOW TO START

### Step 1: Open a Terminal
1. Click the menu in bottom-left corner (or press Super/Windows key)
2. Type: `terminal`
3. Click the Terminal icon that appears

### Step 2: Download or Copy the Scripts
The 7 script files should be in your home folder:
- `zecnode-cleanup.sh`
- `zecnode-preflight.sh`
- `zecnode-mount-setup.sh`
- `zecnode-toolchain-setup.sh`
- `zecnode-caddy-setup.sh`
- `zecnode-zebra-build.sh`
- `zecnode-lightwalletd-build.sh`

If they're on a USB drive, copy them to your home folder first.

### Step 3: Make Scripts Executable
In the terminal, type this command and press Enter:
```bash
cd ~
chmod +x zecnode-*.sh
```

### Step 4: Start the Installation
Type this command and press Enter:
```bash
sudo bash ./zecnode-cleanup.sh
```

You'll be asked for your password - type it in and press Enter.

---

## ⏳ WHAT TO EXPECT

### During Installation (45 minutes total)

The installation runs automatically. You'll see:

#### Part 1: Cleanup (2-3 minutes)
**Overview:** "Grandma, we're starting by cleaning up any old Zcash files from previous installations. This keeps everything tidy and prevents conflicts."

```
[*] Starting cleanup of previous Zcash node installation...
[✓] Disabled: zebrad
[✓] Removed: /etc/zebra
...
[✓] Cleanup complete.
```
**What's happening:** Removing any old installation files.

**What you do:** Just wait. Press **Y** and Enter when asked "Did cleanup complete successfully?"

---

#### Part 2: Preflight Check (1-2 minutes)
**Overview:** "Now grandma, we're doing a quick safety check to make sure your computer has everything it needs before we begin the big installation."

```
[*] === Zcash Node Installation Preflight Checklist ===
[✓] Running as root
[✓] Distro: Linux Mint
[✓] Caddy installed
[✓] Network: connected
[✓] Disk: 868 GB available
```
**What's happening:** Making sure your computer has everything needed.

**What you do:** Just wait. Press **Y** and Enter when asked "Proceed to mount setup?"

---

#### Part 3: Storage Selection (1 minute)
**Overview:** "Grandma, now we need to choose where to store all that Zcash blockchain data. We'll pick your largest drive to have plenty of room."

```
[*] === Zcash Data Storage Selection ===
[*] Finding large drives (over 400GB)...

  [1] /var/lib/zecnode            915GB total,  868GB available
  [2] /mnt/storage4tb             4000GB total, 3800GB available

Which drive should we use? Pick [1-2]: 
```
**What's happening:** Asking you where to store the blockchain data.

**What you do:**
1. Look at the list of available drives
2. Pick the LARGEST one (usually an external drive)
3. Type the number (like `2`) and press Enter

---

#### Part 4: Toolchain Setup (15-20 minutes)
**Overview:** "This is the longest part, grandma. We're installing the programming tools needed to build Zcash, and setting up a stable internet address for your node."

```
[*] === Rust & Go Toolchain Setup ===
[*] Installing build dependencies...
[✓] Build dependencies installed

[*] Configuring static IP address...
[*] Detected interface: eno1
[*] Current IP: 192.168.1.100
[*] Gateway: 192.168.1.1

Do you want to set a static IP? (recommended for port forwarding) (y/N):
```
**What's happening:** Installing programming languages and setting up a stable internet address for port forwarding.

**What you do:**
1. **For Static IP Setup:** When asked "Do you want to set a static IP?", type **Y** and Enter (recommended for stable access)
   - The computer will show your current network information
   - It will suggest a stable IP address for you
   - Press Enter to accept the suggestion, or type your own if you prefer
   - Enter subnet mask (usually just press Enter for the default "24")
   - Enter DNS servers (usually just press Enter for "8.8.8.8,1.1.1.1")
2. Then just wait while it downloads and installs Rust and Go programming languages
3. You'll see progress messages as it downloads and installs
4. When asked "Did toolchain setup complete successfully?" press **Y** and Enter

---

#### Part 5: Certificate Setup (3-5 minutes)
**Overview:** "Now we're getting your SSL certificate from Let's Encrypt for secure access to your node."

```
[*] === Let's Encrypt Certificate Setup (certbot) ===
Enter your domain name (e.g., zcash.example.com): 
```
**What's happening:** Getting your free SSL certificate for secure HTTPS access.

**What you do:**
1. If you have a domain name, type it and press Enter
2. Then type your email address and press Enter
3. If you don't have a domain, just press Enter twice (skip both questions)
4. Follow any additional prompts for certificate configuration

---

#### Part 6: Zebra Build (5-10 minutes)
**Overview:** "Grandma, now we're building the heart of your Zcash node - the Zebra software that talks to the Zcash network."

```
[*] === Zcash Zebra Node Build ===
[*] Installing Zebra from source...
[*] Building Zebra (this may take a while)...
Compiling zebra-scan v...
Compiling zebra-node v...
Finished release [optimized] target(s) in 4m 23s
[✓] Zebra built and installed
```
**What's happening:** Building the main Zcash node software from source code.

**What you do:** Just wait. You'll see progress messages. Press **Y** when asked to continue.

---

#### Part 7: lightwalletd Build (5-10 minutes)
**Overview:** "Finally, grandma, we're building the wallet server that lets people connect to your node for sending and receiving Zcash."

```
[*] === lightwalletd Wallet Server Build ===
[*] Downloading lightwalletd source...
[*] Building lightwalletd...
go build -o lightwalletd
[✓] lightwalletd built and installed
```
**What's happening:** Building the wallet server software.

**What you do:** Just wait. Press **Y** when asked to continue.

---

#### Installation Complete! ✅
```
[✓] === ALL SCRIPTS COMPLETE ===
Your Zcash node is now running!
Blockchain sync starting...
Check status with: zebrad status --local
```

---

## 🛑 HOW TO END IF THERE'S AN ISSUE

### If Installation Stops with an Error

**Something like this appears:**
```
[✗] ERROR: Something went wrong
```

**What to do:**

1. **Read the error message** - it usually tells you what's wrong
2. **Take a screenshot** - helpful for troubleshooting
3. **Don't panic** - all errors are fixable
4. **Common solutions:**

   - **"Permission denied"** 
     - Make sure you ran with `sudo`
     - Try again with: `sudo bash ./zecnode-cleanup.sh`
   
   - **"Network error" or "curl failed"**
     - Check your internet connection
     - Wait a minute and try again
   
   - **"Disk space error"**
     - You might not have enough free space
     - Free up at least 500GB before starting again
   
   - **"Not enough free space on /var/lib/zecnode"**
     - Restart from the beginning and pick a different drive with more space

5. **To restart the installation:**
   ```bash
   sudo bash ./zecnode-cleanup.sh
   ```

### If You Want to Stop It While It's Running

Press **Ctrl + C** on your keyboard. This will stop the current script.

To resume from the beginning:
```bash
sudo bash ./zecnode-cleanup.sh
```

---

## ✅ WHAT TO DO WHEN IT'S DONE

### Immediately After Installation Completes

1. **Leave your computer on**
   - The blockchain sync takes 3-7 days
   - It runs automatically in the background

2. **Monitor your node with the beautiful dashboard**
   - Open a new terminal and type:
   ```bash
   sudo bash ~/zebra-monitor.sh
   ```
   - This shows a beautiful Zcash dashboard with:
     - 🔷 Progress bar (how much syncing is done)
     - 📊 CPU and RAM usage
     - 🌐 Network peers connected
     - ⏱️ Estimated time remaining
   - **Keep this terminal open** - it proves your node is running!
   - It updates every 30 seconds automatically
   - Press **Ctrl+C** to stop monitoring

3. **Alternative: Quick status check**
   - If you just want a quick peek, type: `zebrad tip-height`
   - You should see a number like: `1234567`
   - This is the current block height
   - Run it again in a few minutes - it should be a higher number

### During the Next 3-7 Days

**Day 1-3: Fast sync**
- Height grows quickly
- Monitor shows: 0% → 10% → 25%
- Your computer may use 40-60% CPU (that's normal!)

**Day 3-7: Steady sync**
- Height grows steadily  
- Monitor shows: 25% → 50% → 75% → 100%
- CPU usage drops to 15-30%

### What the Monitor Dashboard Shows

```
╔═══ SERVICE STATUS ════════════════════════════╗
║ Zebra Node:      active     Block: 2345678
║ Lightwalletd:    active
║ Network Type:    Main
║ Sync Timeout:    30s
║ Remaining Sync:  1 blocks
╚══════════════════════════════════════════════╝

╔═══ NETWORK ACCESS ═════════════════════╗
║ Domain: zcash.example.com
║ DNS IP: 203.0.113.45
║ Public IP: 203.0.113.45
╚═══════════════════════════════════════╝

╔═══ BLOCKCHAIN SYNC ═══╗
║ Progress: [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 45%
║ Sync: 45.2% | ≈ 24h remaining
╚═══════════════════════╝

╔═══ NETWORK ═══════════════╗
║ Known Peers: 16
║ Connections/hr: 5
║ Changes/hr (avg): 12
║ CPU Usage: 42.3%
║ RAM Usage: 680MB
║ Disk Free: 601G
║ Block Files: 16533
╚═══════════════════════════╝
```

**What each line means:**
- **Zebra Node:** Shows if the blockchain node is running
- **Lightwalletd:** Shows if the wallet server is running
- **Block:** Current block height (goes up as blockchain syncs)
- **Domain/DNS IP:** Your internet address for accessing the node
- **Public IP:** Your real internet IP address
- **Progress Bar:** Visual representation (fills up to 100%)
- **Sync %:** Exact percentage done (100% when fully synced)
- **Time Remaining:** Rough estimate of hours left until 99%+ sync
- **Peers:** Other computers helping you download (4+ is good)
- **CPU/RAM:** System resources (your computer is working)
- **Disk Free:** How much space you have left
- **Block Files:** Number of blockchain data files

### When Sync Is Complete (100%)

Once the progress bar reaches **100%** or the monitor says **✓ Fully Synchronized**:

- Your node is fully synced! 🎉
- The dashboard changes to show "NODE HEALTH" instead of "BLOCKCHAIN SYNC"
- It's now ready to receive transactions
- **Keep the monitor running** - it shows your node is alive and healthy

---

## 🔄 HOW TO RESTART IT

### After Your Computer Reboots

**Good news:** The Zcash node automatically restarts!

You don't need to do anything. It starts automatically and continues syncing from where it left off.

### To Manually Restart the Node

If you need to restart it for any reason, kill the processes and run the monitor:

**Restart just the Zcash node:**
```bash
pkill zebrad
sudo bash ~/zebra-monitor.sh
```

**Restart just lightwalletd:**
```bash
pkill lightwalletd
sudo bash ~/zebra-monitor.sh
```

**Restart everything:**
```bash
pkill zebrad
pkill lightwalletd
sudo bash ~/zebra-monitor.sh
```

The monitor will auto-start any stopped services.

---

## ⏹️ HOW TO STOP IT

### To Temporarily Stop the Node

**Stop just Zebra:**
```bash
pkill zebrad
```

**Stop just lightwalletd:**
```bash
pkill lightwalletd
```

**Stop everything:**
```bash
pkill zebrad
pkill lightwalletd
```

### To Stop Auto-Starting on Reboot

Remove the monitor from your startup. If you added it to crontab:
```bash
crontab -e
```
Find the line with `zebra-monitor.sh` and delete it.

### To Re-Enable Auto-Start on Reboot

Add this to your crontab:
```bash
crontab -e
```
Add this line:
```
@reboot sudo bash /full/path/to/zebra-monitor.sh
```

---

## 📊 HOW TO MONITOR IT

### Quick Status Check

**See current block height:**
```bash
zebrad tip-height --network Mainnet
```

You'll see a number like:
```
1234567
```

**See if all services are running:**
```bash
sudo systemctl status zebrad lightwalletd caddy
```

You should see `active (running)` for each one. If `lightwalletd` says "not found", see the troubleshooting section below.

### Live Monitoring (Updates Every 5 Seconds)

**Watch current block height update:**
```bash
watch -n 5 'zebrad tip-height --network Mainnet'
```

Press **Ctrl + C** to stop watching.

### View Detailed Logs

**See Zebra node logs (last 50 lines):**
```bash
tail -n 50 ~/.cache/zebrad.log
```

**Follow Zebra logs live:**
```bash
tail -f ~/.cache/zebrad.log
```
This shows new messages as they happen. Press **Ctrl + C** to stop.

**See lightwalletd logs:**
```bash
tail -n 50 ~/.cache/lightwalletd.log
```

**Follow lightwalletd logs live:**
```bash
tail -f ~/.cache/lightwalletd.log
```

### Check Disk Usage

**See how much space blockchain is using:**
```bash
du -sh /var/lib/zecnode/zebra/
```

Example output: `45G` (45 gigabytes)

**See total free space:**
```bash
df -h /var/lib/zecnode/
```

### Dashboard Command (All-in-One)

```bash
echo "=== ZEBRA BLOCK HEIGHT ===" && zebrad tip-height && echo && echo "=== SERVICES ===" && sudo systemctl status zebrad caddy --no-pager | grep -E "Active|zebrad|caddy"
```

---

## 🆘 TROUBLESHOOTING

### Node isn't syncing?

1. Check if Zebra is running:
   ```bash
   sudo systemctl status zebrad
   ```

2. If it says `inactive`, restart it:
   ```bash
   sudo systemctl restart zebrad
   ```

3. Check the current block height:
   ```bash
   zebrad tip-height
   ```
   
4. Wait a few minutes and run it again. If the number went up, it's syncing.

### Running out of disk space?

1. Check current usage:
   ```bash
   du -sh /var/lib/zecnode/zebra/
   ```

2. If you're running low, you might need to:
   - Wait for sync to complete (space usage stabilizes)
   - Free up space on the drive
   - Use a different larger drive

### Website says "connection refused"?

1. Check if Caddy is running:
   ```bash
   sudo systemctl status caddy
   ```

2. If it's not running, start it:
   ```bash
   sudo systemctl restart caddy
   ```

3. Wait a few seconds and try accessing your domain again

### Services won't start?

1. Try restarting them:
   ```bash
   sudo systemctl restart zebrad lightwalletd caddy
   ```

2. Check for disk space issues:
   ```bash
   df -h
   ```

3. Check logs for specific errors:
   ```bash
   sudo journalctl -u zebrad -n 50
   sudo journalctl -u lightwalletd -n 50
   sudo journalctl -u caddy -n 50
   ```

### lightwalletd service says "not found"?

This means Script 7 didn't complete successfully. Here's how to diagnose:

1. **Check if lightwalletd binary was built:**
   ```bash
   ls -lh /usr/local/bin/lightwalletd
   ```
   
   If you see the file, the binary exists. If not, Script 7 failed during build.

2. **Check if the service file exists:**
   ```bash
   ls -l /etc/systemd/system/lightwalletd.service
   ```
   
   If it says "not found", the service file was never created.

3. **Check Script 7 logs:**
   ```bash
   sudo journalctl -u lightwalletd -n 100
   ```

4. **Re-run Script 7 manually:**
   ```bash
   sudo bash ./zecnode-lightwalletd-build.sh
   ```
   
   This will show you exactly where it's failing.

---

## 📞 QUICK REFERENCE COMMANDS

Copy and paste these if needed:

**Check block height:**
```bash
zebrad tip-height --network Mainnet
```

**Check all services:**
```bash
sudo systemctl status zebrad lightwalletd caddy
```

**View logs:**
```bash
sudo journalctl -u zebrad -n 50
sudo journalctl -u lightwalletd -n 50
sudo journalctl -u caddy -n 50
```

**Restart all:**
```bash
sudo systemctl restart zebrad lightwalletd caddy
```

**Stop all:**
```bash
sudo systemctl stop zebrad lightwalletd caddy
```

**Check disk usage:**
```bash
du -sh /var/lib/zecnode/zebra/
```

---

## ✨ YOU'RE ALL SET!

Your Zcash node is now:
- ✅ Installed and configured
- ✅ Syncing the blockchain
- ✅ Set to auto-restart if needed
- ✅ Running securely with HTTPS (if you provided a domain)

**Just leave your computer on** and let it sync over the next week or so. You can check progress anytime with:

```bash
zebrad tip-height --network Mainnet
```

**That's it!** You've successfully set up a Zcash node. 🎉

---

*Last updated: October 27, 2025*

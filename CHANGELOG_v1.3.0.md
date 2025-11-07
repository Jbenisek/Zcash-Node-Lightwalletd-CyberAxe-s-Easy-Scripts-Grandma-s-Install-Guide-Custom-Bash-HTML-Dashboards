# CHANGELOG - Version 1.3.14

## Version 1.3.14 (Installation Scripts - Version Consistency)
**Release Date:** November 6, 2025  
**Updated by:** GitHub Copilot
**All Script Versions Synchronized to v1.3.14**

### Version Synchronization Fix
This release ensures all 7 installation scripts use consistent versioning for proper tracking and deployment:
- ✅ zecnode-cleanup.sh: 1.3.14
- ✅ zecnode-preflight.sh: 1.3.14
- ✅ zecnode-mount-setup.sh: 1.3.14
- ✅ zecnode-toolchain-setup.sh: 1.3.14
- ✅ zecnode-caddy-setup.sh: 1.3.14 (was 1.2.38)
- ✅ zecnode-zebra-build.sh: 1.3.14
- ✅ zecnode-lightwalletd-build.sh: 1.3.14 (was 1.2.38)

### Why This Matters
- Consistent versioning allows proper tracking of feature deployment across all scripts
- Prevents confusion when debugging or verifying installation system state
- Ensures all scripts in a deployment are from the same release
- Facilitates rollback and version history tracking

### Included in v1.3.14
This version includes all features from v1.3.13:
- ✅ Donation address collection and configuration (Scripts 5 & 7)
- ✅ Monitor launch option 'M' at installation completion (Script 7)
- ✅ HTML dashboard ASCII art enlargement

---

# CHANGELOG - Version 1.3.13

## Version 1.3.13 (Installation Scripts - Donation Address Feature)
**Release Date:** November 6, 2025  
**Updated by:** GitHub Copilot
**Script Versions:** caddy-setup.sh v1.2.38, lightwalletd-build.sh v1.2.38
**Major Feature:** Added optional Zcash Unified Address (UA) donation address collection to the installation system.

### Implementation Summary
This feature enables Zcash node operators to configure and advertise a donation address to wallet clients. The address is collected during installation (Script 5) and automatically configured in lightwalletd (Script 7).

### Changes by Script

**Script 5 (zecnode-caddy-setup.sh v1.2.38):**
- Added interactive prompt asking users for optional Zcash UA donation address (lines 82-110)
  - Displays helpful info about what the feature does
  - Allows user to skip by pressing Enter
  - Validates format: must start with 'u', max 255 characters
  - Shows truncated preview of address if provided
- Added configuration storage (lines 392-411)
  - Stores validated address in `/etc/zecnode/zecnode.conf`
  - Uses proven grep/append/sed pattern (identical to DOMAIN storage)
  - Handles both new installations and re-running existing setups
  - Gracefully clears address if user skips on re-run
  
**Script 7 (zecnode-lightwalletd-build.sh v1.2.38):**
- Added donation address configuration (lines 191-194)
  - Reads inherited `DONATION_ADDRESS` from `/etc/zecnode/zecnode.conf`
  - Automatically appends `donation-address=<address>` to `/etc/lightwalletd/zcash.conf` if configured
  - lightwalletd will advertise this address to wallet clients via GetLightdInfo gRPC call
- Added Monitor Launch Option (lines 705-706)
  - New 'M' key option in final installation prompt launches zebra-monitor.sh
  - Users can now immediately start monitoring their node after installation completes
  - Provides seamless transition from installation to monitoring workflow
  
### Benefits
- Enables node operators to monetize their infrastructure by advertising donation addresses to wallet users
- Completely optional feature - non-breaking for existing installations
- Follows established config management patterns (store in Script 5, consume in Script 7)
- Uses official lightwalletd `--donation-address` configuration option per v0.4.18 source code
- Users can immediately start monitoring their node post-installation without manual commands

### Technical Details
- **Format:** Per official lightwalletd documentation, address must be valid Zcash UA format (starts with 'u')
- **Validation:** Client-side validation in bash (regex check), server-side validation in lightwalletd
- **Advertisement:** Address is exposed as `donation_address` field in GetLightdInfo gRPC response
- **Config File:** `/etc/lightwalletd/zcash.conf` (plaintext, restricted permissions 600)
- **Verification:** Check with `sudo cat /etc/lightwalletd/zcash.conf | grep donation-address` or query via gRPC
- **Restart:** `sudo systemctl restart lightwalletd` to apply changes
- **Monitor Launch:** Press 'M' at final installation prompt to launch `sudo bash zebra-monitor.sh`

### Backward Compatibility
- ✅ Existing installations unaffected (feature is optional)
- ✅ Re-running scripts preserves configuration
- ✅ Empty address properly cleared if user skips on updates

---

## Version 1.3.13 (Zcash Node Dashboard.html)
**Release Date:** November 6, 2025  
**Updated by:** GitHub Copilot
**Visual Enhancement:** Increased ASCII art background image size from `font-size: 4px` to `16px` (4x enlargement). The background art now displays much larger and more visible while maintaining semi-transparency (opacity: 0.25) and remaining behind the text overlay. This improves visual impact of the dashboard's artistic design elements.

---

# CHANGELOG - Version 1.3.12

## Version 1.3.12 (Zcash Node Dashboard.html)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Five
**Performance Optimizations:** Reduced Matrix effect particle count from 300 to 100, trail segments from 8 to 2, and shadow blur intensity to improve FPS when Matrix is enabled. Increased data fetch interval from 5 seconds to 30 seconds and limited log display to last 50 entries to reduce DOM update overhead.

## Additional Update: Version 1.3.12 (Zcash Node Dashboard.html)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Five
**Visual Improvements:** Reduced particle speed for slower, more graceful movement. Increased trail segments back to 8 and improved trail opacity for a nicer visual effect. Fixed FPS counter to accurately reflect animation frame rate instead of timer calls.

## Animation & UI Improvements: Version 1.3.12 (Zcash Node Dashboard.html)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Five
**Changes:**
- Switched animation loop to `requestAnimationFrame` for better browser optimization.
- Added dynamic particles counter showing current visible particles.
- Reverted to `requestAnimationFrame` after `setInterval` testing.

## Additional Update: Version 1.3.12 (Zcash Node Dashboard.html)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Five
**Default Effect Change:** Changed the default Matrix effect from CLASSIC to MAGNETIC for more dynamic particle interaction.

---

# CHANGELOG - Version 1.3.11

## Latest: Version 1.3.11 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Changed folder permissions from 755 to 775. Version 1.3.10 claimed to fix permissions but only fixed file permissions (644), not folder permissions. Users could not delete files because folder lacked write permission. Now folder is 775 (rwxrwxr-x) allowing user to delete files, while files remain 644 (rw-r--r--).

## Additional Fix: Version 1.3.11 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Four
**Fix:** Fixed double-nesting bug in write_metrics_json() function. Script was changing directory to html_dashboard_public folder, causing script_dir calculation to be incorrect and placing JSON file in html_dashboard_public/html_dashboard_public/ instead of html_dashboard_public/. Added logic to detect when script_dir is wrong and correct it by going up one directory level.

## Additional Fix: Version 1.3.11 (zebra-monitor.sh) - Ownership
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Four
**Fix:** Added chown commands to give html_dashboard_public folder and HTML file ownership to actual user (not root). Script now runs as sudo but transfers ownership to $actual_user. User can now edit and update HTML dashboard file without permission errors.

---

# CHANGELOG - Version 1.3.10

## Version 1.3.10 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Set proper folder permissions (755) and ownership to actual user for html_dashboard_public directory. Simplified JSON file path construction to prevent double-subfolder nesting issue. Directory now created with correct permissions on first run so user can read, write, and delete files.

---

# CHANGELOG - Version 1.3.9

## Version 1.3.9 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Fixed X session error when opening browser from sudo context. Script now detects actual user via $SUDO_USER and runs xdg-open as that user with DISPLAY=:0, preventing "Firefox as root in regular user's session" error.

---

# CHANGELOG - Version 1.3.8

## Version 1.3.8 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Added directory creation check to write_metrics_json() function. Ensures html_dashboard_public directory exists before attempting to write JSON file, preventing "No such file or directory" errors if function called before main() creates directory.

---

# CHANGELOG - Version 1.3.7

## Version 1.3.7 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Isolated dashboard files to separate subfolder for security and cleanliness. Dashboard HTML and JSON now served from `html_dashboard_public/` subfolder only. Script creates subfolder on first run, copies HTML file, and generates JSON there. HTTP server root changed to serve only from dashboard subfolder, preventing accidental exposure of system files.

---

# CHANGELOG - Version 1.3.6

## Version 1.3.6 (zebra-monitor.sh)
**Release Date:** November 5, 2025  
**Updated by:** Copilot Twenty-Three
**Fix:** Added mandatory root permission check - zebra-monitor.sh now exits with clear error if not run with sudo. UFW commands require elevated privileges to read firewall status.

---

# CHANGELOG - Version 1.3.2

**Version:** 1.3.2  
**Release Date:** November 5, 2025  
**Previous Version:** 1.3.1  
**Updated by:** CyberAxe (www.dontpanic.biz)

---

## SUMMARY

Bug fixes for data integrity and honest reporting. Fixed empty audio source causing load errors. Fixed memory counter showing misleading `0 MB` on non-Chrome browsers - now shows `N/A` for unavailable data.

---

## MAJOR FEATURES ADDED

### 1. **HTML Dashboard Rename & Rebranding**
- **File Changed:** `matrix_installer.html` → `Zcash Node Dashboard.html`
- **Title Updated:** "Zecnode Installer" → "Zcash Node Dashboard"
- **Header Updated:** "ZECNODE INSTALLER" → "ZCASH NODE DASHBOARD"
- **Overlay Text:** Changed from installation messages to dashboard description
- **Impact:** All system references updated (bash script M-key handler, Visualization.md, code comments)

### 2. **Four Vertical Dashboard Boxes (Left Side)**
All boxes positioned with mathematically calculated equal 50px gaps between them.

#### Box 1: NETWORK (top: 65px)
- Known Peers: peer_count
- Connections/hr: connections_per_hour
- Changes/hr (avg): changes_per_hour
- CPU Usage: cpu_usage (formatted as percentage)
- RAM Usage: ram_usage (in MB)
- Disk Free: disk_free
- Block Files: block_files
- **Height:** 211px | **Styling:** Cyan border, black background

#### Box 2: SYSTEMD SERVICES (top: 326px)
- Zebra Node: [active/unknown] + Block height
- Lightwalletd: [active/unknown]
- Caddy (TLS): [active/unknown]
- Network Type: network_type
- Sync Timeout: sync_timeout
- Remaining Sync: remaining_blocks
- **Height:** 189px | **Status Colors:** Green (active), Red (inactive)
- **Styling:** Cyan border, black background

#### Box 3: NETWORK ACCESS (top: 565px)
- Domain: subdomain
- DNS IP: subdomain_ip
- Public IP: current_external_ip
- **Height:** 124px | **Styling:** Cyan border, black background

#### Box 4: NODE HEALTH (top: 739px)
- Sync Status: Shows "✓ Fully Synchronized" or "Syncing: X.X%"
- Last Block: last_block (timestamp)
- **Height:** 103px | **Status:** Green checkmark when synced
- **Styling:** Cyan border, black background

### 3. **Collapsible Recent Logs Box (Bottom-Right)**
- **Default State:** Collapsed
- **Button:** "▶ Recent Logs" (gold text on dark background)
- **Expanded State:** Shows "▼ Recent Logs", displays last 10 zebra logs from journalctl
- **Logs Source:** `journalctl -u zebrad -n 10`
- **Dimensions:** 
  - Width: `calc(100% - 500px)` for responsiveness
  - Max-width: 900px | Min-width: 400px
  - Height: 180px with auto-scroll
- **Positioning:** Fixed bottom-right (20px from bottom and right edges)
- **Toggle Animation:** Smooth CSS transitions

### 4. **Last Updated Timestamp**
- **Position:** Top-left (20px from top and left)
- **Format:** "Nov 05 03:36" (UTC)
- **Updates:** Every 5 seconds with JSON fetch
- **Default:** "No Data" when node offline

### 5. **Data Integrity & Honest Reporting**
- **New Function:** `initializeAllFields()` sets all values to `--` or "unknown" on page load
- **No Fake Data:** When JSON fails to load (node offline), ALL fields show no-data state
- **Before:** Dashboard showed fake "active" statuses with green colors (misleading)
- **After:** Shows "unknown" with red/inactive styling when node not running
- **Trust:** Every value is either real data from JSON or clearly shows "no data"

### 6. **IP Mismatch Alarm (NEW in v1.3.1)**
- **Detection:** Compares DNS IP vs Public IP in Network Access box
- **Trigger Condition:** `ip_mismatch_alarm = 1` when DNS IP ≠ Public IP
- **Visual Alert:** Red blinking border with glow effect
- **Animation:**
  - Border pulses: #FF0000 ↔ #CC0000
  - Background tints red (0.1 opacity → 0.05 opacity)
  - Glow effect: box-shadow 15px → 20px radius
  - Speed: 0.5s infinite
- **Behavior:** 
  - Normal cyan border when IPs match
  - Blinking red border when mismatch detected
  - Updates every 5 seconds
- **Use Case:** Alerts operator to network configuration issues (firewall, NAT, DNS problems)

---

## BUG FIXES (v1.3.2)

### Bug #1: Empty Audio Source Causing Load Error
- **Issue:** Empty `<source src="">` in audio element caused "Invalid URI. Load of media resource failed"
- **Symptom:** Browser console errors on page load
- **Fix:** Removed empty source tag from audio element
- **Status:** ✅ FIXED

### Bug #2: Memory Counter Showing Misleading `0 MB`
- **Issue:** Memory counter displayed `0 MB` on Firefox/Safari (unavailable data)
- **Symptom:** Looks like system using 0MB when actually data isn't available
- **Root Cause:** `performance.memory` API only available in Chrome/Chromium browsers
- **Fix:** 
  - Changed to show `N/A` when `performance.memory` is unavailable
  - Only shows actual MB value when data is truly available
  - Added comment documenting Chrome-only limitation
- **Behavior:**
  - **Chrome/Chromium:** Shows actual JS heap memory (e.g., "10 MB")
  - **Firefox/Safari/Other:** Shows "N/A" (honest about unavailability)
- **Status:** ✅ FIXED

---

## FILES MODIFIED

### zebra-monitor.sh (v1.2.37 → v1.3.5)
**Changes (v1.3.4 → v1.3.5):**
1. Fixed HTTP server network binding for LAN accessibility
   - Changed from default localhost-only binding to `--bind 0.0.0.0`
   - HTTP server now accessible from any computer on LAN at `http://192.168.1.230:4242`
   - Updated startup message to indicate LAN accessibility

**Changes (v1.3.3 → v1.3.4):**
1. Corrected UFW firewall port 4242 configuration
   - Removed `sudo` prefix from `ufw allow 4242/tcp` command (script already runs with sudo)
   - Eliminates password prompt halt during dashboard startup
   - Port opens automatically when script launched with `sudo bash ./zebra-monitor.sh`
   - Grandma no longer needs to run manual commands or re-enter password
2. Code cleanup
   - Removed unused `get_external_ip()` function (dead code)
   - Removed unused variable `local external_ip=$(get_external_ip)` from main loop
   - Simplified UFW check logic

**Changes (v1.3.2 → v1.3.3):**
1. Enhanced UFW firewall rule configuration for LAN dashboard access
   - Added UFW status detection before attempting rule addition
   - Port 4242/tcp now automatically opened for HTTP server (dashboard access)
   - Verifies rule was added successfully before reporting completion
   - Script continues to gather metrics regardless of firewall status
2. HTTP server auto-start on dashboard launch
   - Python3 HTTP server started on port 4242 at script initialization
   - Server runs in background and persists for duration of monitoring session
   - Cleanup function properly terminates server on script exit

**Previous Changes (v1.2.37 → v1.3.2):**
1. Updated M-key handler URL: `matrix_installer.html` → `Zcash Node Dashboard.html`
2. Enhanced `write_metrics_json()` function:
   - Added `recent_logs` array: Last 10 lines from `journalctl -u zebrad -n 10`
   - Renamed JSON field: `memory_usage` → `ram_usage`
   - Renamed JSON field: `file_count` → `block_files`
   - Kept: `cpu_usage`, `disk_free` (already correct)
   - All 21+ metrics now properly mapped

### Zcash Node Dashboard.html (NEW - renamed from matrix_installer.html)
**Changes:**
1. **CSS Updates:**
   - Network box: max-width 400px
   - Systemd box: max-width 450px
   - Network Access box: max-width 400px
   - Node Health box: max-width 350px
   - Live Logs box: `calc(100% - 500px)` responsive width with 50px gap calculation
   - Logs toggle button: Fixed positioning, gold text, hover effects
   - Logs container: Hidden by default (collapsed state)
   - `.collapsed` class: `display: none`

2. **HTML Updates:**
   - Removed hardcoded "NETWORK DATA" header
   - 7 metric fields per Network box with value spans
   - Added status color classes for active/inactive
   - Replaced logs header with toggle button
   - Added logContainer div with collapsed class

3. **JavaScript Updates:**
   - **New:** `initializeAllFields()` function
     - Sets all 20+ data fields to `--` or "unknown"
     - Clears logs to "No logs available" message
     - Called on page load and fetch error
   - **New:** Logs toggle click handler
     - Toggles `.collapsed` class on logContainer
     - Updates button text: "▶" ↔ "▼"
     - Smooth transitions
   - **Updated:** `fetchAndUpdateMetrics()` function
     - Calls `initializeAllFields()` on fetch error (honest reporting)
     - Populates 6 new system metric fields (CPU, RAM, Disk, Block Files)
     - Formats CPU as percentage to 1 decimal place
     - Status color assignment based on actual "active" value

### Visualization.md
**Changes:**
- Updated all references: `matrix_installer.html` → `Zcash Node Dashboard.html`
- Updated data flow diagram titles
- Updated access URL in documentation

---

## TECHNICAL DETAILS

### Box Positioning Math (Calculated from CSS)
All positions calculated with pixel-perfect accuracy:

```
Network Data Box:
  padding: 30px + border: 4px + header: 25.6px + 7 rows (151.2px) = 210.8px ≈ 211px
  top: 65px | bottom: 276px

Systemd Services Box:
  padding: 30px + border: 4px + header: 25.6px + 6 rows (129.6px) = 189.2px ≈ 189px
  top: 326px | gap: 50px from Network | bottom: 515px

Network Access Box:
  padding: 30px + border: 4px + header: 25.6px + 3 rows (64.8px) = 124.4px ≈ 124px
  top: 565px | gap: 50px from Systemd | bottom: 689px

Node Health Box:
  padding: 30px + border: 4px + header: 25.6px + 2 rows (43.2px) = 102.8px ≈ 103px
  top: 739px | gap: 50px from Network Access

All gaps: Exactly 50px between box bottoms
```

### JSON Data Structure (v1.3.0)
```json
{
  "timestamp": "2025-11-05T03:36:00Z",
  "current_height": "3123918",
  "sync_percent": "100.0",
  "peer_count": "64",
  "connections_per_hour": "42",
  "cpu_usage": "38.2",
  "ram_usage": "3368",
  "disk_free": "580G",
  "block_files": "14",
  "remaining_blocks": "0",
  "zebra_status": "active",
  "lightwalletd_status": "active",
  "caddy_status": "active",
  "subdomain": "zcash.dontpanic.biz",
  "subdomain_ip": "174.45.174.149",
  "current_external_ip": "174.45.174.149",
  "ip_mismatch_alarm": 0,
  "last_block": "2025-11-05T03:36:10Z",
  "time_remaining": "0s",
  "network_type": "Main",
  "sync_timeout": "67s",
  "changes_per_hour": "1",
  "is_synced": "1",
  "recent_logs": [
    "22:32: {zebrad} sync::progress: finished initial sync...",
    "22:32: {zebrad} sync::gossip: height=Height(3123918)...",
    ...last 10 logs...
  ]
}
```

### Responsive Design
- **Live Logs Width:** `calc(100% - 500px)` reserves 500px for left column
- **Max Width:** 900px prevents excessive width on ultra-wide screens
- **Min Width:** 400px ensures usability on smaller screens
- **Dynamic:** Adapts automatically to different screen sizes

---

## DATA INTEGRITY IMPROVEMENTS

### Before (v1.2.37)
- Dashboard showed fake "active" statuses even with no JSON
- Green "active" indicators on Windows systems (misleading)
- No distinction between "no data" and "data unavailable"
- Hard to trust what you're seeing

### After (v1.3.0)
- All fields initialize to `--` or "unknown" on page load
- JSON fetch failure triggers `initializeAllFields()`
- Status shows "unknown" in red/inactive color when offline
- "No Data Available" messaging is clear and honest
- Only shows "active" when JSON contains actual "active" value
- Logs show "No logs available - Node not running or unreachable"

---

## TESTING NOTES

**Tested On:**
- Linux Mint 22.2 with fully synchronized Zcash node
- Windows system without any services (to verify honest data reporting)
- Various screen resolutions (responsiveness verification)

**Verification:**
- ✅ All left boxes have equal 50px gaps
- ✅ Logs collapsible and toggle works smoothly
- ✅ Dashboard shows real data on node system
- ✅ Dashboard shows "no data" on non-node system
- ✅ JSON updates every 30 seconds from bash script
- ✅ HTML fetches and displays every 5 seconds
- ✅ Button colors and styling consistent across boxes
- ✅ Responsive layout works on different screen sizes

---

## BREAKING CHANGES

None - This is a pure enhancement with no functionality removal.

---

## FUTURE ROADMAP

Possible enhancements for v1.4.0:
- Real-time block chart/graph
- Network peer map visualization
- Transaction mempool depth chart
- Historical sync speed trends
- Custom refresh rate settings
- Dark/Light theme toggle
- Mobile responsive optimization

---

## VERSION HISTORY

- **v1.3.2** (Nov 5, 2025) - Fixed empty audio source error, fixed memory counter misleading 0MB display
- **v1.3.1** (Nov 4, 2025) - IP mismatch alarm with blinking red border animation
- **v1.3.0** (Nov 4, 2025) - Dashboard redesign, responsive layout, data integrity
- **v1.2.37** (Oct 28, 2025) - Network type extraction, changes per hour metric
- **v1.2.35** (Oct 28, 2025) - Removed backup/restore features
- ...earlier versions in ~archive/CODE_FIXES.md

---

## NOTES

This version represents a significant UI/UX improvement with a focus on:
1. **Professional appearance** - Clean, organized dashboard
2. **Accurate data reporting** - No fake data, honest "N/A" for unavailable metrics
3. **Responsive design** - Works across different screen sizes
4. **User-friendly collapsibles** - Logs hidden by default, expanded on demand
5. **Pixel-perfect alignment** - Mathematical calculations ensure equal spacing
6. **Network alerts** - IP mismatch detection with visual alarms
7. **Data integrity** - No misleading values (0 MB, fake "active" statuses, etc.)

All changes follow the project's commitment to honest, transparent reporting and no-assumptions design.

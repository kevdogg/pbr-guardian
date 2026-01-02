# Proxmox PBR Guardian

A self-healing Policy-Based Routing (PBR) manager for multi-homed Proxmox LXC containers and VMs. This tool ensures that traffic entering the system on a specific interface always leaves through that same interface (preventing asymmetric routing) and protects local loopback services (like Technitium DNS).

## 🚀 Quick Install

Run this command inside any Debian/Ubuntu-based LXC or VM:

```bash
curl -sSL [https://raw.githubusercontent.com/kevdogg/proxmox-pbr-guardian/main/install.sh](https://raw.githubusercontent.com/YOUR_USER/proxmox-pbr-guardian/main/install.sh) | bash

✨ Key Features

    Universal Detection: Automatically identifies eth*, net*, ens*, and even tagged interfaces like eth1.40.

    Active Sentry: A background service scans the kernel every 10 seconds. If a rule is deleted or a "forbidden" rule appears, it automatically repairs the state.

    Aggressive Cleanup: Automatically purges legacy rules (like the Proxmox 200-series defaults) that cause routing loops.

    Technitium Friendly: Forces loopback traffic (priority 2000) to bypass PBR, ensuring local DNS services don't break.

    Persistent Tables: Automatically registers and maintains custom routing tables in /etc/iproute2/rt_tables.d/.

🏗️ The Routing Logic (Priority Map)

The Guardian organizes the Linux IP Rules in the following hierarchy:
Priority	Purpose	Table
0	Critical Kernel Defaults	local
2000	Loopback Bypass (DNS/Localhost)	local
1 - 29999	Forbidden Zone (Legacy Rules)	Purged by Sentry
30000+	Interface-Specific Source Rules	vlan[ID]
32000+	Interface-Specific Input Rules	vlan[ID]
32766	System Main Routing Table	main
32767	Default Catch-all	default
🛠️ Maintenance & Debugging

The Guardian runs as a systemd service. You can monitor its actions in real-time:
View Live Logs
Bash

journalctl -u pbr-routes.service -f

Force a Configuration Re-sync
Bash

systemctl restart pbr-routes.service

Check Current Rules
Bash

ip rule show
ip route show table vlan0  # Replace 0 with your interface ID

📝 Configuration Details

    Table Naming: Dots in interface names (e.g., eth1.40) are sanitized to underscores (vlaneth1_40).

    Priority Logic: Table priorities are calculated as 30000 + (Interface_ID % 2000) to prevent collisions with system-reserved tables.

Created to solve asymmetric routing in Proxmox multi-homed environments.

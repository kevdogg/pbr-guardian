# Proxmox PBR Guardian

A self-healing Policy-Based Routing (PBR) manager for multi-homed Proxmox LXC containers and VMs.

## Quick Install

Run this command inside any Debian/Ubuntu-based LXC or VM:

```bash curl -sSL https://raw.githubusercontent.com/kevdog/proxmox-pbr-guardian/main/install.sh | bash ```

## The Routing Logic

| Priority | Purpose | Table | | :--- | :--- | :--- | | 0 | Critical Kernel Defaults | local | | 2000 | Loopback Bypass | local | | 30000+ | Source Rules | vlan[ID] |

Created to solve asymmetric routing in Proxmox.

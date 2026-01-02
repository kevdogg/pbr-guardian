# Proxmox PBR Guardian

A self-healing **Policy-Based Routing (PBR)** manager for multi-homed Proxmox LXC containers and VMs.

---

## 🚀 Quick Install

Run this command inside any Debian/Ubuntu-based LXC or VM:

```bash
curl -sSL [https://raw.githubusercontent.com/kevdog/proxmox-pbr-guardian/main/install.sh](https://raw.githubusercontent.com/kevdog/proxmox-pbr-guardian/main/install.sh) | bash
```

## ✨ Key Features

* **Universal Detection**: Automatically identifies eth, net, ens, and tagged interfaces.
* **Active Sentry**: Repairs the routing state every 10 seconds.

## 🏗️ The Routing Logic

| Priority | Purpose | Table |
| :--- | :--- | :--- |
| 0 | Kernel Defaults | local |
| 2000 | Loopback Bypass | local |
| 30000+ | Source Rules | vlan[ID] |

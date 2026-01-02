# Changelog

All notable changes to the Proxmox PBR Guardian will be documented in this file.

## [1.1.1] - 2026-01-01

### Added
- **Dynamic Gateway Detection**: Replaced hardcoded `.1` gateway logic with active route lookups. The script now identifies the actual gateway assigned to each interface.
- **Service Robustness**: Added `Wants=network-online.target` to the systemd unit to ensure the guardian waits for the network stack to be fully initialized during boot.
- **Safety Checks**: Added conditional logic to prevent route application if an interface has an IP but no detectable network or gateway.

### Changed
- **Restart Policy**: Updated systemd `RestartSec` to 5 seconds to prevent rapid-fire restart loops during heavy network reconfiguration.

## [1.1.0] - 2025-12-31

### Added
- **Loopback Bypass**: Implemented priority 2000 rules to ensure local traffic (e.g., Technitium DNS) bypasses PBR tables.
- **Aggressive Cleanup**: Added logic to purge "forbidden" rules (priority < 30000) that cause routing loops in multi-homed Proxmox setups.
- **Universal Interface Handling**: Support for `eth`, `ens`, `enp`, and dot-notated VLAN tags (e.g., `eth1.40`).

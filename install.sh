#!/bin/bash
# ==============================================================================
# MASTER INSTALLER: V11.1 (UNIVERSAL / DYNAMIC GATEWAY / SELF-HEALING)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "Must be root"; exit 1; fi

WORKER_PATH="/usr/local/bin/add_pbr_routes.sh"
SERVICE_PATH="/etc/systemd/system/pbr-routes.service"

echo "[1/3] Generating Universal Worker Script..."

cat > "$WORKER_PATH" << 'EOF_WORKER'
#!/bin/bash

apply_pbr() {
    echo "$(date): PBR Guardian v1.1.1 starting maintenance..."
    
    # 1. Loopback Bypass (Priority 2000)
    # Ensures local services like Technitium DNS don't get trapped in PBR tables
    ip rule add pref 2000 iif lo lookup local 2>/dev/null

    # 2. AGGRESSIVE CLEANUP
    # Purge any PBR rules sitting in the forbidden priority range (< 30000)
    BAD_PRIOS=$(ip rule show | grep -E 'lookup vlan' | cut -d':' -f1)
    for PRIO in $BAD_PRIOS; do
        if [ "$PRIO" -lt 30000 ] && [ "$PRIO" -ne 0 ]; then
            echo "$(date): Purging legacy rule at priority $PRIO"
            while ip rule del pref "$PRIO" 2>/dev/null; do :; done
        fi
    done

    # 3. UNIVERSAL INTERFACE PROCESSING
    for IF_PATH in /sys/class/net/*; do
        IFACE="${IF_PATH##*/}"
        
        # Skip loopback and virtual stack interfaces
        [[ "$IFACE" == "lo" || "$IFACE" == veth* || "$IFACE" == br* || "$IFACE" == docker* ]] && continue
        [ ! -d "$IF_PATH/device" ] && [ ! -d "$IF_PATH/subsystem" ] && continue

        # Extract IP
        _IP=$(ip -4 addr show dev "$IFACE" | sed -n 's/.*inet \([0-9.]*\).*/\1/p' | head -n 1)
        [ -z "$_IP" ] && continue

        # GENERATE STABLE TABLE NAME & ID
        SAFE_NAME=$(echo "$IFACE" | sed 's/\./_/g')
        TNAME="vlan${SAFE_NAME}"
        
        ID_NUM=$(echo "$IFACE" | tr -dc '0-9')
        if [ -z "$ID_NUM" ]; then
            ID=$(echo "$_IP" | cut -d. -f4)
        else
            ID="$ID_NUM"
        fi
        
        TPRIO=$((30000 + (ID % 2000)))
        
        # Register Table if missing
        mkdir -p /etc/iproute2/rt_tables.d
        if ! grep -q "$TNAME" /etc/iproute2/rt_tables.d/custom_pbr.conf 2>/dev/null; then
            echo "$(date): Registering table $TNAME with priority $TPRIO"
            echo "$TPRIO $TNAME" >> /etc/iproute2/rt_tables.d/custom_pbr.conf
        fi

        # DYNAMIC GATEWAY DETECTION (V11.1 Improvement)
        # Pulls the actual gateway assigned to this interface instead of assuming .1
        _GW=$(ip route show dev "$IFACE" | grep default | awk '{print $3}')
        [ -z "$_GW" ] && _GW=$(echo "$_IP" | cut -d. -f1-3).1
        
        _NET=$(ip -4 route show dev "$IFACE" proto kernel | grep -v "default" | head -n 1 | cut -d' ' -f1)

        # Apply Routes/Rules
        if [ -n "$_NET" ] && [ -n "$_GW" ]; then
            ip route replace "$_NET" dev "$IFACE" proto kernel scope link src "$_IP" table "$TNAME"
            ip route replace default via "$_GW" dev "$IFACE" onlink table "$TNAME"
            ip rule add from "$_IP" pref "$TPRIO" table "$TNAME" 2>/dev/null
            ip rule add iif "$IFACE" pref $((TPRIO + 2000)) table "$TNAME" 2>/dev/null
        fi
    done
    ip route flush cache
    echo "$(date): PBR state synchronized."
}

# Main Loop: Check for drift every 10 seconds
apply_pbr
while true; do
    _DRIFT=0
    if ! ip rule show | grep -q "2000:"; then _DRIFT=1; fi
    
    FORBIDDEN=$(ip rule show | grep -E 'lookup vlan' | sed -n 's/^[ ]*\([0-9]\{1,5\}\):.*/\1/p')
    for P in $FORBIDDEN; do
        if [ "$P" -gt 0 ] && [ "$P" -lt 30000 ]; then _DRIFT=1; break; fi
    done

    [ "$_DRIFT" -eq 1 ] && apply_pbr
    sleep 10
done
EOF_WORKER

chmod +x "$WORKER_PATH"

echo "[2/3] Writing Systemd Service..."
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Universal PBR Guardian
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$WORKER_PATH
Restart=always
RestartSec=5
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[3/3] Reloading and FORCING Restart..."
systemctl daemon-reload
systemctl enable pbr-routes.service
systemctl restart pbr-routes.service

echo "-------------------------------------------------------"
echo "INSTALL COMPLETE. Universal Guardian v1.1.1 is Active."
echo "Monitoring: eth*, net*, ens*, enp*, and tagged interfaces."
echo "-------------------------------------------------------"

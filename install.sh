#!/bin/bash
# ==============================================================================
# MASTER INSTALLER: V11 (UNIVERSAL / DOT-SAFE / SELF-HEALING)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "Must be root"; exit 1; fi

WORKER_PATH="/usr/local/bin/add_pbr_routes.sh"
SERVICE_PATH="/etc/systemd/system/pbr-routes.service"

echo "[1/3] Generating Universal Worker Script..."

cat > "$WORKER_PATH" << 'EOF_WORKER'
#!/bin/bash

apply_pbr() {
    # Add this near the top of the 'apply_pbr' function in your install.sh
    echo "$(date): PBR Guardian v1.1.0 (GitHub Main) starting up..."
    echo "$(date): Maintenance triggered - checking PBR state..."
    
    # 1. Loopback Bypass (Priority 2000)
    ip rule add pref 2000 iif lo lookup local 2>/dev/null

    # 2. AGGRESSIVE CLEANUP
    # Find any rule pointing to a table starting with 'vlan' with priority < 30000
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
        # Replace dots with underscores for valid table naming (eth1.40 -> vlaneth1_40)
        SAFE_NAME=$(echo "$IFACE" | sed 's/\./_/g')
        TNAME="vlan${SAFE_NAME}"
        
        # Extract all numbers from interface name (eth1.40 -> 140)
        # If no numbers, use the last octet of the IP
        ID_NUM=$(echo "$IFACE" | tr -dc '0-9')
        if [ -z "$ID_NUM" ]; then
            ID=$(echo "$_IP" | cut -d. -f4)
        else
            ID="$ID_NUM"
        fi
        
        # Keep ID in a safe range for priority 30000+
        TPRIO=$((30000 + (ID % 2000)))
        
        mkdir -p /etc/iproute2/rt_tables.d
        if ! grep -q "$TNAME" /etc/iproute2/rt_tables.d/custom_pbr.conf 2>/dev/null; then
            echo "$(date): Registering table $TNAME with priority $TPRIO"
            echo "$TPRIO $TNAME" >> /etc/iproute2/rt_tables.d/custom_pbr.conf
        fi

        _GW=$(echo "$_IP" | cut -d. -f1-3).1
        _NET=$(ip -4 route show dev "$IFACE" proto kernel | grep -v "default" | head -n 1 | cut -d' ' -f1)

        # Apply Routes/Rules
        ip route replace "$_NET" dev "$IFACE" proto kernel scope link src "$_IP" table "$TNAME"
        ip route replace default via "$_GW" dev "$IFACE" onlink table "$TNAME"
        ip rule add from "$_IP" pref "$TPRIO" table "$TNAME" 2>/dev/null
        ip rule add iif "$IFACE" pref $((TPRIO + 2000)) table "$TNAME" 2>/dev/null
    done
    ip route flush cache
    echo "$(date): PBR state synchronized."
}

apply_pbr
while true; do
    _DRIFT=0
    # Condition A: Essential rules are missing
    if ! ip rule show | grep -q "2000:"; then _DRIFT=1; fi
    
    # Condition B: Forbidden rules found (< 30000)
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

[Service]
Type=simple
ExecStart=$WORKER_PATH
Restart=always
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[3/3] Reloading and FORCING Restart..."
systemctl daemon-reload
systemctl enable pbr-routes.service
systemctl restart pbr-routes.service

echo "-------------------------------------------------------"
echo "INSTALL COMPLETE. Universal Guardian is Active."
echo "Handles: eth*, net*, ens*, enp*, and tagged eth1.40"
echo "-------------------------------------------------------"

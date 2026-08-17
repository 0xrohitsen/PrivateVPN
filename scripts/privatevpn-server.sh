#!/bin/bash
# =============================================================================
#  PrivateVPN — One-Click Interactive WireGuard Server Manager
#  Compatible: Ubuntu 20.04 / 22.04 / 24.04 / 26.04 & Debian 11 / 12
#  Usage: bash privatevpn-server.sh
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/wg0.conf"
CLIENTS_DIR="${WG_DIR}/clients"
SERVER_WG_IP="10.8.0.1"
WG_PORT="51820"
WG_SUBNET="10.8.0.0/24"
DNS_SERVER="1.1.1.1"

# Ensure running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] This script must be run as root (sudo bash $0)${NC}"
    exit 1
fi

get_public_ip() {
    curl -s4 https://ifconfig.me || curl -s4 https://api.ipify.org || ip route get 1.1.1.1 | awk '{print $7}' | head -1
}

get_net_iface() {
    ip route | grep default | awk '{print $5}' | head -1
}

header() {
    clear
    echo -e "${BOLD}${CYAN}=====================================================${NC}"
    echo -e "${BOLD}${CYAN}          PrivateVPN — Server Manager                ${NC}"
    echo -e "${BOLD}${CYAN}=====================================================${NC}"
    echo ""
}

is_installed() {
    [ -f "$WG_CONF" ] && command -v wg >/dev/null 2>&1
}

install_wireguard() {
    header
    echo -e "${BOLD}${YELLOW}>>> Installing and Configuring WireGuard Server...${NC}\n"

    SERVER_PUB_IP=$(get_public_ip)
    NET_IFACE=$(get_net_iface)

    if [ -z "$NET_IFACE" ]; then
        echo -e "${RED}[ERROR] Could not detect default network interface.${NC}"
        exit 1
    fi

    echo -e "${GREEN}[1/5] Updating package repositories...${NC}"
    apt-get update -qq

    echo -e "${GREEN}[2/5] Installing WireGuard, iptables, qrencode...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq wireguard wireguard-tools iptables qrencode curl

    echo -e "${GREEN}[3/5] Enabling IPv4 forwarding...${NC}"
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf >/dev/null 2>&1

    echo -e "${GREEN}[4/5] Generating Server Keys & Configuration...${NC}"
    mkdir -p "$WG_DIR" "$CLIENTS_DIR"
    chmod 700 "$WG_DIR"

    SERVER_PRIV_KEY=$(wg genkey)
    SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)
    echo "$SERVER_PRIV_KEY" > "${WG_DIR}/server_private.key"
    echo "$SERVER_PUB_KEY" > "${WG_DIR}/server_public.key"

    cat > "$WG_CONF" << EOF
[Interface]
PrivateKey = ${SERVER_PRIV_KEY}
Address = ${SERVER_WG_IP}/24
ListenPort = ${WG_PORT}
PostUp   = iptables -F FORWARD; iptables -P FORWARD ACCEPT; iptables -A FORWARD -i wg0 -o ${NET_IFACE} -j ACCEPT; iptables -A FORWARD -i ${NET_IFACE} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -F POSTROUTING; iptables -t nat -A POSTROUTING -s ${WG_SUBNET} -o ${NET_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o ${NET_IFACE} -j ACCEPT 2>/dev/null; iptables -D FORWARD -i ${NET_IFACE} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; iptables -t nat -D POSTROUTING -s ${WG_SUBNET} -o ${NET_IFACE} -j MASQUERADE 2>/dev/null

EOF

    chmod 600 "$WG_CONF"

    # Configure UFW if active
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow ${WG_PORT}/udp >/dev/null 2>&1
        sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
        ufw --force reload >/dev/null 2>&1
    fi

    echo -e "${GREEN}[5/5] Starting WireGuard Service...${NC}"
    systemctl enable wg-quick@wg0 >/dev/null 2>&1
    systemctl restart wg-quick@wg0

    echo -e "\n${BOLD}${GREEN}✔ WireGuard Server installed and running successfully!${NC}\n"
    
    # Automatically create the first client
    add_client "Device1"
}

get_next_ip() {
    local max_octet=1
    if [ -f "$WG_CONF" ]; then
        for ip in $(grep -oE '10\.8\.0\.[0-9]+' "$WG_CONF" | grep -v '10.8.0.1' | grep -v '10.8.0.0' || true); do
            local octet=$(echo "$ip" | awk -F. '{print $4}')
            if [ "$octet" -gt "$max_octet" ]; then
                max_octet=$octet
            fi
        done
    fi
    echo "10.8.0.$((max_octet + 1))"
}

add_client() {
    local client_name="$1"
    if [ -z "$client_name" ]; then
        header
        echo -e "${BOLD}${CYAN}>>> Add New Android Client Device${NC}\n"
        read -p "Enter device name (e.g. Pixel8, Tablet, Phone2): " client_name
        client_name=$(echo "$client_name" | tr -cd '[:alnum:]_-')
        if [ -z "$client_name" ]; then
            echo -e "${RED}[ERROR] Invalid device name.${NC}"
            read -p "Press Enter to return to menu..."
            return
        fi
    fi

    local client_file="${CLIENTS_DIR}/${client_name}.conf"
    if [ -f "$client_file" ]; then
        echo -e "${RED}[ERROR] Device '$client_name' already exists!${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi

    SERVER_PUB_IP=$(get_public_ip)
    SERVER_PUB_KEY=$(cat "${WG_DIR}/server_public.key" 2>/dev/null || grep PrivateKey "$WG_CONF" | awk '{print $3}' | wg pubkey)
    CLIENT_IP=$(get_next_ip)
    CLIENT_PRIV_KEY=$(wg genkey)
    CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

    # Append peer to wg0.conf
    cat >> "$WG_CONF" << EOF

# Device: ${client_name}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

    # Add peer to running WireGuard interface live
    wg set wg0 peer "$CLIENT_PUB_KEY" allowed-ips "${CLIENT_IP}/32"

    # Create client .conf file
    cat > "$client_file" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_IP}/32
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = ${SERVER_PUB_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    chmod 600 "$client_file"

    header
    echo -e "${BOLD}${GREEN}✔ Device '${client_name}' Created Successfully!${NC}\n"
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${PURPLE}  📱 PRIVATEVPN ANDROID APP CREDENTIALS             ${NC}"
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Server Endpoint:${NC}    ${CYAN}${SERVER_PUB_IP}:${WG_PORT}${NC}"
    echo -e "  ${BOLD}Server Public Key:${NC}  ${CYAN}${SERVER_PUB_KEY}${NC}"
    echo -e "  ${BOLD}Client Address:${NC}     ${GREEN}${CLIENT_IP}/32${NC}"
    echo -e "  ${BOLD}Client Private Key:${NC} ${GREEN}${CLIENT_PRIV_KEY}${NC}"
    echo -e "  ${BOLD}DNS:${NC}                ${CYAN}${DNS_SERVER}${NC}"
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo -e "${BOLD}${CYAN}📄 WireGuard .conf Config (Copy/Paste into Import):${NC}"
    echo -e "${YELLOW}-----------------------------------------------------${NC}"
    cat "$client_file"
    echo -e "${YELLOW}-----------------------------------------------------${NC}\n"

    if command -v qrencode >/dev/null 2>&1; then
        echo -e "${BOLD}${CYAN}📷 Scan QR Code with WireGuard App (Optional):${NC}"
        qrencode -t ansiutf8 < "$client_file"
    fi

    echo -e "\n${GREEN}Saved config file:${NC} ${client_file}"
    echo ""
    read -p "Press Enter to return to menu..."
}

list_clients() {
    header
    echo -e "${BOLD}${CYAN}>>> Active WireGuard Devices & Statistics${NC}\n"

    if [ ! -f "$WG_CONF" ]; then
        echo -e "${RED}WireGuard is not configured.${NC}"
    else
        echo -e "${BOLD}${PURPLE}--- Server Interface Status ---${NC}"
        wg show wg0
        echo ""
        echo -e "${BOLD}${PURPLE}--- Configured Client Profiles ---${NC}"
        if [ -d "$CLIENTS_DIR" ] && [ "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]; then
            for f in "$CLIENTS_DIR"/*.conf; do
                local name=$(basename "$f" .conf)
                local ip=$(grep Address "$f" | awk '{print $3}')
                echo -e " • ${BOLD}${name}${NC} → IP: ${GREEN}${ip}${NC} (File: $f)"
            done
        else
            echo "No client profiles saved in ${CLIENTS_DIR}"
        fi
    fi
    echo ""
    read -p "Press Enter to return to menu..."
}

remove_client() {
    header
    echo -e "${BOLD}${RED}>>> Remove / Revoke Device Client${NC}\n"

    if [ ! -d "$CLIENTS_DIR" ] || [ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No client profiles found to remove.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi

    echo "Available clients to remove:"
    local i=1
    declare -A client_map
    for f in "$CLIENTS_DIR"/*.conf; do
        local name=$(basename "$f" .conf)
        local ip=$(grep Address "$f" | awk '{print $3}')
        echo -e "  [$i] ${BOLD}${name}${NC} (${ip})"
        client_map[$i]="$name"
        i=$((i + 1))
    done

    echo ""
    read -p "Select client number to remove (1-$((i-1))) [or 0 to cancel]: " choice
    if [ "$choice" = "0" ] || [ -z "${client_map[$choice]}" ]; then
        echo "Cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    local target_name="${client_map[$choice]}"
    local target_file="${CLIENTS_DIR}/${target_name}.conf"
    local client_pub=$(grep PublicKey "$target_file" 2>/dev/null || true) # wait, peer pub key in client file is server pub key

    # Get client public key by calculating from client private key
    local client_priv=$(grep PrivateKey "$target_file" | awk '{print $3}')
    local client_pubkey=$(echo "$client_priv" | wg pubkey)

    # Remove peer from live interface
    wg set wg0 peer "$client_pubkey" remove 2>/dev/null || true

    # Remove peer section from wg0.conf
    python3 - << PYEOF
import re

conf_path = "${WG_CONF}"
with open(conf_path, 'r') as f:
    content = f.read()

# Pattern to remove Device section
pattern = r'\n*# Device: ${target_name}\n\[Peer\]\nPublicKey = [^\n]+\nAllowedIPs = [^\n]+'
new_content = re.sub(pattern, '', content)

with open(conf_path, 'w') as f:
    f.write(new_content.strip() + '\n')
PYEOF

    # Remove client config file
    rm -f "$target_file"

    echo -e "\n${BOLD}${GREEN}✔ Device '${target_name}' revoked and removed successfully!${NC}\n"
    read -p "Press Enter to return to menu..."
}

show_client_details() {
    header
    echo -e "${BOLD}${CYAN}>>> View Device Configuration & QR Code${NC}\n"

    if [ ! -d "$CLIENTS_DIR" ] || [ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No client profiles found.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi

    echo "Select client to view:"
    local i=1
    declare -A client_map
    for f in "$CLIENTS_DIR"/*.conf; do
        local name=$(basename "$f" .conf)
        local ip=$(grep Address "$f" | awk '{print $3}')
        echo -e "  [$i] ${BOLD}${name}${NC} (${ip})"
        client_map[$i]="$name"
        i=$((i + 1))
    done

    echo ""
    read -p "Select number (1-$((i-1))): " choice
    if [ -z "${client_map[$choice]}" ]; then
        echo "Invalid selection."
        read -p "Press Enter to return to menu..."
        return
    fi

    local target_name="${client_map[$choice]}"
    local target_file="${CLIENTS_DIR}/${target_name}.conf"

    header
    echo -e "${BOLD}${CYAN}📱 Configuration for ${target_name}:${NC}\n"
    cat "$target_file"
    echo ""

    if command -v qrencode >/dev/null 2>&1; then
        echo -e "${BOLD}${CYAN}📷 QR Code:${NC}"
        qrencode -t ansiutf8 < "$target_file"
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

restart_wireguard() {
    header
    echo -e "${BOLD}${YELLOW}>>> Restarting WireGuard Server...${NC}\n"
    systemctl restart wg-quick@wg0
    echo -e "${GREEN}✔ WireGuard server restarted successfully!${NC}\n"
    read -p "Press Enter to return to menu..."
}

uninstall_wireguard() {
    header
    echo -e "${BOLD}${RED}=====================================================${NC}"
    echo -e "${BOLD}${RED}        WARNING: UNINSTALL WIREGUARD SERVER          ${NC}"
    echo -e "${BOLD}${RED}=====================================================${NC}\n"
    echo -e "This will remove WireGuard, configuration files, and client keys.\n"
    read -p "Are you sure you want to completely uninstall? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Uninstall cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    echo -e "\n${YELLOW}Stopping WireGuard service...${NC}"
    systemctl stop wg-quick@wg0 2>/dev/null || true
    systemctl disable wg-quick@wg0 2>/dev/null || true

    echo -e "${YELLOW}Removing packages...${NC}"
    apt-get remove --purge -y wireguard wireguard-tools 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true

    echo -e "${YELLOW}Cleaning configuration files...${NC}"
    rm -rf /etc/wireguard /etc/sysctl.d/99-wireguard.conf

    echo -e "\n${BOLD}${GREEN}✔ WireGuard server has been completely uninstalled.${NC}\n"
    exit 0
}

# ----------------- MAIN MENU -----------------
main_menu() {
    while true; do
        header
        if ! is_installed; then
            echo -e "${YELLOW}WireGuard is not installed on this system.${NC}\n"
            echo -e "  ${BOLD}1)${NC} ${GREEN}Install & Setup WireGuard Server (1-Click)${NC}"
            echo -e "  ${BOLD}2)${NC} Exit"
            echo ""
            read -p "Choose option [1-2]: " opt
            case $opt in
                1) install_wireguard ;;
                2) exit 0 ;;
                *) echo "Invalid option." ;;
            esac
        else
            SERVER_PUB_IP=$(get_public_ip)
            ACTIVE_PEERS=$(wg show wg0 peers 2>/dev/null | wc -l || echo "0")
            echo -e "${BOLD}Server IP:${NC} ${CYAN}${SERVER_PUB_IP}${NC} | ${BOLD}Port:${NC} ${CYAN}${WG_PORT}${NC} | ${BOLD}Status:${NC} ${GREEN}ACTIVE${NC}"
            echo -e "${BOLD}Configured Peers:${NC} ${PURPLE}${ACTIVE_PEERS}${NC}"
            echo -e "${YELLOW}-----------------------------------------------------${NC}"
            echo -e "  ${BOLD}1)${NC} ${GREEN}➕ Add / Generate New Device Client${NC}"
            echo -e "  ${BOLD}2)${NC} ${CYAN}📊 List Connected Devices & Live Traffic Stats${NC}"
            echo -e "  ${BOLD}3)${NC} ${YELLOW}🔍 View Device Config & QR Code${NC}"
            echo -e "  ${BOLD}4)${NC} ${RED}🗑️  Remove / Revoke Device Client${NC}"
            echo -e "  ${BOLD}5)${NC} 🔄 Restart WireGuard Server"
            echo -e "  ${BOLD}6)${NC} ⚠️  Uninstall WireGuard Server"
            echo -e "  ${BOLD}7)${NC} 🚪 Exit"
            echo -e "${YELLOW}-----------------------------------------------------${NC}"
            echo ""
            read -p "Choose an option [1-7]: " choice
            case $choice in
                1) add_client "" ;;
                2) list_clients ;;
                3) show_client_details ;;
                4) remove_client ;;
                5) restart_wireguard ;;
                6) uninstall_wireguard ;;
                7) exit 0 ;;
                *) echo "Invalid option." ;;
            esac
        fi
    done
}

main_menu

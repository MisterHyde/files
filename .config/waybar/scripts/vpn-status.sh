#!/usr/bin/env bash
# Waybar custom module: VPN status.
#
# Reports "up" as soon as at least one VPN-ish interface (wireguard, openvpn,
# vpnc, tailscale, zerotier, ppp, ...) is UP.  Prints waybar JSON on stdout.
#
# Refresh manually with:  pkill -RTMIN+9 waybar

set -uo pipefail

is_vpn_iface() {
    case "$1" in
        tun*|tap*|wg*|ppp*|vpn*|nordlynx|proton*|tailscale*|ipsec*|zt*) return 0 ;;
        *) return 1 ;;
    esac
}

declare -a ifaces=()
while read -r _ name _; do
    name=${name%:}          # strip trailing colon
    name=${name%%@*}        # strip @parent for veth-style names
    is_vpn_iface "$name" && ifaces+=("$name")
done < <(ip -o link show up 2>/dev/null)

if ((${#ifaces[@]} == 0)); then
    printf '{"text":"󰦞","tooltip":"VPN: disconnected","class":"disconnected","alt":"disconnected"}\n'
    exit 0
fi

tooltip="VPN: connected"
for iface in "${ifaces[@]}"; do
    addrs=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | paste -sd ', ')
    [[ -z $addrs ]] && addrs=$(ip -o -6 addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd ', ')
    [[ -z $addrs ]] && addrs="no address"
    tooltip+="\n$iface: $addrs"
done

# label: first interface name, so it is obvious *which* tunnel is up
printf '{"text":"󰖂  %s","tooltip":"%s","class":"connected","alt":"connected"}\n' \
    "${ifaces[0]}" "$tooltip"

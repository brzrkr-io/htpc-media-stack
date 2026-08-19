#!/bin/bash
# Network repair for gort: purge host VPN remnants, stabilize WiFi, and
# remove the pointless single-node vxlan overlay from k3s.
# Run: sudo bash bootstrap/host/fix-network.sh   (then: sudo systemctl start k3s)
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

echo "== 1/4 purge host ProtonVPN (bloat + routing interference; VPN lives in the gluetun pod) =="
DEBIAN_FRONTEND=noninteractive apt-get purge -y proton-vpn-daemon proton-vpn-gnome-desktop \
  proton-vpn-gtk-app protonvpn-stable-release python3-proton-core python3-proton-keyring-linux \
  python3-proton-vpn-api-core python3-proton-vpn-local-agent 2>/dev/null || \
  echo "   WARNING: purge incomplete (apt busy?) - rerun later"
ip link delete proton0 2>/dev/null || true
ip link delete ipv6leakintrf0 2>/dev/null || true

echo "== 2/4 WiFi powersave off (mt7921e wedges under bursty load with powersave on) =="
cat > /etc/NetworkManager/conf.d/wifi-powersave-off.conf <<'EOF'
[connection]
# 2 = disable powersave
wifi.powersave = 2
EOF
systemctl reload NetworkManager 2>/dev/null || true

echo "== 3/4 k3s: host-gw instead of vxlan (single node - the overlay does nothing) =="
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<'EOF'
# Single-node cluster: no vxlan encapsulation needed; host-gw routes pod
# traffic directly and removes the riskiest kernel path from every startup.
flannel-backend: host-gw
EOF

echo "== 4/4 wired check =="
if ip link show eno1 2>/dev/null | grep -q 'LOWER_UP'; then
  SPEED=$(cat /sys/class/net/eno1/speed 2>/dev/null || echo '?')
  echo "   eno1 link UP at ${SPEED}Mbps $( [ "${SPEED}" = "1000" ] && echo '- good' || echo '- BAD CABLE, replace it' )"
else
  echo "   eno1 has NO cable/link. Plug a known-good ethernet cable - the cluster"
  echo "   should not live on WiFi. (It will still work on WiFi until you do.)"
fi

echo
echo "DONE. Now: sudo systemctl start k3s"

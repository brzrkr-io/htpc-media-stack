#!/bin/bash
# One-shot host hardening for gort. Run: sudo bash bootstrap/host/harden-host.sh
#
# Context (2026-08-18): kernel 6.17.0-41 crash-reboots within ~2 min of k3s
# starting (regression vs 6.17.0-40, which ran the same stack 9 days clean).
# The reboots were invisible because kubelet and kdump-config re-arm
# kernel.panic_on_oops=1/kernel.panic=10 on every start. This script:
#   - installs panic-guard so an oops can only ever log, never reboot
#   - pins GRUB to the known-good 6.17.0-40 kernel
#   - purges the broken kdump setup (reclaims the 512MB crashkernel= after reboot)
#   - disables non-HTPC services (host ProtonVPN, docker, printing, etc.)
#   - retires the absent USB drive (fstab, stray backups) and dead app configs
#   - re-enables k3s for boot
# Reboot afterwards: the box comes up on 6.17.0-40 with the lean stack.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== 1/8 panic-guard: an oops must log, never reboot =="
install -m 0755 "$HERE/panic-guard.sh" /usr/local/sbin/panic-guard.sh
install -m 0644 "$HERE/panic-guard.service" /etc/systemd/system/panic-guard.service
install -m 0644 "$HERE/sysctl-99-no-panic.conf" /etc/sysctl.d/99-no-panic-on-oops.conf
mkdir -p /etc/systemd/system/k3s.service.d
install -m 0644 "$HERE/k3s-no-panic.conf" /etc/systemd/system/k3s.service.d/10-no-panic.conf
mkdir -p /etc/systemd/journald.conf.d
install -m 0644 "$HERE/journald-crash-capture.conf" /etc/systemd/journald.conf.d/99-crash-capture.conf
systemctl daemon-reload
systemctl enable --now panic-guard.service
systemctl restart systemd-journald
sysctl -q -p /etc/sysctl.d/99-no-panic-on-oops.conf

echo "== 2/8 pin boot kernel to known-good 6.17.0-40 =="
[ -f /boot/vmlinuz-6.17.0-40-generic ] || { echo "ERROR: 6.17.0-40 kernel missing"; exit 1; }
apt-mark hold linux-image-6.17.0-40-generic linux-modules-6.17.0-40-generic >/dev/null
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub

echo "== 3/8 purge broken kdump (also frees the 512MB crashkernel= reservation) =="
DEBIAN_FRONTEND=noninteractive apt-get purge -y kdump-tools makedumpfile crash || true
if dpkg -s kdump-tools >/dev/null 2>&1; then
  echo "   WARNING: kdump-tools purge failed (apt busy?) - crashkernel= stays until you re-run this step"
fi
update-grub 2>/dev/null
SUB=$(grep -oP "submenu '[^']*' \\\$menuentry_id_option '\K[^']+" /boot/grub/grub.cfg | head -1)
ENTRY=$(grep -oP "menuentry 'Ubuntu, with Linux 6\.17\.0-40-generic'.*\\\$menuentry_id_option '\K[^']+" /boot/grub/grub.cfg | head -1)
[ -n "$SUB" ] && [ -n "$ENTRY" ] || { echo "ERROR: could not locate 6.17.0-40 GRUB entry"; exit 1; }
grub-set-default "${SUB}>${ENTRY}"
echo "   default boot: ${SUB}>${ENTRY}"

echo "== 4/8 disable non-HTPC services =="
# Host-level ProtonVPN (VPN lives in the gluetun pod; the host tunnel hijacks
# routing/DNS/IPv6 under k3s and cloudflared)
systemctl disable --now openvpn.service me.proton.vpn.split_tunneling.service 2>/dev/null || true
# Printing, mDNS, modem, crash uploaders, enterprise auth
# (sssd's sockets re-activate the service on any NSS lookup, so they must go too)
for u in cups.service cups.socket cups.path cups-browsed.service avahi-daemon.service \
         avahi-daemon.socket ModemManager.service whoopsie.service apport.service \
         apport-autoreport.timer sssd.service sssd-nss.socket sssd-pam.socket \
         sssd-autofs.socket sssd-ssh.socket sssd-sudo.socket sssd-pac.socket; do
  systemctl disable --now "$u" 2>/dev/null || true
done
# Docker + standalone containerd: k3s has its own embedded containerd.
# Only disable when we can positively confirm no containers exist.
if ! command -v docker >/dev/null 2>&1; then
  systemctl disable --now docker.socket docker.service containerd.service 2>/dev/null || true
  echo "   docker CLI absent - runtime services disabled"
elif docker info >/dev/null 2>&1 && [ -z "$(docker ps -aq)" ]; then
  systemctl disable --now docker.socket docker.service containerd.service 2>/dev/null || true
  echo "   docker/containerd disabled (no containers found)"
else
  echo "   WARNING: docker has containers or daemon unqueryable - left enabled, review manually"
fi

echo "== 5/8 retire the absent USB drive =="
sed -i 's|^UUID=83f6071d-e7b6-46b4-9427-f2172981341f|# (SanDisk 8TB retired 2026-08-18) &|' /etc/fstab
systemctl daemon-reload

echo "== 6/8 move stray backups to /data/backups (frees ~6GB on /) =="
mkdir -p /data/backups/configs
newest=$(ls -1t /mnt/media-storage/backups/configs/media-config-*.tar.gz 2>/dev/null | head -1 || true)
if [ -n "${newest:-}" ]; then
  mv "$newest" /data/backups/configs/
  rm -f /mnt/media-storage/backups/configs/media-config-*.tar.gz
  # plain rmdir (never -p: that would remove the /mnt/media-storage mountpoint)
  rmdir /mnt/media-storage/backups/configs /mnt/media-storage/backups 2>/dev/null || true
  echo "   kept newest: /data/backups/configs/$(basename "$newest")"
fi
chown -R 1000:1000 /data/backups

echo "== 7/8 delete config dirs of long-removed apps (all inside the kept tarball) =="
for d in crowdsec duplicati glance glances gotify homarr loki qbittorrent speedtest tdarr uptime-kuma; do
  rm -rf "/data/media/config/$d"
done
install -m 0644 "$HERE/sysctl-98-htpc-tuning.conf" /etc/sysctl.d/98-htpc-tuning.conf
sysctl -q -p /etc/sysctl.d/98-htpc-tuning.conf

echo "== 8/8 re-enable k3s for boot; install disk diagnostics =="
systemctl enable k3s >/dev/null 2>&1
# smartmontools: needed to diagnose the returning SanDisk 8TB (fw/health)
DEBIAN_FRONTEND=noninteractive apt-get install -y smartmontools >/dev/null 2>&1 || \
  echo "   WARNING: smartmontools install failed (offline?) - install later"

echo
echo "DONE. Now run:  sudo reboot"
echo "The box will boot 6.17.0-40 with panic-guard active and the lean stack."

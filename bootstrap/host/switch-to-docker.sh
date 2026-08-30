#!/bin/bash
# Replace k3s with Docker Compose. Run: sudo bash bootstrap/host/switch-to-docker.sh
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
echo "== 1/3 remove k3s (app data under /data/media is untouched) =="
[ -x /usr/local/bin/k3s-uninstall.sh ] && /usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1
rm -rf /etc/systemd/system/k3s.service.d /etc/rancher
echo "== 2/3 docker + compose plugin =="
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2 >/dev/null 2>&1 || echo "   WARNING: compose plugin install failed"
systemctl unmask docker.service docker.socket containerd.service 2>/dev/null
systemctl enable --now containerd docker.socket docker.service
usermod -aG docker swig
echo "== 3/3 start the stack (as swig) =="
cd /home/swig/workspace/htpc-media-stack/compose && sg docker -c "docker compose up -d" 2>&1 | tail -15
echo; echo "DONE. Tell Claude 'up'."

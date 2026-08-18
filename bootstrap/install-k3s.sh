#!/bin/bash
set -euo pipefail

# HTPC Media Stack - k3s Installation Script
# This script installs k3s with settings optimized for a single-node media server

echo "=== Installing k3s ==="

# Matches the live install on gort: k3s bundled traefik + servicelb serve all
# Ingresses; svclb publishes 80/443 on the node IP, which is what the host
# cloudflared tunnel points at. Do NOT add --disable servicelb/traefik.

curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644

echo "=== Waiting for k3s to be ready ==="
sleep 10

# Wait for node to be ready
kubectl wait --for=condition=ready node --all --timeout=120s

echo "=== k3s installed successfully ==="
echo ""
echo "Node status:"
kubectl get nodes -o wide
echo ""
echo "System pods:"
kubectl get pods -n kube-system
echo ""
echo "=== Next Steps ==="
echo "1. Install FluxCD CLI: curl -s https://fluxcd.io/install.sh | sudo bash"
echo "2. Create a GitHub repo for your manifests"
echo "3. Run ./bootstrap/flux-bootstrap.sh"

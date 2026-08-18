#!/bin/bash
set -euo pipefail

# HTPC Media Stack - Complete Setup Script
# This script handles the full initial setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  HTPC Media Stack - Setup"
echo "=========================================="
echo ""

# Step 1: Check/Install Nix
echo "[1/4] Checking Nix installation..."
if ! command -v nix &> /dev/null; then
    echo "Nix not found. Installing..."
    "$SCRIPT_DIR/install-nix.sh"
    echo ""
    echo "Please restart your shell and run this script again."
    exit 0
else
    echo "✓ Nix installed: $(nix --version)"
fi

# Step 2: Enter Nix environment and verify tools
echo ""
echo "[2/4] Loading Nix development environment..."
cd "$PROJECT_DIR"

# Check if we're in a nix shell already
if [ -z "${IN_NIX_SHELL:-}" ]; then
    echo "Entering nix develop shell..."
    exec nix develop --command bash "$0" "$@"
fi

echo "✓ Nix environment loaded"
echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || echo 'available')"
echo "  - flux: $(flux --version 2>/dev/null || echo 'available')"
echo "  - helm: $(helm version --short 2>/dev/null || echo 'available')"

# Step 3: Create data directories
# Media lives on the internal NVMe under /data/media/local-media (the old
# /data/media/{downloads,library} paths are convenience symlinks into it).
echo ""
echo "[3/4] Creating data directories..."
sudo mkdir -p /data/media/config \
    /data/media/local-media/downloads/{complete,incomplete,watch} \
    /data/media/local-media/library/{movies,tv} \
    /data/media/downloads-incomplete /data/backups/configs
sudo ln -sfn local-media/downloads /data/media/downloads
sudo ln -sfn local-media/library /data/media/library
sudo chown 1000:1000 /data/media /data/media/config /data/backups /data/backups/configs \
    /data/media/downloads-incomplete
sudo chown -R 1000:1000 /data/media/local-media
echo "✓ Created /data/media structure"
echo ""
echo "[3b/4] Host hardening (panic-guard, kernel pin, service cleanup)..."
echo "  Run: sudo bash $SCRIPT_DIR/host/harden-host.sh"

# Step 4: Check k3s
echo ""
echo "[4/4] Checking k3s..."
if command -v k3s &> /dev/null; then
    echo "✓ k3s is installed"
    if systemctl is-active --quiet k3s; then
        echo "✓ k3s is running"
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        kubectl get nodes
    else
        echo "! k3s is installed but not running"
        echo "  Start with: sudo systemctl start k3s"
    fi
else
    echo "! k3s not installed"
    echo "  Install with: ./bootstrap/install-k3s.sh"
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. If k3s not installed:"
echo "   ./bootstrap/install-k3s.sh"
echo ""
echo "2. Update VPN credentials:"
echo "   vim kubernetes/apps/downloads/gluetun/secret.yaml"
echo ""
echo "3. Push to GitHub and bootstrap FluxCD:"
echo "   git init && git add . && git commit -m 'Initial commit'"
echo "   git remote add origin git@github.com:YOUR_USER/htpc-media-stack.git"
echo "   git push -u origin main"
echo "   ./bootstrap/flux-bootstrap.sh"
echo ""
echo "4. For auto-loading Nix env, set up direnv:"
echo "   nix profile install nixpkgs#direnv"
echo "   echo 'eval \"\$(direnv hook bash)\"' >> ~/.bashrc"
echo "   source ~/.bashrc && direnv allow"
echo ""

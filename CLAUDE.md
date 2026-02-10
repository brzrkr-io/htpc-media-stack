# HTPC Media Stack - Project Context

## Overview
Kubernetes (k3s) based media stack with Flux CD for GitOps deployment.

## Critical: 8TB USB Drive Stability Issue
The SanDisk Extreme 8TB USB drive (Vendor: 0781, Product: 55dd) has UAS driver issues causing disconnections.

### Fixes Applied (NEED REBOOT TO TAKE EFFECT):
1. `/etc/modprobe.d/sandisk-disable-uas.conf` - Disables UAS for this device
2. `/etc/default/grub.d/sandisk-uas.cfg` - Boot parameter: `usb-storage.quirks=0781:55dd:u`
3. `/etc/udev/rules.d/50-sandisk-no-autosuspend.rules` - Disables USB autosuspend
4. GRUB updated with `sudo update-grub`

**IMPORTANT: System needs a reboot to fully apply the UAS disable fix!**

## Storage Layout
- **NVMe (reliable)**: `/data/media/config/` - All app configs stored here
- **8TB USB**: `/mnt/media-storage/` - Media files and downloads only
  - `/mnt/media-storage/library/movies`
  - `/mnt/media-storage/library/tv`
  - `/mnt/media-storage/downloads/complete/tv-sonarr`
  - `/mnt/media-storage/downloads/complete/movies-radarr`
  - `/mnt/media-storage/downloads/incomplete`

## fstab Entry
```
UUID=83f6071d-e7b6-46b4-9427-f2172981341f /mnt/media-storage ext4 defaults,nofail,x-systemd.device-timeout=10 0 2
```

## API Keys (as of Jan 7, 2026)
- Prowlarr: b19d0bd1806b45eab740ba5829c119e0
- Sonarr: 90a00b9e090b4f0f803fd3fb1298faa0
- Radarr: 6a16b3b4b8da4dcaa522d49b27fd2f16
- SABnzbd: 6ae647c8f6554f33ba2ceae7ff075b27
- Bazarr: 4f9141b6d4ff051d8186a3d4b4aee56b

## Service Cluster IPs (for API calls)
- Prowlarr: 10.43.146.194:9696
- Sonarr: 10.43.131.246:8989
- Radarr: 10.43.39.55:7878
- SABnzbd: 10.43.142.100:8080
- Jellyfin: 10.43.48.23:8096
- FlareSolverr: 10.43.121.210:8191
- Transmission: 10.43.177.174:9091

## Access URLs (via Cloudflare Tunnel)
- http://sonarr.brzrkr.io
- http://radarr.brzrkr.io
- http://prowlarr.brzrkr.io
- http://jellyfin.brzrkr.io
- http://request.brzrkr.io (Jellyseerr)
- http://sabnzbd.brzrkr.io
- http://transmission.brzrkr.io

## Usenet Server
- Host: news.newshosting.com
- Port: 563 (SSL)
- 30 connections configured

## Indexers Configured in Prowlarr
- NZBgeek (Usenet)
- 1337x, EZTV, KickassTorrents, LimeTorrents, The Pirate Bay, YTS (Torrents)

## SABnzbd Categories
- `tv` -> `/downloads/complete/tv-sonarr`
- `movies` -> `/downloads/complete/movies-radarr`

## Common Issues & Fixes

### Drive Disconnects
If drive disconnects (I/O errors), the device name changes (sdb -> sdc -> sdd etc):
```bash
# Check current device
lsblk | grep "7.3T"

# Unmount stale, remount new
sudo umount -l /mnt/media-storage
sudo mount /dev/sdX /mnt/media-storage  # Replace X with current letter

# Restart pods
k3s kubectl rollout restart deployment -n media
k3s kubectl rollout restart deployment -n downloads
```

### Check All Services Health
```bash
curl -s "http://10.43.146.194:9696/api/v1/health?apikey=b19d0bd1806b45eab740ba5829c119e0" | jq
curl -s "http://10.43.131.246:8989/api/v3/health?apikey=90a00b9e090b4f0f803fd3fb1298faa0" | jq
curl -s "http://10.43.39.55:7878/api/v3/health?apikey=6a16b3b4b8da4dcaa522d49b27fd2f16" | jq
```

### Trigger Missing Content Search
```bash
# Sonarr - search missing episodes
curl -X POST "http://10.43.131.246:8989/api/v3/command" -H "X-Api-Key: 90a00b9e090b4f0f803fd3fb1298faa0" -H "Content-Type: application/json" -d '{"name": "MissingEpisodeSearch"}'

# Radarr - search missing movies
curl -X POST "http://10.43.39.55:7878/api/v3/command" -H "X-Api-Key: 6a16b3b4b8da4dcaa522d49b27fd2f16" -H "Content-Type: application/json" -d '{"name": "MissingMoviesSearch"}'
```

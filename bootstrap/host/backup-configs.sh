#!/bin/bash
# Daily config backup (replaces the old k8s CronJob). Keeps 7.
D=/data/backups/configs; mkdir -p "$D"
tar czf "$D/media-config-$(date +%Y%m%d-%H%M%S).tar.gz" -C /data/media/config \
  --exclude='./jellyfin/cache' --exclude='./jellyfin/data/metadata' --exclude='./jellyfin/data/transcodes' \
  --exclude='./jellyfin/log' --exclude='./*/MediaCover' --exclude='./*/logs' --exclude='./*/Logs' . 2>/dev/null
ls -1t "$D"/media-config-*.tar.gz | tail -n +8 | xargs -r rm -f

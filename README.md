# HTPC Media Stack

Lean, GitOps-managed home-theater stack for a single-node k3s cluster
(host `gort`, Beelink mini-PC, AMD Radeon 680M, 18GB RAM, Ubuntu).
Flux CD reconciles everything under `kubernetes/` from this repo
(`prune: true` — delete a manifest here and the live resource goes away).

## What runs

| Area | Apps |
|---|---|
| Streaming | Jellyfin (VA-API hardware transcode), Jellyseerr (requests) |
| Automation | Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, Maintainerr |
| Downloads | SABnzbd (usenet, primary), Transmission + FlareSolverr behind a gluetun VPN pod (torrents, secondary) |
| Processing | FileFlows (GPU transcoding), Unpackerr |
| Infra | k3s bundled Traefik + servicelb (ingress), config-backup CronJob, Flux |

Ingress: host-level `cloudflared` tunnel → Traefik on the node IP :80 →
`*.brzrkr.io` Ingresses. cloudflared is a host systemd service, not a pod.

## Layout

- `kubernetes/apps/` — one directory per app (deployment + service/ingress)
- `kubernetes/infrastructure/` — backup CronJob
- `kubernetes/flux-system/` — Flux bootstrap components
- `bootstrap/` — host setup scripts; `bootstrap/host/` hardens the host
  (panic-guard so a kernel oops logs instead of rebooting, kernel pin,
  journald flush tuning, non-HTPC service cleanup)

## Storage (all on internal NVMe)

- `/data/media/config/<app>` — app configs (hostPath mounts)
- `/data/media/local-media/downloads` — downloads (`complete/`, `watch/`)
- `/data/media/downloads-incomplete` — SABnzbd incomplete spool
- `/data/media/local-media/library/{movies,tv}` — the library
- `/data/backups/configs` — daily config tarballs (same-disk copies; take an
  off-box copy occasionally)

`/data/media/{downloads,library}` are convenience symlinks into `local-media/`;
manifests mount the concrete paths.

## Operating notes

- Every image is pinned to a digest with `imagePullPolicy: IfNotPresent` — no
  image-pull stampede after a reboot. To update an app, update the digest.
- Jellyfin/SABnzbd/FileFlows memory limits are sized so all three together
  cannot exhaust the node. Keep it that way when tuning.
- The gluetun pod is the only VPN. Do not run a host-level VPN alongside it.
- Kernel 6.17.0-41 crash-reboots this box under k3s (pod-network regression;
  6.17.0-40 is pinned via GRUB). Before moving to a newer kernel: boot it once
  with `sudo grub-reboot <entry>` and let k3s run a day; panic-guard will turn
  any recurrence into journal logs instead of a crash loop.

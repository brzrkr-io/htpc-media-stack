# HTPC Media Stack - Project Context

Single-node k3s + Flux GitOps on host `gort` (Beelink, AMD 680M iGPU, 18GB RAM,
Ubuntu). See README.md for the app list and storage layout.

## Ground rules

- GitOps: change manifests here, commit, push, `flux reconcile ks flux-system
  --with-source`. Flux prunes anything removed from git.
- kubectl/flux/k9s are in `~/.nix-profile/bin` (on PATH); kubeconfig at
  `~/.kube/config`. No sudo needed for cluster work.
- All images digest-pinned + `IfNotPresent`. Update = bump digest in git.
- Ingress is k3s's bundled Traefik in kube-system (+svclb on node :80/:443);
  the cloudflared tunnel (host systemd service) targets it. There is no
  Traefik in this repo — don't add one, don't disable the bundled one.

## Stability guardrails (2026-08-18, don't undo)

- **panic-guard.service** re-zeroes `kernel.panic_on_oops`/`kernel.panic`
  every 2s — kubelet re-arms them on every k3s start; without the guard, any
  kernel oops instantly reboots the box with no trace.
- **Kernel pinned to 6.17.0-40** (GRUB saved default + apt-mark hold).
  6.17.0-41 crash-rebooted within ~2 min of k3s starting pods (9 crashes,
  Jul 23 + Aug 18). Test newer kernels with `grub-reboot` one-shot boots only.
- Memory limits: Jellyfin 4Gi, SABnzbd 3Gi, FileFlows 3Gi — sized to coexist.
  The old 8/6/4Gi limits summed past physical RAM and OOM-thrashed the node.
- Slow-starter probes: the *arr apps/SAB/FileFlows have startupProbes and 10s
  probe timeouts. Don't tighten them; 1s-timeout probes caused restart storms
  after every unclean reboot.
- The flaresolverr-healthcheck CronJob has hysteresis (10-min pod age gate +
  2 strikes) — it used to bounce the whole VPN pod during every boot.

## Storage facts

- Everything on NVMe under `/data/media/local-media/` (concrete paths in
  manifests; `/data/media/{downloads,library}` are symlinks kept for humans).
- SABnzbd incomplete spool: `/data/media/downloads-incomplete` (mounted at
  `/incomplete`).
- Backups: `/data/backups/configs`, daily CronJob, keeps 7, excludes
  regenerable caches (jellyfin metadata, MediaCover, logs).
- SanDisk 8TB USB (0781:55dd, fw 0130): UAS-drop history under sustained
  writes; `usb-storage.quirks=0781:55dd:u` is on the kernel cmdline. Its old
  fstab entry is commented out — reintroduce deliberately if the drive
  returns; nothing in the stack depends on it.

## Gotchas that already bit us

- Removing a Traefik middleware/namespace that Ingress annotations reference
  404s EVERY host (crowdsec incident). Check annotation refs before deleting.
- `media/flaresolverr` ExternalName service is referenced by Prowlarr's
  database config — deleting it silently breaks CF-solved indexers.
- Secrets (ProtonVPN, Newshosting, API keys) are plaintext in git history —
  treat the repo as sensitive; SOPS migration is a wanted follow-up.
- User prefers usenet (SABnzbd+NZBgeek); torrents are secondary. FlareSolverr
  can't solve 1337x/eztvx (those indexers stay disabled).

## API keys / service IPs

Don't hardcode them here. Keys: `/data/media/config/<app>/config.xml`.
IPs: `kubectl get svc -A`.

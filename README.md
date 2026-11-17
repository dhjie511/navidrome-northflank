# Navidrome on Northflank (public, free Sandbox tier)

Self-hosted Navidrome music server (v0.64.2) as a public Northflank
service, so an iPhone can reach it from SoundFlow without a VPN /
Tailscale — and, unlike Render's free tier, Northflank's free Sandbox
tier **does not sleep**.

## What it does

- Runs the official image `navidrome/navidrome:0.64.2`.
- On **first start**, `entrypoint.sh` downloads 4 public demo tracks
  (Howler.js demo audio + Kevin MacLeod's "Outfoxing the Fox") and
  creates the first admin account from `ND_ADMIN_USER` /
  `ND_ADMIN_PASSWORD`.
- Listens on a **fixed port 4533** (Northflank does not inject a
  `$PORT` variable like Render/Heroku do — the port is configured in
  the dashboard, see step 5).
- With a persistent volume mounted at `/data` (step 6), songs, the
  database, playlists and users survive restarts and redeploys. The
  entrypoint skips re-downloading any track that is already present
  with the exact expected size, so with a volume it downloads once.
  Without a volume the container filesystem is ephemeral and the 4
  tracks are re-downloaded on every start (same behaviour as the
  Render package).

## Cost (Northflank's own pricing page, read 2026-11-17)

Free tier = **Developer Sandbox**: 2 services, 2 jobs, 1 database,
up to **$20/month of resources** on Northflank Cloud, **always on,
no sleeping**.

| Item | Price | Monthly cost |
| --- | --- | --- |
| Compute, smallest plan `nf-compute-50` (0.5 vCPU, 1 GB) | $0.01667/vCPU/hr | **$12.00** |
| Persistent disk, 2 GiB NVMe | $0.11657/GiB/month | **$0.23** |
| Network egress | $0.06/GB | ~$0 for personal listening |
| **Total** | | **~$12.23/month — inside the $20 free allowance** |

Notes:

- If the console offers a smaller compute plan when creating the
  service, take it — it only makes the total cheaper.
- A 2 GiB volume holds roughly 400 songs at ~5 MB each. It can be
  enlarged later in the dashboard without recreating the service.
- Set a **billing alert** in the dashboard (Billing → Monitor
  spending) at e.g. $15 so a surprise never happens. Usage beyond the
  Sandbox allowance is pay-as-you-go.
- Northflank's own billing docs say the free plan "should not be
  used for production applications" — this is a hobby/test setup,
  which is exactly what it is for.

## Deploy — path A (recommended): Combined service from GitHub

This is the same pattern as the Render package and the only path
that runs the custom entrypoint automatically.

1. **Create a GitHub repository** `dhjie511/navidrome-northflank`
   (public, no secrets in it) and push the 3 files in this folder:
   `Dockerfile`, `entrypoint.sh`, `README.md`.
2. **Sign up at Northflank** (app.northflank.com): GitHub, Google,
   or email + password. Verify your email if you used the
   email/password flow.
3. **Add a payment method** (Billing → Payment methods). This is
   required before creating any resource, on every plan including
   free — Northflank's own billing docs: "all users must add a
   payment method to start creating resources on Northflank,
   regardless of plan selection. This is to verify user identity,
   and prevent malicious usage of the platform." The card is only
   verified, not charged, until you create and use paid services.
   **Pick the Developer Sandbox plan, not Pay as you go**, when
   creating your team.
4. **Create a project** (name it e.g. `navidrome`), then
   **Services → Create service → Combined service**, name it
   `navidrome`. Select the GitHub repository and branch, build type
   **Dockerfile** (auto-detected at the repo root). Resources:
   smallest compute plan (`nf-compute-50`, 0.5 vCPU / 1 GB).
5. **Networking → Add port**: port `4533`, protocol **HTTP**,
   accessibility **Public**. Northflank provisions a public HTTPS
   URL on the `code.run` domain (e.g.
   `https://4533--navidrome--<project>--<user>.<cluster>.code.run`)
   with an automatic TLS certificate; HTTP is redirected to HTTPS.
   The exact hostname is shown in the service header after creation.
   (Northflank does not use a `$PORT` environment variable — the
   app listens on the fixed port 4533 set by `ND_PORT`.)
6. **Attach a persistent volume**: project → **Volumes → Create
   volume**. Name it `navidrome-data`, access mode **Single
   Read/Write**, storage type **NVMe**, size **2 GiB**, container
   mount path **`/data`**, attach it to the `navidrome` service.
   Attaching a volume restarts the deployment and limits the
   service to 1 instance (fine — Navidrome is single-instance).
7. **Environment variables** (service → Environment / Secret
   groups). `ND_ADMIN_PASSWORD` must be a **secret**, never written
   in the repo:

   | Key | Value |
   | --- | --- |
   | `ND_ADMIN_USER` | `dhjie511` |
   | `ND_ADMIN_PASSWORD` | *(secret — dai's usual desktop password, typed in the dashboard only)* |
   | `ND_PORT` | `4533` |
   | `ND_MUSICFOLDER` | `/data/music` |
   | `ND_DATAFOLDER` | `/data` |
   | `ND_LOGLEVEL` | `info` |

8. **Create the service.** First build takes a few minutes (pulls
   the Navidrome image, builds the Dockerfile, starts the
   container). Watch the logs: you should see the 4 `ok ...`
   download lines, `navidrome is up on :4533`, and
   `createAdmin: 200`.

Your public address will be the `code.run` URL from step 5, e.g.:

```
https://4533--navidrome--<project>--<user>.<cluster>.code.run
```

## Deploy — path B (no GitHub repo): Deployment service, external image

If you don't want a GitHub repository, use the stock image directly:

1. Steps 2–3 as in path A (sign up, add a card, pick Sandbox).
2. **Services → Create service → Deployment service**, name it
   `navidrome`. Deployment source: **External image**, image path
   `navidrome/navidrome:0.64.2` (Docker Hub, public — no registry
   credentials needed).
3. Same as path A steps 5–7: public HTTP port `4533`, volume
   mounted at `/data` (2 GiB), environment variables as above.
4. **Custom entrypoint/command** (service → Configure → Command):
   entrypoint `bash -c`, command the one-liner below (paste as a
   single line; it downloads the 4 demo tracks if missing, then
   starts Navidrome — the stock image already ships `curl`):

   ```sh
   mkdir -p /data/music/"Howler Demo" /data/music/"Kevin MacLeod"; cd /data/music; [ -s "Howler Demo/80s_vibe.mp3" ] || curl -fsSL -o "Howler Demo/80s_vibe.mp3" https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/80s_vibe.mp3; [ -s "Howler Demo/rave_digger.mp3" ] || curl -fsSL -o "Howler Demo/rave_digger.mp3" https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/rave_digger.mp3; [ -s "Howler Demo/running_out.mp3" ] || curl -fsSL -o "Howler Demo/running_out.mp3" https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/running_out.mp3; [ -s "Kevin MacLeod/outfoxing.mp3" ] || curl -fsSL -o "Kevin MacLeod/outfoxing.mp3" https://cdn.jsdelivr.net/gh/mdn/webaudio-examples@main/audio-basics/outfoxing.mp3; exec /app/navidrome
   ```

5. Create the service. **The admin account is not created
   automatically on this path**: on first visit Navidrome shows its
   create-admin page — fill in username `dhjie511` and the same
   password. (Path A does this step for you.)

## SoundFlow settings (iPhone)

No Tailscale / VPN needed — this is a public HTTPS address:

- Server: the `code.run` URL from step 5 (path A) / step 3 (path B)
- Username: `dhjie511`
- Password: the admin password entered in the dashboard

## Verify

```sh
curl -s -o /dev/null -w "%{http_code}\n" https://<your-service>.code.run/
# 302 = up (redirects to the login page)
```

Log in on the web page and check the library shows 4 songs
(80s_vibe, rave_digger, running_out, Outfoxing the Fox).

## Free-tier persistent volume: the honest conclusion

- Northflank's own docs describe persistent volumes as a general
  feature (service → Volumes → Create volume, set a container mount
  path, attach to the service; containers without a volume are
  ephemeral and lose data on restart). **The docs page does not
  state any plan restriction on volumes**, and the pricing page's
  plan-comparison row "Volumes and persistence" does not resolve
  to a yes/no for Sandbox Free in its published text.
- A third-party guide for a free-Sandbox deployment reports that
  the Sandbox plan **can** attach a persistent volume (1 GB, mount
  `/data`).
- So: most likely yes, but **not proven from Northflank's own
  pages alone**. The package is built to survive either outcome:
  if the volume attaches, songs + database persist; if it does
  not (or the console refuses on the free plan), the entrypoint
  re-downloads the 4 demo tracks on every start and recreates the
  admin, exactly like the Render package. The only thing lost
  without a volume is anything added later (playlists, extra
  songs, ratings).
- **Confirm in the console**: if "Create volume" is available and
  the volume shows attached after deploy, persistence works. If
  the console blocks it on Sandbox, stay on path A without a
  volume (still always-on, just re-seeded each start) or use the
  0359 Tailscale server for a large library.

## Caveats

- **A card is required.** Not for signup itself, but Northflank's
  billing docs require every user to add a payment method before
  creating resources, on any plan. It is verification only — the
  card is not charged until paid services are created and used.
  There is no way around this step; it has to be dai's own card,
  entered in the Northflank dashboard.
- **Email verification** is required if signing up with
  email/password (not needed for GitHub/Google sign-in).
- The Sandbox plan is for hobby/test use, not production — fine
  for this.
- If the service ever fails to start with a permission error
  after attaching the volume, Northflank's own volume docs suggest
  adding a `chown -R <user>:<group> /data` step to the startup
  command (volume ownership follows the group set in the Docker
  image at build time). The official Navidrome image runs as root,
  so this should not be needed.
- Health check: if the dashboard asks for one, use path `/`
  (Navidrome answers 302 there, which counts as up). If it
  insists on a 200, use `/login`.
- The 0359 Tailscale server and the Render package are untouched
  by this deployment. Keep 0359 as the backup for a large library:
  its D: drive has ~16 GB free, roughly 3,000 songs at ~5 MB each.

## Files

- `Dockerfile` — official Navidrome 0.64.2 image + custom
  entrypoint, `EXPOSE 4533` so Northflank auto-detects the port.
- `entrypoint.sh` — downloads the demo tracks, starts Navidrome
  on fixed port 4533 (`ND_PORT`, no `$PORT`), creates the first
  admin via `POST /auth/createAdmin`.
- `README.md` — this file.

## Local test (2026-11-17, this VM)

Official Linux binary `navidrome_0.64.2_linux_amd64.tar.gz`,
SHA256 verified against the release `navidrome_checksums.txt`,
version `0.64.2`. Ran the full `entrypoint.sh` flow (no `$PORT`
set, proving it does not depend on one): 4 tracks downloaded with
exact sizes, Navidrome started, `POST /auth/createAdmin` returned
200, login succeeded, song list showed all 4, Subsonic
`/rest/stream` returned a real MP3. Restart with the same data
folder (simulating the volume): no re-download, `createAdmin`
returned 403 (admin already exists), all 4 songs still listed.

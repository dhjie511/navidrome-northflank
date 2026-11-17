# Navidrome on Northflank (public, free Sandbox tier) — Dockerfile
#
# Builds on the official image (navidrome/navidrome:0.64.2, alpine-based,
# already ships curl + ffmpeg). The entrypoint downloads 4 public demo
# tracks on first start and creates the first admin account from env vars.
#
# Northflank differences from the Render version of this package:
#   - Northflank does NOT inject a $PORT variable. The service listens on
#     a fixed port you configure in the dashboard (Networking -> Add port).
#     We use 4533 everywhere: EXPOSE 4533 below, ND_PORT=4533 in the
#     entrypoint, and a public HTTP port 4533 in the dashboard. Northflank
#     auto-detects EXPOSEd ports when the service is created.
#   - The container filesystem is ephemeral. Persistence comes from a
#     Northflank volume mounted at /data (see README.md): with the volume
#     attached, songs + database survive restarts and redeploys; without
#     it, the entrypoint re-downloads the 4 demo tracks on every start.
#   - Attach a volume limits the service to 1 instance. Navidrome is
#     single-instance anyway, so this costs nothing.
FROM navidrome/navidrome:0.64.2

EXPOSE 4533

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

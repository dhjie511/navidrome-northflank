#!/bin/sh
# Navidrome entrypoint for Northflank (free Sandbox tier).
#
# On every start:
#   1. downloads the 4 public demo tracks into the music folder
#      (skips any file already present with the exact expected size,
#      so with a persistent volume mounted at /data this runs once),
#   2. starts Navidrome listening on ND_PORT (default 4533),
#   3. creates the first admin account from ND_ADMIN_USER /
#      ND_ADMIN_PASSWORD (POST /auth/createAdmin only works while no
#      user exists yet; a 403 just means the admin is already there).
#
# Northflank note: there is NO $PORT variable here (unlike Render).
# The port is fixed: set ND_PORT=4533 in the dashboard and expose a
# public HTTP port 4533 on the service (Networking -> Add port).
#
# The admin password is NEVER written in this repo. It comes from the
# Northflank dashboard as a secret environment variable.

set -eu

export ND_PORT="${ND_PORT:-4533}"
export ND_ADDRESS="${ND_ADDRESS:-0.0.0.0}"
export ND_MUSICFOLDER="${ND_MUSICFOLDER:-/data/music}"
export ND_DATAFOLDER="${ND_DATAFOLDER:-/data}"
export ND_LOGLEVEL="${ND_LOGLEVEL:-info}"
export ND_SCANSCHEDULE="${ND_SCANSCHEDULE:-1h}"
NAVIDROME_BIN="${NAVIDROME_BIN:-/app/navidrome}"

mkdir -p "$ND_MUSICFOLDER/Howler Demo" "$ND_MUSICFOLDER/Kevin MacLeod"

# dl <url> <dest> <expected-bytes>
dl() {
  url="$1"; dest="$2"; want="$3"
  if [ -f "$dest" ]; then
    got="$(wc -c < "$dest" | tr -d ' ')"
    if [ "$got" = "$want" ]; then echo "have $dest"; return 0; fi
  fi
  i=1
  while [ "$i" -le 3 ]; do
    if curl -fsSL --max-time 120 -o "$dest.tmp" "$url"; then
      got="$(wc -c < "$dest.tmp" | tr -d ' ')"
      if [ "$got" = "$want" ]; then
        mv "$dest.tmp" "$dest"
        echo "ok $dest ($got bytes)"
        return 0
      fi
      echo "size mismatch $dest: got=$got want=$want (try $i)"
    else
      echo "download failed: $url (try $i)"
    fi
    rm -f "$dest.tmp"
    i=$((i + 1))
    sleep 2
  done
  echo "WARNING: could not fetch $dest, continuing without it"
}

# Public demo tracks (verified sizes, 2026-11-17):
# Howler.js player demo audio (MIT) + Kevin MacLeod via MDN (CC-BY)
dl 'https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/80s_vibe.mp3' \
  "$ND_MUSICFOLDER/Howler Demo/80s_vibe.mp3" 973773
dl 'https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/rave_digger.mp3' \
  "$ND_MUSICFOLDER/Howler Demo/rave_digger.mp3" 1260390
dl 'https://cdn.jsdelivr.net/gh/goldfire/howler.js@master/examples/player/audio/running_out.mp3' \
  "$ND_MUSICFOLDER/Howler Demo/running_out.mp3" 1094157
dl 'https://cdn.jsdelivr.net/gh/mdn/webaudio-examples@main/audio-basics/outfoxing.mp3' \
  "$ND_MUSICFOLDER/Kevin MacLeod/outfoxing.mp3" 1831788

"$NAVIDROME_BIN" &
ND_PID=$!

cleanup() {
  kill "$ND_PID" 2>/dev/null || true
  wait "$ND_PID" 2>/dev/null || true
}
trap cleanup TERM INT

# Wait until Navidrome answers HTTP (any status counts: / redirects to login).
i=1
while [ "$i" -le 45 ]; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${ND_PORT}/" || true)"
  case "$code" in
    ''|000) sleep 2; i=$((i + 1));;
    *) break;;
  esac
done
echo "navidrome is up on :${ND_PORT} (HTTP ${code:-?})"

if [ -n "${ND_ADMIN_USER:-}" ] && [ -n "${ND_ADMIN_PASSWORD:-}" ]; then
  body="{\"username\":\"$ND_ADMIN_USER\",\"password\":\"$ND_ADMIN_PASSWORD\"}"
  # 200 = admin created, 403 = an admin already exists. Both are fine.
  curl -s --max-time 10 -o /dev/null -w 'createAdmin: %{http_code}\n' \
    -X POST "http://127.0.0.1:${ND_PORT}/auth/createAdmin" \
    -H 'Content-Type: application/json' -d "$body" \
    || echo 'createAdmin: request failed (will retry on next start)'
else
  echo 'ND_ADMIN_USER / ND_ADMIN_PASSWORD not set; skipping admin creation'
fi

wait "$ND_PID"

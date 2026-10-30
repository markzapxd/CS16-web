#!/bin/sh
set -eu
case "$MAP" in ''|*[!a-zA-Z0-9_-]*) printf '%s\n' 'MAP must be a simple map name' >&2; exit 1;; esac
# Proprietary game data must be supplied externally, never downloaded into the image.
for required in /content/valve /content/cstrike /content/valve.zip; do
    if [ ! -e "$required" ]; then printf 'Missing external game data: %s\n' "$required" >&2; exit 1; fi
done
mkdir -p /xashds/valve
cp -rsn /content/valve/. /xashds/valve/
ln -sfn /content/valve.zip /xashds/public/valve.zip
# Link absent files only; do not overwrite supplied configuration. Safe on restart.
cp -rsn /content/cstrike/. /xashds/cstrike/
cp -rsn /content/cstrike/. /xashds/public/cstrike/
if [ -f /content/preload.json ]; then
    cp /content/preload.json /xashds/public/deployment-preload.json
else
    printf '["cstrike/maps/%s.bsp"]\n' "$MAP" > /xashds/public/deployment-preload.json
fi
if [ ! -f "/xashds/cstrike/maps/$MAP.bsp" ]; then
    printf 'Missing map: /content/cstrike/maps/%s.bsp\n' "$MAP" >&2
    exit 1
fi
exec ./xash +ip 0.0.0.0 -port 27015 -game cstrike +map "$MAP" +maxplayers "${MAXPLAYERS:-16}" "$@"

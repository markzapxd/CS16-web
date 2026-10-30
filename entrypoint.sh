#!/bin/sh
set -eu
case "$MAP" in ''|*[!a-zA-Z0-9_-]*) printf '%s\n' 'MAP must be a simple map name' >&2; exit 1;; esac
# First-start init prepares the separate named data volume; custom maps stay external.
DATA_DIR=${DATA_DIR:-/game-data}
for required in "$DATA_DIR/valve" "$DATA_DIR/cstrike" "$DATA_DIR/valve.zip"; do
    if [ ! -e "$required" ]; then printf 'Missing external game data: %s\n' "$required" >&2; exit 1; fi
done
mkdir -p /xashds/valve
cp -rsn "$DATA_DIR/valve/." /xashds/valve/
ln -sfn "$DATA_DIR/valve.zip" /xashds/public/valve.zip
# Custom content precedes release data; image configuration remains authoritative.
cp -rsn /content/cstrike/. /xashds/cstrike/
cp -rsn "$DATA_DIR/cstrike/." /xashds/cstrike/
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

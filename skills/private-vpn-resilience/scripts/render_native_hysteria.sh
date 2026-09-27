#!/bin/sh
set -eu

SOURCE=${1:?Usage: render_native_hysteria.sh CLIENT_MATERIAL.json [TARGET]}
TARGET=${2:-/opt/etc/hysteria-native/config.json}
HOP_PORTS=${HOP_PORTS:-20000-20100}

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[ -r "$SOURCE" ] || { echo "Cannot read $SOURCE" >&2; exit 1; }

server=$(jq -er '.server | select(type == "string" and length > 0)' "$SOURCE")
auth=$(jq -er '.auth | select(type == "string" and length > 0)' "$SOURCE")
sni=$(jq -er '.sni | select(type == "string" and length > 0)' "$SOURCE")
obfs=$(jq -er '.obfsPassword | select(type == "string" and length > 0)' "$SOURCE")

case "$HOP_PORTS" in
    *[!0-9-]*|*-*-*) echo "Invalid HOP_PORTS: $HOP_PORTS" >&2; exit 1 ;;
esac

target_dir=${TARGET%/*}
[ "$target_dir" != "$TARGET" ] || target_dir=.
mkdir -p "$target_dir"
umask 077
tmp="$TARGET.tmp.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

jq -n \
  --arg server "$server:$HOP_PORTS" \
  --arg auth "$auth" \
  --arg sni "$sni" \
  --arg obfs "$obfs" \
  '{
    server: $server,
    auth: $auth,
    tls: {sni: $sni},
    obfs: {type: "salamander", salamander: {password: $obfs}},
    quic: {maxIdleTimeout: "30s", keepAlivePeriod: "10s"},
    transport: {type: "udp", udp: {minHopInterval: "10s", maxHopInterval: "20s"}},
    congestion: {type: "bbr", bbrProfile: "standard"},
    socks5: {listen: "127.0.0.1:1082", disableUDP: false}
  }' > "$tmp"

if [ -f "$TARGET" ]; then
    cp -p "$TARGET" "$TARGET.bak"
fi
chmod 600 "$tmp"
mv "$tmp" "$TARGET"
trap - EXIT HUP INT TERM
echo "Prepared $TARGET"

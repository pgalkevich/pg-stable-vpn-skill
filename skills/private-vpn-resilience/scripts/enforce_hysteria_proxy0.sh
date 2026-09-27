#!/bin/sh
set -eu

SETTINGS=${AWGM_SETTINGS:-/opt/etc/awg-manager/settings.json}

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[ -r "$SETTINGS" ] || { echo "Cannot read $SETTINGS" >&2; exit 1; }

if [ "$(jq -r '.createNDMSProxyForSingbox // false' "$SETTINGS")" != false ]; then
    stamp=$(date +%Y%m%d-%H%M%S)
    cp -p "$SETTINGS" "$SETTINGS.bak-$stamp"
    tmp="$SETTINGS.tmp.$$"
    trap 'rm -f "$tmp"' EXIT HUP INT TERM
    jq '.createNDMSProxyForSingbox = false' "$SETTINGS" > "$tmp"
    chmod --reference="$SETTINGS" "$tmp" 2>/dev/null || chmod 600 "$tmp"
    mv "$tmp" "$SETTINGS"
    trap - EXIT HUP INT TERM
fi

ndmc -c 'interface Proxy0 description Hysteria2-Native-PortHop'
ndmc -c 'interface Proxy0 proxy upstream 127.0.0.1 1082'
ndmc -c 'interface Proxy0 ping-check profile Hy2Native'
ndmc -c 'interface Proxy0 up'
ndmc -c 'system configuration save'

config=$(ndmc -c 'show running-config')
block=$(printf '%s\n' "$config" | sed -n '/^interface Proxy0$/,/^!$/p')
printf '%s\n' "$block" | grep -q 'proxy upstream 127.0.0.1 1082'
printf '%s\n' "$block" | grep -q 'ping-check profile Hy2Native'

echo "Proxy0 invariant enforced: native 127.0.0.1:1082 with Hy2Native"

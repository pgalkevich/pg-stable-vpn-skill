#!/bin/sh
set -u

CONFIG=${AWG_PORT_HOPPER_CONFIG:-/opt/etc/awg-port-hopper.conf}
AWG=/opt/sbin/awg
HEXDUMP=/opt/bin/hexdump

if [ ! -r "$CONFIG" ]; then
    echo "Missing configuration: $CONFIG" >&2
    exit 1
fi

# shellcheck source=/dev/null
. "$CONFIG"

: "${AWG_INTERFACE:?Set AWG_INTERFACE}"
: "${AWG_SERVER:?Set AWG_SERVER}"
: "${AWG_PORT_MIN:?Set AWG_PORT_MIN}"
: "${AWG_PORT_MAX:?Set AWG_PORT_MAX}"
: "${AWG_MIN_INTERVAL:?Set AWG_MIN_INTERVAL}"
: "${AWG_MAX_INTERVAL:?Set AWG_MAX_INTERVAL}"

random_between() {
    low=$1
    high=$2
    span=$((high - low + 1))
    value=$($HEXDUMP -n 2 -e '1/2 "%u\n"' /dev/urandom)
    echo $((low + value % span))
}

last_port=0
while :; do
    if [ -d "/sys/class/net/$AWG_INTERFACE" ]; then
        peer=$($AWG show "$AWG_INTERFACE" peers 2>/dev/null | sed -n '1p')
        if [ -n "$peer" ]; then
            port=$(random_between "$AWG_PORT_MIN" "$AWG_PORT_MAX")
            if [ "$port" -eq "$last_port" ]; then
                port=$((AWG_PORT_MIN + (port - AWG_PORT_MIN + 1) % (AWG_PORT_MAX - AWG_PORT_MIN + 1)))
            fi
            if $AWG set "$AWG_INTERFACE" peer "$peer" endpoint "$AWG_SERVER:$port"; then
                echo "$(date -Iseconds) endpoint=$AWG_SERVER:$port"
                last_port=$port
            fi
        fi
    fi
    sleep "$(random_between "$AWG_MIN_INTERVAL" "$AWG_MAX_INTERVAL")"
done

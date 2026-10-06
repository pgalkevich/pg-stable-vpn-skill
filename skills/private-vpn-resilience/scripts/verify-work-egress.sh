#!/bin/sh
set -eu
unset LD_LIBRARY_PATH

expected=${1:-}
proxy=${2:-socks5h://127.0.0.1:1086}
curl_bin=${CURL_BIN:-/opt/bin/curl}

if [ -z "$expected" ]; then
    echo "usage: $0 EXPECTED_EXIT_IPV4 [PROXY_URL]" >&2
    exit 64
fi

case "$expected" in
    *[!0-9.]*|'')
        echo "invalid expected IPv4: $expected" >&2
        exit 64
        ;;
esac

if [ ! -x "$curl_bin" ]; then
    echo "curl not found or not executable: $curl_bin" >&2
    exit 69
fi

observed=$(
    "$curl_bin" --silent --show-error --fail \
        --connect-timeout 8 --max-time 20 \
        --proxy "$proxy" \
        https://1.1.1.1/cdn-cgi/trace |
        awk -F= '$1 == "ip" { print $2; exit }'
)

if [ -z "$observed" ]; then
    echo "no exit IPv4 returned through $proxy" >&2
    exit 1
fi

if [ "$observed" != "$expected" ]; then
    echo "FAIL expected=$expected observed=$observed proxy=$proxy" >&2
    exit 1
fi

echo "PASS expected=$expected observed=$observed proxy=$proxy"

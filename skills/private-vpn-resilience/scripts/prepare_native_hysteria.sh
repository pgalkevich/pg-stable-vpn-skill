#!/bin/sh
set -eu

SOURCE=${SOURCE:-/opt/etc/awg-manager/singbox/config.d/10-tunnels.json}
TARGET_DIR=${TARGET_DIR:-/opt/etc/hysteria-native}
TARGET="$TARGET_DIR/config.json"
HOP_PORTS=${HOP_PORTS:-20000-20100}

json_value() {
    key="$1"
    occurrence="$2"
    grep "\"$key\"" "$SOURCE" | sed -n "${occurrence}p" | sed -E 's/^[^:]*:[[:space:]]*//; s/,[[:space:]]*$//'
}

server=$(json_value server 1 | tr -d '"')
port=$(json_value server_port 1)
obfs_password=$(json_value password 1)
auth_password=$(json_value password 2)
sni=$(json_value server_name 1 | tr -d '"')

test -n "$server"
test -n "$port"
test -n "$obfs_password"
test -n "$auth_password"
test -n "$sni"

mkdir -p "$TARGET_DIR"
umask 077
if [ -f "$TARGET" ]; then
    cp "$TARGET" "$TARGET.bak"
fi

printf '%s\n' \
  '{' \
  "  \"server\": \"$server:$HOP_PORTS\"," \
  "  \"auth\": $auth_password," \
  '  "tls": {' \
  "    \"sni\": \"$sni\"" \
  '  },' \
  '  "obfs": {' \
  '    "type": "salamander",' \
  '    "salamander": {' \
  "      \"password\": $obfs_password" \
  '    }' \
  '  },' \
  '  "quic": {' \
  '    "maxIdleTimeout": "30s",' \
  '    "keepAlivePeriod": "10s"' \
  '  },' \
  '  "transport": {' \
  '    "type": "udp",' \
  '    "udp": {' \
  '      "minHopInterval": "10s",' \
  '      "maxHopInterval": "20s"' \
  '    }' \
  '  },' \
  '  "congestion": {' \
  '    "type": "bbr",' \
  '    "bbrProfile": "standard"' \
  '  },' \
  '  "socks5": {' \
  '    "listen": "127.0.0.1:1082",' \
  '    "disableUDP": false' \
  '  }' \
  '}' > "$TARGET"

chmod 600 "$TARGET"
echo "Prepared $TARGET"

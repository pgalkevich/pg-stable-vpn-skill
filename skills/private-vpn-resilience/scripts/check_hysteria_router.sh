#!/bin/sh
set -u

echo "== time =="
date

echo "== native service =="
/opt/etc/init.d/S98hysteria-native status

echo "== listeners and sessions =="
netstat -lntup 2>/dev/null | grep ':1082' || true
netstat -anup 2>/dev/null | grep ':8443' || true

echo "== Proxy0 =="
ndmc -c 'show interface Proxy0' 2>/dev/null | grep -E 'link:|connected:|state:|uptime:|conf:|ipv4:|ctrl:' || true

echo "== Ping Check =="
ndmc -c 'show ping-check' 2>/dev/null | sed -n '/profile: Hy2Native/,$p' | head -n 80

echo "== IPv4 request through full Proxy0 path =="
/opt/bin/curl -4 -sS --max-time 10 --interface t2s0 \
  -o /dev/null -w 'youtube=%{http_code} time=%{time_total}s local=%{local_ip}\n' \
  https://www.youtube.com/generate_204

echo "== router UDP counters =="
cat /proc/net/snmp | grep '^Udp:'

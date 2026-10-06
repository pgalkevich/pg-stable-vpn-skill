# Hysteria2 procedure

## Server invariants

- UDP 8443 is the accepted Hysteria2 listener.
- UDP 20000-20100 is the router client's port-hopping range. The dedicated
  `hysteria_port_hop` nftables table redirects it to UDP 8443; direct 8443
  access remains available for HAPP and rollback.
- TLS certificate includes the deployed server identity as a valid SAN and must be renewed before expiry.
- Salamander obfuscation and client authentication values must match the protected 3x-ui/Xray configuration.
- Keep `net.core.rmem_default` and `net.core.wmem_default` at 16 MiB and maxima at 32 MiB unless measurements justify another value.
- A server restart intentionally closes QUIC. Confirm the router client automatically recovers afterward.

Useful read-only checks:

```sh
sysctl net.core.rmem_default net.core.rmem_max net.core.wmem_default net.core.wmem_max
ss -uapnmi | grep -A2 ':8443'
cat /proc/net/snmp | grep '^Udp:'
systemctl show x-ui -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp
```

Compare both `RcvbufErrors` and the final socket `drops` field before and after a load test.

## Router native client

The current deployment's accepted candidate is official Hysteria v2.12.3 for
linux/arm64. This is an observed snapshot, not a fresh-install pin. A new
bootstrap must resolve and install the newest stable official release, verify
its current upstream checksum, and rerun all compatibility and soak tests.

The checksum recorded for the currently deployed binary is:

```text
c8dc653c3ba0a28d29a26b8fa52d2086f27c0927afddce95c09965e7174e78b0
```

For a clean bootstrap, create a root-only client-material JSON with `server`,
`auth`, `sni`, and `obfsPassword`, then run
`scripts/render_native_hysteria.sh`. It deterministically writes the accepted
native configuration: `127.0.0.1:1082`, 10-second keepalive, BBR standard, and
random hopping across UDP 20000-20100 every 10-20 seconds. Remove the material
file immediately afterward. `prepare_native_hysteria.sh` remains only a
migration helper for an existing protected AWG Manager Sing-box profile.

Install `scripts/hysteria-port-hop.nft` as `/etc/nftables.d/hysteria-port-hop.nft` and `scripts/hysteria-port-hop.service` as `/etc/systemd/system/hysteria-port-hop.service` on the VPS, then enable the service. Do not enable the stock `nftables.service` without first removing the `flush ruleset` line from `/etc/nftables.conf`, because that can erase Docker-managed rules.

Do not set guessed `bandwidth` values. A tested 20/100 Mbps Brutal configuration reduced throughput sharply and was rejected.

Use `scripts/S98hysteria-native` as the Entware startup service. Verify it with:

```sh
/opt/etc/init.d/S98hysteria-native restart
/opt/etc/init.d/S98hysteria-native status
netstat -lntup | grep ':1082'
```

The Keenetic proxy interface remains independent of the Hysteria implementation. Its relevant configuration is:

```text
interface Proxy0
    proxy protocol socks5
    proxy upstream 127.0.0.1 1082
    proxy socks5-udp
    up
```

Do not switch `Proxy0` back to port 1080. Test the former Sing-box client only
through its direct SOCKS endpoint when diagnostic comparison is needed.

Use a Keenetic Ping Check profile so the proxy interface participates in failover instead of remaining falsely healthy:

```text
ping-check profile Hy2Native
ping-check profile Hy2Native host www.gstatic.com
ping-check profile Hy2Native update-interval 10
ping-check profile Hy2Native mode tls
ping-check profile Hy2Native max-fails 2
ping-check profile Hy2Native min-success 1
interface Proxy0 ping-check profile Hy2Native
system configuration save
```

Create the profile with the first command before setting its fields; Keenetic rejects field commands for an unknown profile.

## Tests

Direct native SOCKS test:

```sh
curl -4 --max-time 10 --proxy socks5h://127.0.0.1:1082 \
  -o /dev/null -w '%{http_code} %{time_total}\n' \
  https://www.youtube.com/generate_204
```

Full `Proxy0`/tun2socks path test:

```sh
curl -4 --max-time 10 --interface t2s0 \
  -o /dev/null -w '%{http_code} %{time_total}\n' \
  https://www.youtube.com/generate_204
```

Force IPv4 in router-side tests because the VPS does not currently provide IPv6 egress. A test without `-4` may select an IPv6 destination and time out even when IPv4 Hysteria is healthy.

## Recovery after accidental deletion

If the 3x-ui Hysteria inbound or its clients are deleted, restore the accepted
production path first. Recovery is complete only when the official native
client works on port 1082, `Proxy0` still points to 1082 with `Hy2Native`
attached, and the full `t2s0` path passes the verification gates. A visible
AWG Manager Sing-box tunnel is a separate optional diagnostic object and must
never be treated as the production route.

Create or update-in-place an enabled Hysteria v2 inbound on UDP 8443 with UDP
idle timeout 60 seconds, Salamander, TLS `h3`, SNI equal to the certificate
identity, and the existing valid certificate paths. Create one router client.
Render the native client configuration directly from those protected client
fields; do not require a Sing-box import as an intermediate source of truth.

If the user also requests a visible diagnostic Sing-box tunnel, first set
`createNDMSProxyForSingbox` to `false`. AWG Manager and Sing-box have separate
process lifecycles. Restarting `S99awg-manager` alone may leave the old Sing-box
PID and its stale in-memory credentials untouched. After the generated slot
contains the new values, use the authenticated router API:

```text
POST /api/singbox/control
Content-Type: application/json
{"action":"restart"}
```

Confirm that the Sing-box PID changes, local port 1080 answers a SOCKS5 YouTube
HTTP 204 request, and the AWG Manager tunnel card shows `RUNNING` plus a finite
delay. Back up `10-tunnels.json` before forcing the restart. Then run
`enforce_hysteria_proxy0.sh` and confirm from `show running-config` that the
diagnostic object did not bind `Proxy0` to port 1080.

On the router, back up `/opt/etc/hysteria-native/config.json`, replace only
`auth` and `obfs.salamander.password`, and preserve the accepted native settings:
server port range 20000-20100, 10-20 second hopping, QUIC keepalive, BBR standard,
and SOCKS5 `127.0.0.1:1082`. Restart `S98hysteria-native`, verify direct SOCKS
and full `t2s0` HTTP 204 checks, then remove every temporary secret file from
the VPS, management machine, and router. `Proxy0` must continue to point to the
accepted native port 1082 even though the separately verified Sing-box tunnel
listens on port 1080.

In a controlled server restart test, the native client reported two failed requests during QUIC failure detection and reconnected automatically about one minute later without a router-side restart. The `Hy2Native` profile marks `Proxy0` unavailable after approximately 20 seconds so HydraRoute can use another transport during this window.

The Let's Encrypt IP certificate uses the short-lived profile. `acme.sh` runs every six hours, has a configured reload command, and scheduled renewal was visible before expiry. Recheck both the renewal schedule and reload hook during audits.

### Mandatory post-AWG-Manager invariant

AWG Manager can overwrite a manually accepted Keenetic proxy when
`createNDMSProxyForSingbox` is enabled. After every install, upgrade, import,
refresh, or restart, verify all of the following from live state—not from the
tunnel card:

```text
createNDMSProxyForSingbox = false
Proxy0 upstream = 127.0.0.1:1082
Proxy0 ping-check profile = Hy2Native
direct native SOCKS request = HTTP 204
full t2s0 request = HTTP 204
```

If the UI says Sing-box is `RUNNING` but `Proxy0` points to 1080, treat the
installation as failed and restore the invariant before any soak test.

## Fallback is not an instability fix

Selecting VLESS as primary does not prove that Hysteria stalls are resolved.
Preserve the native client, port hopping, and its health profile while
collecting correlated request timings, Ping Check events, QUIC logs, UDP
receive-buffer counters, and packet captures. A short failed health check
without QUIC reconnect or growing drops proves neither DPI nor a false probe.
Keep the diagnosis open until measurements identify the cause; do not apply
speculative tuning merely because the transport is now a fallback.

## Known failure signature

The rejected sing-box client failure presents as:

- AWG Manager delay is `timeout` while process state is `RUNNING`.
- UDP socket to the VPS still exists.
- New outbound requests appear in the log but hang.
- No useful error is logged.
- Restarting sing-box changes the UDP source port and immediately restores connectivity.

Do not mistake that signature for a stopped daemon or server authentication failure.

The same persistent-flow failure was reproduced with the official native client: after about one minute of YouTube playback, `Proxy0` remained administratively up but became `ipv4: pending`, `Hy2Native` failed, and both direct SOCKS and `t2s0` requests timed out. The VPS still received and returned UDP packets with zero socket drops and no increase in `RcvbufErrors`; opening a new client UDP flow restored traffic immediately. Treat this as path/DPI interference with a persistent UDP flow, not an AWG Manager UI-state error. Port hopping is the selected mitigation.

## DPI and camouflage model

Do not assume that every timeout is a configuration fault. The observed
combination of healthy processes, bidirectional packets, frozen kernel-drop
counters, a stalled established flow, and immediate recovery on a new UDP flow
is consistent with per-flow throttling or DPI intervention. It is strong
circumstantial evidence, not proof of the provider's exact classifier.

The accepted Hysteria candidate already uses Salamander, which removes stable
QUIC packet bytes by scrambling packets, plus randomized port hopping. This is
the preferred first variant for the router. Port hopping specifically targets
blocking of persistent UDP tuples; it does not help if the access network
blocks UDP broadly.

Potential follow-up variants must be tested as separate candidates rather than
silently replacing the rollback path:

- Gecko adds randomized fragmentation and padding to QUIC handshake datagrams
  on top of Salamander. Test it on a separate inbound/client pair before
  adoption because it adds overhead and implementation-compatibility risk.
- Hysteria Mimic makes packets appear to be TCP, but requires Linux, root, and
  working eBPF/XDP support on both endpoints. It cannot be combined with port
  hopping and is unsuitable for the macOS/iOS HAPP path. Treat it only as a
  router-specific experiment after checking the Keenetic kernel capabilities.
- Ordinary HTTP/HTTPS masquerade on TCP 80/443 is a server-probing measure; it
  does not by itself repair a throttled established UDP flow.

Prefer transport diversity over one supposedly universal disguise: retain
Hysteria with UDP obfuscation, VLESS Reality as a web-like TCP/TLS path, and
AmneziaWG as an independently obfuscated WireGuard-family path.

## Additional client for a Keenetic-hosted server

Use the existing official native binary with a separate protected config,
process, and local endpoint:

- server `<server-public-address>:8443` over UDP;
- SOCKS5 `127.0.0.1:1084`;
- config `/opt/etc/hysteria-home/config.json`;
- service `/opt/etc/init.d/S96hysteria-home`;
- Keenetic interface `Proxy2`, description `Home-Hysteria2`;
- TLS Ping Check `HomeHy2` against `www.gstatic.com`.

The subscription provides a SHA-256 certificate pin for a certificate that is
not trusted by the router system CA store. The native config must therefore
set both `tls.insecure=true` and `tls.pinSHA256=<subscription pin>`; using
`insecure` without the pin is forbidden. Without `insecure`, the client fails
before the pin is evaluated with `certificate signed by unknown authority`.
Do not copy the fingerprint into this reference.

After a controlled service restart, verify Google HTTP 204 and the expected
server egress address through `Proxy2`. Test relevant applications separately;
a service-specific failure with successful generic HTTPS and public-IP checks
is not by itself proof that the Hysteria transport is down.

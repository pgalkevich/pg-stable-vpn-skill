# VLESS Reality procedure

## VLESS-primary Keenetic example

Preserve the user-agreed priorities and each account's flow. This example
uses Vision and Firefox; a separate no-flow account must remain independent.

- VPS: Xray 26.9.9, VLESS TCP 443, REALITY, XTLS Vision.
- Camouflage target and SNI: `www.samsung.com:443`.
- Router: official Xray 26.9.9 linux/arm64 client.
- Local router SOCKS5 endpoint: `127.0.0.1:1083`.
- Keenetic interface: `Proxy1`.

These versions describe the current deployment. For a fresh bootstrap, install
the newest stable 3x-ui/Xray and newest stable official router Xray available at
execution time, then repeat the REALITY compatibility and direct-path DPI tests.
Do not pin a new installation to 26.9.9 solely because it is recorded here.

Keep UUID, Reality private/public keys, short ID, and subscription URLs only in
protected live configuration. Never write them into this skill.

## Compatibility finding

Xray server 26.9.9 requires a REALITY ClientHello containing the hybrid
`X25519MLKEM768` key share before optional X25519. The AWG Manager custom
sing-box `1.15.0-alpha.8-awgm.27` does not emit a compatible handshake. Its
exact failure is `reality verification failed`, even when the UUID, public key,
short ID, SNI, fingerprint, and Vision flow match.

Do not diagnose this signature as a bad server key or blocked TCP 443 without
an A/B client-core test. The same protected profile was tested from the router:
sing-box failed, while official Xray 26.9.9 immediately returned HTTP 204 from
YouTube and Google.

Do not downgrade the VPS Xray merely for old sing-box compatibility: the live
Hysteria configuration depends on fixes in Xray 26.9.9. Use a matching current
Xray client on the router instead.

## Router installation

Use the official `Xray-linux-arm64-v8a.zip` release for v26.9.9. The verified
archive SHA-256 is:

```text
3e38d72dfc5eb65c91df0e5583e9b6676c32232041da47de6ae73946b526d66c
```

Install the binary as `/opt/bin/xray-vless`, the protected client JSON as
`/opt/etc/xray-vless/config.json` with mode 0600, and
`scripts/S97xray-vless` as `/opt/etc/init.d/S97xray-vless`.

The client JSON uses a local SOCKS inbound and one VLESS outbound with:

```text
protocol: vless
network: tcp
security: reality
flow: xtls-rprx-vision
fingerprint: firefox
serverName: www.samsung.com
```

Also verify the fingerprint exported by the panel, not only the router JSON.
For this tested Firefox path, keep
`realitySettings.settings.fingerprint=firefox` in the panel's inbound
subscription metadata. A working router does not prove that HAPP imported
the same fingerprint. Refresh/reimport an existing HAPP profile after fixing
the export, or set Firefox manually. Preserve each client's server-side flow:
a separate no-flow account must not inherit the router account's Vision.

## Verification

```sh
/opt/bin/xray-vless run -test -config /opt/etc/xray-vless/config.json
/opt/etc/init.d/S97xray-vless restart
/opt/etc/init.d/S97xray-vless status
curl -4 --max-time 15 --proxy socks5h://127.0.0.1:1083 \
  -o /dev/null -w '%{http_code} %{time_total}\n' \
  https://www.youtube.com/generate_204
```

Attach a dedicated TLS Ping Check profile to `Proxy1`. The interface must be
marked unavailable after real SOCKS/VLESS failure, rather than only checking
whether the local Xray process still exists.

## Direct-path DPI finding

Do not accept tests made while another VPN is active on the test device. An
initial HAPP connection test was invalidated because AmneziaVPN was active on
the Mac at the same time.

Use the management computer only for management while its local VPN is active.
Perform router-path acceptance on a separate device with no local VPN so its
traffic can leave only through HydraRoute. During an isolated VLESS test keep
both `OpkgTun10` and `Proxy0` administratively disabled and verify that
`Proxy1` is `up/running` before judging application behavior.

With both `OpkgTun10` and `Proxy0` disabled, a Chrome-fingerprint REALITY
ClientHello reached TCP 443 directly but stalled after the VPS acknowledged
the first 1408-byte TCP segment; the remaining ClientHello bytes did not reach
the capture. The socket stayed `ESTABLISHED` with queued unsent data. This is
consistent with path/DPI handling of the large hybrid Chrome ClientHello.

Changing only the router client's uTLS fingerprint to `firefox` immediately
allowed direct HTTP 204 responses without Hysteria. A six-request synthetic
follow-up returned four successes and two handshake timeouts, but the later
clean real-world test on the separate laptop remained connected without drops.
The user accepts this VLESS path for normal use. It is somewhat slower than
Hysteria and YouTube occasionally lowers quality, so treat throughput as a
known characteristic rather than a disconnect. Reopen diagnosis only when new
failures or materially worse performance are observed.

`xtls-rprx-vision` intentionally rejects proxied UDP/443 so browsers fall back
from QUIC to TCP HTTPS. Seeing `XTLS rejected UDP/443 traffic` in an info-level
client log is expected for this flow; judge service health using subsequent
TCP fallback and application behavior.

## Keenetic as the public VLESS server

In one tested Keenetic deployment, inbound TCP/443 was filtered upstream: SYN
packets from an independent VPS timed out
and did not appear in a capture on the router WAN interface, despite Xray
listening and the local INPUT rule accepting the port. Do not treat this
signature as a REALITY or HAPP configuration failure.

The verified port workaround is VLESS REALITY on TCP/8443. It can coexist with
Hysteria2 on UDP/8443 because TCP and UDP sockets are independent. Preserve
the Firefox fingerprint and `www.samsung.com:443` Reality target/SNI, and allow
TCP/8443 on the WAN firewall.

Acceptance was performed from an independent external VPS with official Xray
26.9.9 using the generated subscription profile. TCP/8443 connected, the
REALITY handshake completed, and public-IP checks reported the expected router
address. Refresh or re-add the subscription in the client after the port
change; the subscription URL itself does not change.

The final HAPP/macOS acceptance profile for this router-as-server deployment
omits the VLESS `flow` value (no `xtls-rprx-vision`). With Vision enabled, the
HAPP session was usable but browsing was very slow and the router accumulated
hundreds of TCP/8443 sockets from that one client, including many in
`CLOSE_WAIT`. Setting Xray level-0 `connIdle` to 60 seconds with 4-second
handshake and 2-second uplink/downlink-only timeouts did not by itself prevent
the accumulation. Removing only the Vision flow, refreshing the subscription,
and reconnecting made normal browsing responsive; the user explicitly
accepted that configuration as working.

The accepted router-server parameters are therefore: Xray 26.9.9, VLESS over
TCP/8443, REALITY, no flow, Firefox fingerprint, and
`www.samsung.com:443` target/SNI. This does not replace the separate
router-as-client finding above, where the tested VPS path uses
`xtls-rprx-vision`.

## Rollback

Stop `S97xray-vless`, remove `Proxy1` from HydraRoute, and keep the server
inbound untouched. This rollback does not affect Hysteria on `Proxy0` or
AmneziaWG on `OpkgTun10`.

## Additional client for a Keenetic-hosted server

The client uses the official router Xray binary with a separate protected
config `/opt/etc/xray-home/config.json` and service
`/opt/etc/init.d/S96xray-home`. It listens on SOCKS5 `127.0.0.1:1085` and is
exposed as Keenetic `Proxy3` with Ping Check `HomeVless`.

Preserve the home server's accepted client parameters exactly: TCP/8443,
REALITY, no VLESS flow, Firefox fingerprint, and `www.samsung.com` SNI. Do not
reuse the `xtls-rprx-vision` setting from the unrelated VPS path on `Proxy1`.
Validate the config with the installed Xray version. After a controlled service
restart, require Google HTTP 204 and the expected server egress address through
the full `t2s3` path.

## ASUS strict-work client

Use the official Xray client behind a sing-box TPROXY frontend on
Asuswrt-Merlin/GNUton when the user explicitly chooses a single VLESS path.
Read [asuswrt-merlin.md](asuswrt-merlin.md) for lifecycle and restart gates.
Keep the protected profile's server port, REALITY identity, SNI, fingerprint,
and per-account flow; a working no-flow server profile must not inherit Vision
from the separate Keenetic/VPS example.

Use localhost SOCKS5 (example `127.0.0.1:1090`) as the boundary between Xray
and sing-box. Route LAN TPROXY, the main acceptance listener (example
`127.0.0.1:1086`), protected DoH, and the final public route through Xray.
Install `scripts/S95asus-xray-vless` as `/opt/etc/init.d/S95xray-vless`.
Resolve the newest stable official release for the router architecture and
verify its digest; do not pin a replacement USB to a historical binary.

Start Xray before sing-box. After an isolated TLS and exact-exit test, repeat
restart, 5–30 minute soak, bounded-load, and separate no-local-VPN LAN gates.
Stopping Xray must fail the main proxy while the LAN-to-WAN kill switch stays
attached and router-originated management SSH remains reachable. Disable the
old selector cron in single-path mode; keep timestamped rollback copies of
previous transports until LAN acceptance. There is no fallback transport.

When an exit-IP service contradicts all transport results, require agreement
from independent services (for example AWS Check IP, ident.me, and icanhazip)
rather than changing working routing based on one oracle.

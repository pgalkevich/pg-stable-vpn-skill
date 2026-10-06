# Strict work profile: Russian egress only

Use this profile when a router is dedicated to work and every device attached
to it must reach the Internet exclusively through one user-approved Russian
public IPv4.

## Required invariant

Obtain `EXPECTED_EXIT_IPV4` before deployment. It is either:

- the public IPv4 of the user's home VPN server; or
- the public IPv4 of a user-controlled Russian VPS.

Do not infer or approve an address solely from GeoIP. By default there is one
exact allowed egress IPv4. If the user intentionally wants several Russian
exits, require an explicit allowlist and test every address separately.

All LAN Internet traffic must use the selected VPN path or selector. Do not create per-device,
per-domain, entertainment-service, or split-tunnel policies. Private LAN and
router-management destinations may remain local, but there must be no direct
WAN fallback for public traffic. Disable IPv6 unless it is explicitly tunneled
and verified against the same egress policy. Use protected DNS through the VPN
so DNS cannot leak to the ISP.

The transport set is independent of the policy. A low-memory ASUS may use
Hysteria2 plus AmneziaWG; another router may use all three transports. An
explicitly selected VLESS-only ASUS profile has no selector failover; require
fail-closed on Xray failure and automatic recovery instead. Every
candidate admitted to the production selector must independently yield the
configured `EXPECTED_EXIT_IPV4`. Do not add a transport that exits from a
different IP merely because it is reachable.

## Deployment sequence

1. Keep the kill switch disabled while testing isolated transports so a
   management mistake does not strand the operator.
2. Test every candidate through its dedicated local listener. Require a real
   TLS response and exact exit-IP equality.
3. Test the normal selector and confirm its preferred transport also yields
   the exact IP.
4. Force the preferred transport to fail. Confirm automatic fallback remains
   online and still yields the exact IP.
   Then restore the primary and verify that failback waits for the configured
   recovery threshold instead of flapping immediately.
5. Confirm protected DNS, TCP and UDP LAN interception, and ensure no IPv6
   bypass exists.
6. Enable fail-closed as the last step. Preserve any already-tested reverse
   SSH management path that originates on the router.
7. Run restart and soak gates, then have the user perform the separate LAN
   test from a device with no local VPN.

Use `scripts/verify-work-egress.sh EXPECTED_EXIT_IPV4 [PROXY_URL]` on a router
with Entware curl. The optional proxy defaults to the accepted ASUS selector
listener `socks5h://127.0.0.1:1086`. Run it again with the isolated Hysteria and
AmneziaWG listener ports when applicable.

On ASUS, set `EXPECTED_EXIT_IPV4` and the measured primary in
`/opt/etc/home-vpn/selector.conf`. Test both isolated transports for latency,
bounded-download throughput, and the real work application before fixing the
order. The current low-memory home-exit deployment uses Hysteria as primary and
AWG as fallback because AWG health checks passed while its userspace throughput
made interactive work impractical. Treat that ordering as a deployment result,
not a universal claim about the protocols.

For an explicitly selected VLESS-only profile, skip selector failover/failback
steps and instead stop Xray, verify fail-closed, and restart it to verify
automatic recovery. Keep all other gates.

## Acceptance matrix

The deployment is accepted only when all applicable rows pass:

| Test | Required result |
| --- | --- |
| Each isolated transport | TLS succeeds; observed IPv4 equals `EXPECTED_EXIT_IPV4` |
| Normal selector | Observed IPv4 equals `EXPECTED_EXIT_IPV4` |
| Forced primary failure (multi-transport) | Fallback recovers automatically and keeps the same exact IPv4 |
| Router/firewall restart | Routing, DNS, selector, and management tunnel recover automatically |
| 5–30 minute soak | Neutral HTTPS and required work services remain stable |
| Separate LAN device with no local VPN | Public IPv4 equals `EXPECTED_EXIT_IPV4` |
| All VPN transports stopped | No Internet and no public DNS; ISP WAN never carries LAN Internet traffic |

YouTube, other blocked entertainment services, and anti-censorship throughput
are outside this profile's acceptance criteria. A failure of one of those
services does not prove the work tunnel is unhealthy. Diagnose only neutral
connectivity, required work services, transport health, exact egress identity,
DNS protection, failover, and fail-closed behavior.

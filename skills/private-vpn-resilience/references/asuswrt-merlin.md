# Asuswrt-Merlin client deployment

Use this branch for ASUS routers running Asuswrt-Merlin or GNUton firmware.
The Keenetic AWG Manager and HydraRoute procedures do not apply.

## Preflight

1. Confirm the exact model, firmware build, CPU architecture, kernel, WAN
   interface, LAN bridge, LAN subnet, IPv6 state, and available JFFS space.
2. Enable custom JFFS scripts and LAN-only SSH. Do not enable WAN SSH.
3. Use `amtm` to format the user-authorized empty USB drive as ext4 with
   journaling, then install Entware to that drive. A format or reboot needs
   explicit authorization and a reconnection plan.
4. Resolve current stable package versions at execution time. Install the
   Entware builds matching `opkg print-architecture`; do not reuse ARM64
   binaries on an `armv7` router.

The accepted RT-AX82U deployment used GNUton `3004.388.11_1-gnuton1`, kernel
`4.1.52`, Entware `armv7sf-k3.2`, and `sing-box-go` `1.13.3`. These are an
observed snapshot, not version pins.

If the management computer may leave the ASUS LAN, establish a restricted
reverse SSH tunnel to a user-controlled bastion before changing forwarding,
DNS, or fail-closed rules. Bind the remote listener to `127.0.0.1`, use a
dedicated key restricted to port forwarding and the exact listen port, keep
WAN SSH and WAN web administration disabled, and verify reconnect after a
router reboot. The reverse tunnel is management traffic originating on the
router and must not be captured by the LAN-only TPROXY chain.
Use `ExitOnForwardFailure=yes` in the reverse client. If a listener remains on
the bastion but no longer produces an SSH banner, identify the exact owning
`sshd` PID for that loopback port, terminate only that stale process, and
verify that the router's supervised reverse client recreates the listener.

## Components

- Use Entware `sing-box-go` for Hysteria2, transparent TPROXY routing, selector
  failover, and protected DNS forwarding.
- Use native Xray only when the REALITY share link cannot be represented by
  the installed sing-box schema or when server-side diagnostics require it.
- For AmneziaWG on ARM32 Merlin, use a userspace implementation; ordinary
  WireGuard silently discards the AWG obfuscation parameters. The
  `r0otx/asuswrt-merlin-amneziawg` addon is suitable only when its daemon and
  configuration tool support every field in the supplied profile. A profile
  containing `HeaderProtectionKey`, `ContentPaddingAddition`, randomized
  timings, `RandomTrailers`, or `DisableCookies` requires AWG 3.1. Do not use
  an older kernel module merely because it creates an interface: the observed
  failure was TX and handshakes without useful RX traffic.

### Low-memory two-protocol profile

When the user explicitly omits Xray, run only Hysteria2 and AmneziaWG. Keep
both executables, configurations, logs, and swap on the Entware USB mount under
`/opt`; runtime processes still consume RAM. Create a 512 MiB swap file on the
USB before starting both Go daemons and set swappiness to 10 with
`scripts/S00asus-swapfile`. Swap is a safety margin, not a target working set.
Create the file once only after confirming at least 1 GiB free on the `/opt`
filesystem, format it with `mkswap`, set mode `0600`, then let the service
activate it at boot.
The accepted RT-AX82U used about 248 MiB RAM excluding cache and only 132 KiB
swap during the five-minute dual-transport soak.

For AWG 3.1 on ARMv7:

1. Resolve the newest stable tag of the official
   `amnezia-vpn/amneziawg-go` repository at execution time and record the tag,
   commit SHA, build image digest, target architecture, and output SHA-256.
2. Cross-compile a static `linux/arm` `GOARM=7` binary from that exact commit.
   Do not trust the embedded version string alone; the observed official
   `v3.1.20260828` source still printed an older version string.
3. Build `scripts/asus-awg-uapi-config.go` for the same target. It applies the
   protected profile through `/var/run/amneziawg/<interface>.sock` without
   exposing key material in process arguments.
4. Install both binaries under `/opt/home-vpn/bin`, mode `0700`, and the
   protected client profile under `/opt/etc/home-vpn`, mode `0600`. Use
   `scripts/S96asus-awg3-userspace` as
   `/opt/etc/init.d/S96awg3-userspace`.
5. Test AWG through a source-specific route table before attaching it to
   sing-box. A recent handshake is insufficient; require a real HTTPS request
   and increasing RX and TX counters.

Every simultaneously active router needs a distinct AWG peer, private key,
and tunnel address. Reusing the same peer on two routers makes the server roam
the endpoint between them: both can show handshakes while useful replies go to
the other router. Add a new client without changing the server-wide AWG 3.1
parameters or the existing peer. Prefer the panel API; if an embedded 3x-ui
build requires a database update, make a consistent SQLite backup first and
update the normalized client records, inbound association, traffic row, and
inbound JSON atomically. Restart only the affected panel service and verify the
old and new peer records before deleting temporary key files.

## Protected profile rendering

Keep subscription links and rendered configurations in mode `0600` files.
Parse only the selected transport links locally and render live JSON without
printing credentials, then transfer it with legacy SCP (`scp -O`) because
Merlin's Dropbear may not provide an SFTP server.

For a legacy addon-compatible AWG profile, import a protected `.conf` with
`scripts/import_awg_asus.sh`. Do not use that importer for AWG 3.1: install the
profile directly for the userspace service. BusyBox `tr -d '[:space:]'`
corrupts IPv6 values such as `::/0` by deleting colons. Use a POSIX character
class through `sed`, as the reviewed helper does.

## Transparent routing

Use `scripts/S97asus-home-vpn-two-protocol` as
`/opt/etc/init.d/S97home-vpn` in low-memory mode. It creates a LAN-only TPROXY
chain, mark `0x66`, and routing table `166`; it does not intercept
router-originated control traffic or private destinations. Adapt the LAN
bridge and ports only after checking for conflicts.

The accepted two-protocol listener layout is:

- TPROXY TCP/UDP on `0.0.0.0:7893`;
- local mixed acceptance test on `127.0.0.1:1086`;
- Hysteria-only acceptance test on `127.0.0.1:1087`;
- AWG-only acceptance test on `127.0.0.1:1088`;
- Clash API on `127.0.0.1:9090` for health inspection;
- protected router DNS on `127.0.0.1:5354`.

Render the Hysteria credentials from the protected share link, then use these
non-secret structural invariants in sing-box:

```json
{
  "outbounds": [
    {"type": "hysteria2", "tag": "hy2"},
    {"type": "direct", "tag": "awg", "bind_interface": "awg3"},
    {"type": "selector", "tag": "vpn", "outbounds": ["hy2", "awg"],
     "default": "hy2", "interrupt_exist_connections": false},
    {"type": "direct", "tag": "direct"}
  ]
}
```

Route `hy2-test` only to `hy2`, `awg-test` only to `awg`, and both
`lan-tproxy` and `local-test` to `vpn`; set the route final to `vpn`. Detour the
DoH server through `vpn`, but route private destination ranges through
`direct`. Never bind the `direct` fallback to the WAN interface or include it
in the selector.

Do not use UDP 5353: Avahi already owns it on ASUS. Configure the direct DNS
inbound with a `hijack-dns` route action and a DoH server dialed through a
known-working tunnel. After that query succeeds directly, point dnsmasq at
`127.0.0.1#5354`. Preserve a backup of an existing `dnsmasq.conf.add`, manage a
clearly delimited block, and restart dnsmasq. When using `no-resolv`, install a
watchdog first so DNS does not remain down after a daemon crash.

Use a sing-box selector with `interrupt_exist_connections: false`; a health
transition must not deliberately close unrelated established work sessions.
For an ordinary censorship-resilience profile, Hysteria may remain the
preferred outbound. For a strict work profile, choose the primary only after
measuring request latency, a bounded download, and the real work application
through each isolated listener. A transport that merely passes health probes
but makes interactive work impractical is not acceptable. Configure
`/opt/etc/home-vpn/selector.conf`, mode `0600`; this example is Hysteria-first:

```sh
PRIMARY_OUTBOUND=hy2
EXPECTED_EXIT_IPV4=203.0.113.10
FAIL_THRESHOLD=2
RECOVER_THRESHOLD=15
```

Replace the example address with the user's exact approved exit. The reviewed
`scripts/asus-select-outbound` serializes checks with a lock, records bounded
diagnostics, requires two consecutive failures before failover, and by default
requires fifteen successful primary checks before failback. Use an IP-based
HTTPS target so the health check does not depend on the protected DNS it is
supervising. Exact IP mismatch is a failure in strict-egress mode. The
lifecycle starts the selector at the half-minute so it does not collide with
the watchdog. Enable fail-closed only after both candidate ports, selector
failover, delayed failback, and restart recovery pass.
Render the sing-box selector's `default` to the same outbound as
`PRIMARY_OUTBOUND`; the earlier JSON fragment shows the ordinary Hysteria-first
case, not a fixed default for every profile.

Asus cron may export a firmware `LD_LIBRARY_PATH`. An Entware `curl` can then
load the firmware `libcurl`, emit a version-mismatch warning, lose SOCKS
support, and return error 4 even though both tunnels work. Every Entware
service or health script invoked by cron must unset that variable before
calling Entware binaries. Test the actual scheduled invocation or explicitly
reproduce the cron environment; an interactive SSH success is not sufficient.

The watchdog must be observational while the service is healthy. Do not flush
and recreate TPROXY chains, policy rules, the kill-switch chain, or the AWG
source-route table on every scheduled run. First verify the required process,
socket, interface, rule, route, and iptables hook; repair only a missing
invariant. Confirm with a traced healthy watchdog run that no destructive
firewall or route path executes.

On the ARM32 userspace AWG client, a long-lived UDP flow may retain correct
handshakes and exit identity while throughput degrades substantially. When AWG
is a standby transport, refresh only its userspace service immediately before
selecting it, then require a successful exact-exit probe before changing the
selector. Do not periodically restart a selected AWG path or treat a single CDN
speed sample as a health failure. This selection-time refresh changes the
client UDP source port without modifying server-wide AWG parameters.

The reviewed lifecycle uses `/opt/etc/home-vpn/fail-closed.enabled` as the
explicit production switch. Leave it absent during isolated testing. As the
last deployment step, create it mode `0600`, run `S97home-vpn kill-switch`, and
verify both the `HOMEVPN_KILLSWITCH` FORWARD hook and continued reverse-SSH
reachability. Stopping the VPN while this flag exists must leave LAN forwarding
blocked.

Add `/opt/etc/init.d/S97home-vpn firewall` to Merlin's
`/jffs/scripts/firewall-start`; firmware firewall reloads otherwise erase the
TPROXY chain. Entware starts the `S97` service at boot. Keep the watchdog
idempotent and verify it exists with `cru l`.

## Acceptance and failure localization

Before enabling LAN interception, test each candidate through its own local
listener with a real TLS request. Then verify:

- `sing-box check` passes and the daemon remains alive;
- the selector reports the intended candidate and a forced primary failure
  moves the main listener to the fallback;
- protected DNS returns real A records for a blocked-domain test rather than
  a forged `NXDOMAIN`;
- TPROXY counters increase for an actual LAN client;
- the selected outbound appears in connection logs;
- IPv6 is either proxied or explicitly disabled so it cannot bypass policy;
- boot-style and firewall-style restarts restore listeners, rules, DNS, and
  traffic.

If Hysteria logs `read: message too long`, localize it as a client-side
QUIC/path-MTU symptom before changing the server. Never add a guessed JSON
field: run `sing-box check` against the installed version first. Older builds
may reject newer QUIC path-MTU options. Prefer a verified supported upgrade or
the stable alternate transport while retaining Hysteria as fallback.

Do not require YouTube as a universal health target. A private home exit may
itself be on a network where YouTube is filtered even though the tunnel is
healthy. Correlate a neutral HTTPS target, the requested work service, and the
exit IP. In the accepted home-exit trial Gstatic and Cloudflare succeeded over
both transports while YouTube timed out over both; this localized the failure
after the VPN exit rather than to either tunnel.

For a strict work router, do not test or diagnose YouTube unless the user asks
for it as a separate task. Its only Internet-routing objective is that every
LAN device exits through the exact configured Russian IPv4. Use the exact user-approved server public IPv4; a deployment terminating on a
Russian VPS expects that VPS's public IPv4. Use
`references/work-russian-egress.md` and
`scripts/verify-work-egress.sh` for the profile-specific gates. Do not accept
country geolocation as a substitute for exact IP equality.

Do not treat URLTest fallback as proof that every candidate works. A VLESS
REALITY connection that reaches the endpoint but receives the camouflage
site's real certificate means the server rejected the REALITY identity
(public key, short ID, client, or active inbound); inspect the server rather
than tuning the ASUS client. An AWG client with transmitted bytes but zero
handshake and zero received bytes likewise requires server peer, listener,
firewall, port-forward, and current-public-IP checks. Request SSH access to the
server-side router before changing working client routing.

The initial RT-AX82U low-memory trial accepted Hysteria2 and an official AWG
3.1 userspace client, protected DoH, and LAN fail-closed. Later work exposed
false failures from the cron library environment, destructive two-minute
watchdog route rebuilds, and poor AWG userspace throughput on this ARM router.
The current measured profile uses Hysteria as primary and AWG as fallback,
non-interrupting selector changes, serialized checks, 2-failure failover, and
15-success failback. Preserve the most recent live acceptance results in
deployment notes rather than treating this paragraph as a universal protocol
ranking.

### VLESS-only strict-work profile

When both UDP transports remain unstable and the user explicitly chooses one
VLESS path, retain sing-box only as the LAN TPROXY, protected-DNS, and
fail-closed frontend. Run the official ARMv7 Xray client separately with a
localhost SOCKS5 inbound, then add a sing-box `socks` outbound to that port.
Route `lan-tproxy`, the main local test listener, protected DNS, and `route.final`
to the Xray SOCKS outbound. Do not route public traffic to `direct` and do not
leave the old selector cron active.

Adapt the coordinated lifecycle from `scripts/S97asus-home-vpn-two-protocol`:
replace AWG start/stop with the Xray service, remove selector cron registration,
and disable the existing selector job. Do not install the older
`scripts/S97asus-home-vpn` as a strict-work lifecycle: it lacks the kill switch.
Start Xray before sing-box and make the healthy watchdog idempotently verify
both daemons without recreating firewall state. Once the VLESS-only path passes
the exact-exit and restart gates, stop AWG and disable its selector, but retain
timestamped Hysteria/AWG configuration and lifecycle backups until the user
accepts the separate LAN work test. A stopped Xray must make the main SOCKS
path fail while `HOMEVPN_KILLSWITCH` remains attached to LAN-to-WAN forwarding;
router-originated reverse SSH must remain reachable.

Install `scripts/S95asus-xray-vless` as
`/opt/etc/init.d/S95xray-vless`; it validates the protected Xray config before
starting the daemon and keeps runtime files under `/opt`.

The accepted RT-AX82U implementation uses Xray SOCKS5 on `127.0.0.1:1090` and
sing-box main acceptance on `127.0.0.1:1086`. Do not treat these ports as
universal if they conflict on a different router. Resolve the newest stable
official Xray at execution time and verify the official digest before
installation under `/opt`.

For replacement USB storage, verify ext4, the correct Entware architecture,
and the existing Merlin `amtm` post-mount hook. Restore restricted management
SSH before VPN changes. Disable the package-provided `S99sing-box` placeholder
when using the managed `/opt/etc/home-vpn/config.json`; otherwise a second
unmanaged daemon may start at boot. Resolve stable versions and digests again.
Repeat exact-exit, Xray-stop fail-closed, restart, soak, and separate LAN gates;
previous acceptance does not prove that replacement media works.

# AmneziaWG procedure

## Fresh installation

Use the current stable 3x-ui embedded AmneziaWG server rather than adding a
second Docker or standalone AWG server. Create one UDP inbound on 51888 and one
router client. Let the current panel generate keys and recommended AWG
obfuscation parameters; do not copy the numerical values from an old deployment.

The current deployment has no usable global IPv6 egress, so its candidate
router profile uses IPv4 traffic. The live Keenetic interface MTU is 1400 even
though an old 3x-ui inbound remark mentions MTU 1280. Judge the applied router
value with `ip link` and `show interface`; do not infer it from a remark.
Re-evaluate IPv6 and path MTU on a fresh VPS instead of blindly retaining old
labels.

Install the newest stable AWG Manager package on the Entware router from its
official repository. Confirm the router firmware can load the bundled module
for its exact kernel and architecture before importing the protected client
configuration. The resulting Keenetic interface should be `OpkgTun10` (or the
existing managed interface discovered during an idempotent retry) and occupy
the place agreed for that deployment in `HydraRoute`. In the VLESS-primary
example it is third, after `Proxy1` and `Proxy0`; preserve an existing user's
chosen order.

## Verification

Verify all layers, not only interface state:

1. AWG Manager reports the tunnel running and the kernel interface exists.
2. The VPS shows a recent peer handshake and increasing transfer counters.
3. A router request bound to the AWG interface returns YouTube and Google HTTP 204 over IPv4.
4. A clean LAN client sustains a real application load.
5. When the higher-priority transports are intentionally unavailable, HydraRoute selects AmneziaWG; stopping it then fails closed, and restarting it restores the path without manual route repair.

For isolated acceptance, enable only `OpkgTun10` and keep `Proxy0` and `Proxy1`
administratively down. Use a separate LAN client with no local VPN for sustained
YouTube playback. Record the exact time of any stall so router handshakes,
transfer counters, VPS UDP counters, and application behavior can be correlated.

The initial isolated baseline on this deployment passed 37/37 YouTube HTTP 204
probes over more than six minutes at about 0.21-0.26 seconds per request. The
router received about 431 MB during the interval, the VPS UDP 51888 socket kept
zero drops, and the VPS global `RcvbufErrors` counter did not increase. A later
real-load test nevertheless failed after roughly 20 minutes and 1.5 GB, so a
short protocol probe is not sufficient for acceptance.

The observed failure mode was a false-up tunnel: AWG Manager, the kernel
interface, and HydraRoute all remained up, but interface-bound YouTube and
Google requests timed out. Bidirectional UDP was still visible at the VPS,
while the latest AWG handshake aged past its configured `RekeyAfterTime`
window. Restarting x-ui, restarting AWG Manager, and cycling the Keenetic
interface did not recover useful traffic. A tunnel-specific restart recovered
traffic only briefly while retaining the same public UDP tuple.

To distinguish a protocol implementation failure from path filtering, expose a
second temporary UDP destination on the VPS and redirect it to the unchanged
AWG inbound, then change only the client endpoint port. In the observed test,
moving from UDP 51888 to 51889 immediately restored traffic; two successive
AWG3 rekeys completed and 25/25 YouTube HTTP 204 probes passed at about
0.21-0.26 seconds. Treat that as strong evidence of filtering or degradation of
the previous long-lived UDP flow/port, not inspection of the encrypted YouTube
payload and not an AWG3 client/server mismatch.

For a resilient deployment, do not rely on a single permanent UDP destination.
The supplied `scripts/vps-amneziawg-port-hop.*` assets expose UDP 30000-30100
and redirect the range to the unchanged AWG inbound. The supplied router
hopper changes the live AWG peer endpoint to a random port every 10-20 seconds;
put its deployment-specific values in `/opt/etc/awg-port-hopper.conf`. Keep the
server AWG parameters and keys unchanged during a port rotation. Also attach a
real Keenetic/AWG health check to `OpkgTun10`; administrative/link state alone
must never be used as proof that the tunnel passes traffic. Revisit the interval
only from captured evidence: a much faster fixed interval creates its own
recognizable timing pattern, while an interval longer than the observed
classifier window permits repeat failures.

Store exported configurations and private keys only in root-owned files with
mode 0600. Do not place them in this skill or in terminal transcripts.

## Asuswrt-Merlin AWG 3.1 client

Read `references/asuswrt-merlin.md` before deploying on ASUS. Treat presence
of any AWG 3.1-only field as a hard capability gate: the client daemon and its
configuration path must accept every field. A legacy addon that reports
`RUNNING`, creates `awg0`, and transmits bytes is not compatible evidence.

Use a unique peer per concurrently active router. If the supplied profile is
already active elsewhere, create a new client key and address while preserving
the server-wide J/S/H/I values, header-protection key, padding, randomized
timings, trailer, and cookie settings. Verify the server retains the old peer
and adds the new one before restarting the ASUS client.

The reviewed reusable files are:

- `scripts/asus-awg-uapi-config.go` — protected AWG 3.1 UAPI renderer;
- `scripts/S96asus-awg3-userspace` — daemon, address, and source-route lifecycle;
- `scripts/asus-select-outbound` — configurable primary/fallback health logic
  with strict exit-IP checks and failover/failback hysteresis;
- `scripts/S97asus-home-vpn-two-protocol` — coordinated sing-box, TPROXY,
  protected DNS, watchdog, and fail-closed lifecycle.

For Hysteria-primary deployments, the reviewed selector restarts the standby
AWG userspace service immediately before an actual failover to AWG and probes
the refreshed path before selection. This mitigates degradation tied to an old
client UDP flow while avoiding periodic disruption of an active fallback.

## Additional client for a Keenetic-hosted server

Import the protected server client profile into AWG Manager as a separate
Kernel tunnel, for example `Home-AmneziaWG`. Discover the allocated `awgN` /
`OpkgTunN` pair at runtime; it must not replace or edit the production tunnel
on `OpkgTun10`.

Derive the tunnel address, endpoint, MTU, keys, and AWG obfuscation values from
the protected server profile. Keep them only in the live manager
configuration. Assign a sufficiently low global priority so the new path
cannot preempt existing router traffic outside its dedicated policy. Attach a
Keenetic TLS Ping Check profile, for example `HomeAWG`, against a stable target
such as `www.gstatic.com`.

Verify a fresh handshake, increasing counters, Google HTTP 204, and the
expected server egress address while curl is bound to the discovered tunnel.
After the import, recheck the mandatory invariant:
`createNDMSProxyForSingbox=false`, `Proxy0=127.0.0.1:1082`, and
`Proxy0` still has `Hy2Native` attached.

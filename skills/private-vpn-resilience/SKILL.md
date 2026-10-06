---
name: private-vpn-resilience
description: Bootstrap, configure, diagnose, test, and maintain a private VPN stack with deployment-specific transport profiles on an Ubuntu VPS and an Entware-enabled Keenetic or Asuswrt-Merlin router. Use for 3x-ui, Hysteria2, VLESS Reality, AmneziaWG, transparent routing, failover, stability, cleanup, migration, and recovery work.
---

# Private VPN Resilience

## Deployment identity and transport order

Distinguish each deployment by its actual router, server endpoint, and intended
exit policy. Historical filenames and reverse-SSH ports do not prove device
identity. Verify the endpoint before modifying it. Keep private deployment
records outside the shared skill using
[references/deployment-template.md](references/deployment-template.md).

The Keenetic example uses VLESS (`Proxy1`) as primary, Hysteria2 (`Proxy0`) as
first fallback, and AmneziaWG (`OpkgTun10`) as second fallback. Preserve the
user-agreed order in an existing installation; work profiles are independent.

Use independent transports so a protocol-specific block or implementation failure does not remove all VPN access. The full Keenetic profile uses:

- Hysteria2 through a Keenetic Proxy interface backed by the official native Hysteria client.
- VLESS Reality through `Proxy1`, backed by the official Xray client on the router.
- AmneziaWG through `OpkgTun10`.

On a memory-constrained Asuswrt-Merlin router, use the two-protocol
Hysteria2+AmneziaWG profile when the user explicitly chooses to omit Xray. Do
not install or run Xray in that profile. Keep the full three-protocol mode
available for hardware with enough RAM or when the user asks for VLESS. When
the user explicitly chooses a single VLESS strict-work path, follow the
dedicated ASUS branch and retain protected DNS and fail-closed routing;
there is no transport failover in that profile.

For a new Keenetic installation, read
[references/bootstrap.md](references/bootstrap.md) and require only
root-capable SSH access to the Ubuntu VPS plus root SSH access to a Keenetic
router whose Entware storage is already mounted at `/opt`. For a new
Asuswrt-Merlin or GNUton installation, read
[references/asuswrt-merlin.md](references/asuswrt-merlin.md); Entware must also
be mounted at `/opt`, but AWG Manager and HydraRoute are not used. Do not
require a pre-existing panel, tunnel manager, routing policy, proxy interface,
or VPN profile.

When the router is for work and every attached device must use one Russian
exit, also read
[references/work-russian-egress.md](references/work-russian-egress.md). Treat
that as a distinct strict-egress profile: obtain the exact expected public
IPv4, route all Internet traffic through the selected VPN transports, and do
not add split-tunnel or direct-WAN fallback policies. The exit may be a home
server or a Russian VPS; use its exact user-approved public IPv4. YouTube and other blocked entertainment services are
outside this profile's health and acceptance criteria.

For a Keenetic-as-public-server request, confirm TCP/UDP port reachability
from an independent network and preserve router services. Use the dedicated
server findings in the protocol references; do not apply the VPS bootstrap
blindly or replace existing client interfaces.

For an existing installation, inspect live state and read the operator's private deployment record before making changes. Use [references/deployment-template.md](references/deployment-template.md) for a sanitized record outside the skill. Read [references/hysteria.md](references/hysteria.md), [references/vless.md](references/vless.md), or [references/amneziawg.md](references/amneziawg.md) for protocol-specific work. Update the references when a tested configuration changes.

For an ASUS router running Asuswrt-Merlin or GNUton firmware, read
[references/asuswrt-merlin.md](references/asuswrt-merlin.md). Do not apply the
Keenetic interface names, HydraRoute objects, or AWG Manager installers to an
ASUS router.

## Init / usage guide

If the user's input is exactly `init`, or the user asks for prerequisites or
usage instructions before deployment, read
[references/prerequisites.md](references/prerequisites.md) and present it as the
user-facing preparation guide. Then stop. In this mode do not connect over SSH,
request credentials, inspect devices, install packages, or change any state.

Do not duplicate the prerequisite checklist in an orchestrator or another
reference. This file is the single source of truth for both Codex and OpenCode.

## Full bootstrap entrypoint

When the user explicitly invokes this skill in Codex for a clean deployment, or
when an OpenCode orchestrator loads it for that purpose, act as the deployment
agent rather than merely explaining the procedure.

If connection details are missing, request them in one compact message:

- VPS IP/hostname, SSH port, root-capable user, and authentication method;
- router type, IP/hostname, SSH port, root user, and authentication method;
- for a strict work deployment, the exact expected Russian exit IPv4 and
  whether it belongs to a home server or a Russian VPS.

Prefer a temporary SSH key. If a password is supplied, never place it in a
command argument, ordinary log, or skill file. Do not ask the user to preinstall
3x-ui, AWG Manager, HydraRoute, Xray, Hysteria, or tunnel profiles. After access
is received, verify `/opt` and Entware on the router yourself, read
`references/bootstrap.md`, and continue autonomously through installation and
the verification gates. Ask again only when new authority or a decision with
material impact is genuinely required, such as a router reboot that interrupts
the user's network.

Do not finish with instructions the agent could safely execute itself. Stop
only at a concrete unsupported-hardware/service conflict, or while waiting for
the separate no-local-VPN LAN acceptance test that only the user can perform.

## Release policy

Resolve versions at execution time and install the newest stable releases from official upstream sources and configured stable package feeds. Exclude development, nightly, beta, release-candidate, and draft releases unless the user explicitly asks for them. Verify upstream checksums or signatures before running downloaded root-level artifacts, and record the source URL, version, and digest actually installed.

Numbers in protocol notes describe observed deployments, not pins for a fresh installation. Do not downgrade a current stable component to those historical versions merely to reproduce the snapshot. When a newest stable release changes a schema or protocol handshake, adapt the configuration and pass the compatibility gates; request approval before falling back to an older release.

## Operating rules

1. Inspect live state and preserve working transports before mutation. Never restart or replace every active transport together unless a tested fail-closed lifecycle explicitly coordinates the restart.
2. Make one causal change at a time. Record baseline counters, run a protocol-level request, then run a bounded load or soak test.
3. Keep credentials only in protected live configuration files. Never place passwords, private keys, subscription links, or panel credentials in this skill or command output.
4. Back up a file before replacing it and document an exact rollback. Remove temporary binaries, scripts, disabled test inbounds, and obsolete interfaces after acceptance.
5. Treat UI `RUNNING` as process state, not proof of connectivity. Verify through the actual interface with neutral HTTPS checks and inspect kernel UDP drop counters. In the strict work profile, exact observed exit-IP equality is mandatory.
6. Preserve the platform's failover ordering. A new implementation should initially be tested behind a separate local port or lowest-priority interface.
7. Make bootstrap rerunnable: detect existing packages, ports, interfaces, and inbounds; update matching managed objects in place; never create duplicates or regenerate working identities on a retry.
8. On a new VPS create exactly the production inbounds selected for that deployment—three in full mode, Hysteria2 plus AmneziaWG in explicit low-memory mode, or VLESS in an explicitly selected single-path work profile—and no legacy or failed experimental inbounds.
9. Keep the accepted Hysteria production path invariant: `Proxy0` must use the official native client on `127.0.0.1:1082` with UDP port hopping. Never let an AWG Manager Sing-box import claim or rewrite `Proxy0`. Set `createNDMSProxyForSingbox` to `false` before importing or refreshing a diagnostic Sing-box Hysteria object.
10. Distinguish production data-path acceptance from management-object verification. If the user explicitly asks for a visible AWG Manager tunnel, verify its own card (`RUNNING`, finite delay, passing traffic), but label it diagnostic and do not route HydraRoute through it. After every AWG Manager import, refresh, restart, or Sing-box control action, re-read the Keenetic running configuration and reject the change if `Proxy0` is not `127.0.0.1:1082` with `Hy2Native` attached.

## Verification gates

- Configuration parses and the intended daemon is active after reboot-style restart.
- Neutral HTTPS and the user's in-scope application checks succeed through the selected interface. Do not use YouTube as a gate for the strict work profile.
- In the strict work profile, every isolated transport, the normal selector,
  and the forced-failover path report exactly the configured Russian exit
  IPv4; geolocation or an IP merely belonging to Russia is insufficient.
- A bounded download completes at useful throughput without increasing server `RcvbufErrors` or socket drops.
- A 5–30 minute soak has no timeouts.
- Restarting either endpoint causes automatic recovery without manual client intervention.
- In multi-transport mode, HydraRoute or the platform selector marks an unhealthy path unavailable and demonstrably selects the next transport. In single-path mode, failure must block public LAN traffic and recovery must restore it automatically.
- With every VPN transport unavailable, a strict work-profile LAN client has
  neither Internet nor public DNS access and never falls back to the ISP WAN.

Use the scripts in `scripts/` as reviewed building blocks. They intentionally contain no credentials. The existing `prepare_native_hysteria.sh` is a migration helper for a router that already has a protected AWG Manager sing-box profile; a clean bootstrap must instead build the protected native configuration from the newly generated server client material.

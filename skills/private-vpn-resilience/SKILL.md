---
name: private-vpn-resilience
description: Bootstrap, configure, diagnose, test, and maintain a private three-protocol VPN stack on an Ubuntu VPS and an Entware-enabled Keenetic router. Use for 3x-ui, Hysteria2, VLESS Reality, AmneziaWG, HydraRoute failover, stability, cleanup, migration, and recovery work.
---

# Private VPN Resilience

Maintain three independent transports so a protocol-specific block or implementation failure does not remove all VPN access:

- Hysteria2 through a Keenetic Proxy interface backed by the official native Hysteria client.
- VLESS Reality through `Proxy1`, backed by the official Xray client on the router.
- AmneziaWG through `OpkgTun10`.

For a new installation, read [references/bootstrap.md](references/bootstrap.md) and require only root-capable SSH access to the Ubuntu VPS plus root SSH access to a Keenetic router whose Entware storage is already mounted at `/opt`. Do not require a pre-existing panel, AWG Manager, HydraRoute, proxy interface, or VPN profile.

The clean bootstrap uses the Ubuntu VPS as the public server and Keenetic as
the client/router. For a Keenetic-as-public-server request, do not apply the
full bootstrap topology blindly. Inspect live state, confirm public reachability
of the intended TCP and UDP ports from an independent network, preserve current
router services, and use the dedicated Keenetic-server findings in the relevant
protocol references. Keep server-side services and additional client paths
separate from `Proxy0`, `Proxy1`, and `OpkgTun10` unless the user explicitly
requests a migration.

For maintenance of an existing installation, inspect live state first and read
the operator's deployment record if one exists. Use
[references/deployment-template.md](references/deployment-template.md) to create
a sanitized local record outside the skill. Read
[references/hysteria.md](references/hysteria.md),
[references/vless.md](references/vless.md), or
[references/amneziawg.md](references/amneziawg.md) for protocol-specific work.
Update shared references only when a tested, reusable procedure changes; keep
hostnames, addresses, credentials, interface identities, and private deployment
history out of the skill.

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
- Keenetic IP/hostname, SSH port, root user, and authentication method.

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

Numbers in protocol notes describe observed deployments, not pins for a fresh
installation. Do not downgrade a current stable component merely to reproduce
a historical snapshot. When a newest stable release changes a schema or
protocol handshake, adapt the configuration and pass the compatibility gates;
request approval before falling back to an older release.

## Operating rules

1. Inspect live state and preserve working transports before mutation. Never restart or replace all three transports together.
2. Make one causal change at a time. Record baseline counters, run a protocol-level request, then run a bounded load or soak test.
3. Keep credentials only in protected live configuration files. Never place passwords, private keys, subscription links, or panel credentials in this skill or command output.
4. Back up a file before replacing it and document an exact rollback. Remove temporary binaries, scripts, disabled test inbounds, and obsolete interfaces after acceptance.
5. Treat UI `RUNNING` as process state, not proof of connectivity. Verify through the actual interface with HTTP 204 checks and inspect kernel UDP drop counters.
6. Preserve HydraRoute failover ordering. A new implementation should initially be tested behind a separate local port or lowest-priority interface.
7. Make bootstrap rerunnable: detect existing packages, ports, interfaces, and inbounds; update matching managed objects in place; never create duplicates or regenerate working identities on a retry.
8. On a new VPS create exactly the accepted production inbounds—AmneziaWG, Hysteria2, and VLESS Reality—and no legacy or failed experimental inbounds.
9. Keep the accepted Hysteria production path invariant: `Proxy0` must use the official native client on `127.0.0.1:1082` with UDP port hopping. Never let an AWG Manager Sing-box import claim or rewrite `Proxy0`. Set `createNDMSProxyForSingbox` to `false` before importing or refreshing a diagnostic Sing-box Hysteria object.
10. Distinguish production data-path acceptance from management-object verification. If the user explicitly asks for a visible AWG Manager tunnel, verify its own card (`RUNNING`, finite delay, passing traffic), but label it diagnostic and do not route HydraRoute through it. After every AWG Manager import, refresh, restart, or Sing-box control action, re-read the Keenetic running configuration and reject the change if `Proxy0` is not `127.0.0.1:1082` with `Hy2Native` attached.

## Verification gates

- Configuration parses and the intended daemon is active after reboot-style restart.
- Google and YouTube HTTP 204 checks succeed through the selected interface.
- A bounded download completes at useful throughput without increasing server `RcvbufErrors` or socket drops.
- A 5–30 minute soak has no timeouts.
- Restarting either endpoint causes automatic recovery without manual client intervention.
- HydraRoute marks an unhealthy interface unavailable or otherwise demonstrably selects the next transport.

Use the scripts in `scripts/` as reviewed building blocks. They intentionally contain no credentials. The existing `prepare_native_hysteria.sh` is a migration helper for a router that already has a protected AWG Manager sing-box profile; a clean bootstrap must instead build the protected native configuration from the newly generated server client material.

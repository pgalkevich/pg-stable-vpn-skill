# Deployment record template

Keep the completed record outside the skill and outside a public repository.
Store secrets only in protected live configuration files. The record may point
to those files, but must not contain passwords, private keys, UUIDs, tokens,
subscription URIs, or complete client configurations.

## Environment

- Deployment date:
- VPS provider and region:
- VPS OS and architecture:
- Router model, KeeneticOS or Merlin/GNUton version, kernel, and architecture:
- Entware mount and free space:
- Selected profile and intended exit policy:

## Installed versions

Record the version, official source URL, and verified digest for:

- 3x-ui and bundled Xray:
- router Xray:
- router Hysteria:
- AWG Manager:
- HydraRoute Neo and HRweb (Keenetic):
- sing-box and userspace AWG (ASUS):

## Managed topology

- Hysteria2 server port/range and Keenetic interface:
- VLESS Reality server port and Keenetic interface:
- AmneziaWG server port/range and Keenetic interface:
- HydraRoute or ASUS selector priority and ISP fallback state:
- Single-path routing, if selected:
- Expected exit-IP record location (private only):
- Protected DNS, IPv6 handling, and kill-switch state:
- Ping Check profiles and targets:

Do not record public or private addresses in a copy intended for publication.

## Rollback anchors

- VPS backup paths and creation time:
- Router startup configuration and JFFS hook backups:
- Entware configuration backups:
- Exact rollback order:

## Acceptance evidence

- Isolated Hysteria2 test:
- Isolated VLESS Reality test:
- Isolated AmneziaWG test:
- Load and soak results:
- Failover and recovery results:
- Reboot-style restart results:
- Separate LAN-client acceptance result:
- Strict-work exact-exit and all-transports-down DNS/Internet test:

## Follow-up

- Known limitations:
- Monitoring to repeat:
- Temporary access to revoke:
- Next maintenance window:

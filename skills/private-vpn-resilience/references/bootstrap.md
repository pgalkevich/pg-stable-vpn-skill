# SSH-only bootstrap

## Inputs and outcome

The only required starting access is:

- root-capable SSH to a supported Ubuntu VPS with a public IPv4 address;
- root SSH to a Keenetic router with working Internet access and Entware mounted at `/opt`.

Do not ask the user to preinstall 3x-ui, AWG Manager, HydraRoute, Xray, or
Hysteria. Install and configure them over SSH. If the router model cannot load
the required AmneziaWG or Netfilter modules, stop after the read-only preflight
and report the hardware/firmware limitation.

The completed topology is:

1. `Proxy1`: SOCKS5 to the official Xray VLESS Reality client on `127.0.0.1:1083`, primary.
2. `Proxy0`: SOCKS5 to the native Hysteria2 client on `127.0.0.1:1082`, first fallback.
3. `OpkgTun10`: native AmneziaWG, third priority.
4. Keenetic policy `HydraRoute` permits those interfaces in that order and explicitly has no ISP fallback.
5. HydraRoute Neo sends only the domains and CIDRs from the bundled assets through that policy.

This is an example order. Preserve the user's agreed transport priorities;
interface numbers do not determine priority. On an existing deployment,
verify the selected route with `show ip policy HydraRoute`.

## Current-stable version resolution

Resolve every version immediately before installation:

- 3x-ui: newest non-prerelease GitHub release from `MHSanaei/3x-ui` or the official stable installer without a version argument.
- Xray-core: newest non-prerelease GitHub release from `XTLS/Xray-core` for the router architecture.
- Hysteria: newest non-prerelease GitHub release from `apernet/hysteria` for the router architecture.
- AWG Manager: newest package in the official stable repository installed by `repo.hoaxisr.ru/install.sh`.
- HydraRoute Neo and HRweb: newest packages exposed by the official Ground-Zerro stable feed and `install-neo.sh`.
- Ubuntu and Entware dependencies: newest versions in their configured stable repositories.

Reject GitHub releases where `draft` or `prerelease` is true. Do not use
`dev-latest`, `develop`, nightly assets, or Keenetic Dev firmware. Save the
resolved version, asset URL, and checksum in the deployment record before
installing. Use release-provided SHA-256 files where available; otherwise
calculate and record a digest after a TLS-authenticated download and before
copying the binary into its final root-owned path.

Do not run an indiscriminate `opkg upgrade`: update feed indexes and install or
upgrade only the packages required by this stack. This keeps unrelated router
packages outside the change set.

## Preflight and rollback anchors

Before changing either host:

1. Record OS, architecture, free storage/RAM, default route, public IPv4, current listeners, firewall, and time synchronization.
2. On the router verify `/opt` is mounted and writable, `opkg` works, and Entware survives reboot.
3. Use `components list` to check the Keenetic WireGuard, Netfilter kernel, Xtables-addons, OPKG, and Ping Check components. Install missing supported components with `components install <component>` followed by `components commit`; expect a router reboot and reconnect before continuing.
4. Back up `/etc/x-ui`, relevant `/etc/systemd/system` units and nftables fragments on the VPS. Back up the Keenetic startup configuration and `/opt/etc` files that will be replaced.
5. If TCP 443, UDP 8443, UDP 20000-20100, UDP 30000-30100, or UDP 51888 is already occupied, identify its owner. Never stop an unrelated listener merely to claim the port.

Use timestamped backups and a deployment manifest. Never overwrite an existing
working UUID, Reality key, AWG key, or Hysteria secret on a retry.

## VPS installation

Install current stable Ubuntu packages needed for download, validation, TLS,
JSON handling, and packet filtering: `ca-certificates`, `curl`, `jq`,
`openssl`, `unzip`, and `nftables`. Preserve SSH access while changing the
firewall.

Install the newest stable 3x-ui release from the official repository. Prefer
its noninteractive installer so it generates a random administrator username,
password, API token, panel port, and web base path and writes them to the
root-only `/etc/x-ui/install-result.env`. Do not print that file into ordinary
logs or save its contents in this skill. Enable and verify `x-ui.service`.

For a clean installation, use the current official Quick Start entrypoint:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

When running without an interactive terminal, set `XUI_NONINTERACTIVE=1` so the
same official installer completes unattended and records generated credentials
in `/etc/x-ui/install-result.env`. Do not pass `dev-latest` or a prerelease tag.
The installer verifies the selected release archive against its published
`.sha256` file; still record the installed stable version and installer source
in the deployment manifest.

If the command, options, or installer behavior no longer work, stop rather than
substituting an unofficial script. Read the current installation instructions
in the official repository at `https://github.com/MHSanaei/3x-ui`, adapt to the
documented stable method, and preserve the security and credential-handling
requirements above.

Use the authenticated local panel API over loopback to create or update the
three managed inbounds. The API root is `/panel/api`; fetch its authenticated
`openapi.json` at runtime because request schemas may change between current
stable releases. Prefer update-in-place by stable remark/tag over direct SQLite
edits.

### AmneziaWG

- UDP 51888, IPv4 server subnet, router client MTU 1400 as the current tested baseline, keepalive 25 seconds. Change MTU only after an applied-value and path-MTU test.
- Let the current stable panel generate the AWG server/client key pairs and its current recommended AWG obfuscation fields.
- Use IPv4-only AllowedIPs when the VPS has no verified IPv6 egress.
- Install `scripts/vps-amneziawg-port-hop.nft` and its systemd service so UDP 30000-30100 redirects to the unchanged UDP 51888 inbound. Keep direct UDP 51888 available for HAPP and rollback.
- Export one router client configuration into a root-only staging file.

### Hysteria2

- UDP 8443, TLS 1.3, ALPN `h3`, unique client authentication, Salamander obfuscation.
- Obtain a valid certificate containing the public IP SAN when no domain is available. Confirm automated renewal and an x-ui reload hook before acceptance.
- Install the nftables port-hopping redirect from UDP 20000-20100 to UDP 8443 using the supplied service and fragment. Keep direct UDP 8443 available for HAPP and rollback.
- Export the router fields needed by the native client: address, auth, SNI, and Salamander password.

### VLESS Reality

- TCP 443, raw TCP, REALITY, `xtls-rprx-vision`, one generated UUID, one generated short ID.
- Probe the camouflage target from the VPS at deployment time. It must match the SNI and support a normal TLS 1.3 handshake; `www.samsung.com:443` is the currently tested candidate, not an eternal hard-coded requirement.
- Generate the Reality key pair with the bundled current Xray and store only the public client material outside protected server configuration.
- Export the router fields needed by current Xray: address, port, UUID, flow, public key, short ID, and server name.

After API writes, run the bundled Xray configuration test, restart through
3x-ui, and verify the three expected listeners. Open only the panel port, TCP
443, UDP 8443, UDP 20000-20100, and UDP 51888 in addition to pre-existing SSH
rules. Include UDP 30000-30100 for the router AmneziaWG port-hopping path.

## Router installation

Run `opkg update`, then install the current required packages from stable feeds:
`ca-bundle`, `curl`, `jq`, `ip-full`, `iptables`, and `wireguard-tools`.

Install the newest stable AWG Manager with its official installer. Install the
newest stable HydraRoute Neo/HRweb with the official Ground-Zerro installer.
Record the package versions returned by `opkg list-installed`; do not pin a
fresh installation to historical deployment versions.

Use these canonical upstream installation commands from the router shell for a
clean bootstrap. Do not substitute an unofficial mirror or a copied historical
installer:

```sh
# AWG Manager
opkg update
wget -qO- http://repo.hoaxisr.ru/install.sh | sh
```

```sh
# HydraRoute Neo
opkg update && opkg install curl && curl -Ls "https://git.zerrolabs.org/Ground-Zerro/release/pages/keenetic/install-neo.sh" | sh
```

Treat both commands as root-level remote installers: record the final resolved
source URL and a digest of the retrieved script in the deployment manifest,
capture their exit status, and verify the installed packages and services
before continuing. A retry must first detect an existing installation and use
the installer's supported update path rather than creating duplicate services
or configuration trees.

Before importing any Sing-box subscription or tunnel, set
`createNDMSProxyForSingbox` to `false` in AWG Manager's protected settings and
restart only AWG Manager. This prevents a generated Sing-box tunnel on port
1080 from silently taking ownership of Keenetic `Proxy0`. A Sing-box Hysteria
object may be retained for UI diagnostics, but it is not a production route.

Download the newest stable official arm build of Hysteria and Xray that matches
`opkg print-architecture`. Verify their release checksums, install them as
`/opt/bin/hysteria-native` and `/opt/bin/xray-vless`, then install
`S98hysteria-native` and `S97xray-vless` from this skill.

Transfer the client material directly over SSH/SCP into a temporary root-only
directory on the router. Generate:

- `/opt/etc/awg-manager/awg10.conf` through AWG Manager's current import/API path;
- `/opt/etc/awg-port-hopper.conf` with the deployed AWG interface, VPS address, UDP range 30000-30100, and randomized 10-20 second interval; install `router-awg-port-hopper.sh` as `/opt/sbin/awg-port-hopper` and `router-S99zz-awg-port-hopper` as an Entware service;
- `/opt/etc/hysteria-native/config.json` using `scripts/render_native_hysteria.sh`, listening on SOCKS5 `127.0.0.1:1082`, with 10-second keepalive and randomized port hopping across 20000-20100 every 10-20 seconds;
- `/opt/etc/xray-vless/config.json` listening on SOCKS5 `127.0.0.1:1083`, using current REALITY fields and the `firefox` uTLS fingerprint unless a clean A/B test demonstrates a better current fingerprint.

Set secret-bearing files to mode 0600, validate each configuration with its own
binary, start one transport at a time, and remove the temporary transfer files.

## Keenetic interfaces and failover

Create the interfaces and health checks idempotently with `ndmc`; update an
existing matching interface rather than creating another number:

```text
ping-check profile Hy2Native
    host www.gstatic.com
    update-interval 10
    mode tls
    min-success 1
    max-fails 2

ping-check profile NeuroWG
    host www.gstatic.com
    update-interval 10
    mode tls
    min-success 1
    max-fails 2

ping-check profile VlessReality
    host www.gstatic.com
    update-interval 10
    mode tls
    min-success 1
    max-fails 2

interface Proxy0
    description Hysteria2-Native
    security-level public
    ip global 255
    ping-check profile Hy2Native
    proxy protocol socks5
    proxy upstream 127.0.0.1 1082
    proxy socks5-udp
    up

interface OpkgTun10
    ping-check profile NeuroWG

interface Proxy1
    description VLESS-Reality-Xray
    security-level public
    ip global 256
    ping-check profile VlessReality
    proxy protocol socks5
    proxy upstream 127.0.0.1 1083
    proxy socks5-udp
    up

ip policy HydraRoute
    permit global Proxy1
    permit global Proxy0
    permit global OpkgTun10
    no permit global ISP
```

The descriptions are examples; preserve an existing operator-supplied name on
an idempotent retry. The routing order above is the VLESS-primary example; preserve
the user-agreed priorities.

Install the three files from `assets/HydraRoute/` into
`/opt/etc/HydraRoute/`, preserving mode and backing up any user-edited lists.
Set `PolicyOrder=HydraRoute`, `DirectRouteEnabled=false`, and restart HRneo only
after the Keenetic policy exists. Save the Keenetic configuration.

Run `scripts/enforce_hysteria_proxy0.sh` after the initial AWG Manager setup and
again after every AWG Manager upgrade, import, subscription refresh, or Sing-box
restart. It disables automatic NDMS proxy creation, restores the accepted
`Proxy0` upstream and health check, saves the Keenetic configuration, and fails
if the invariant is absent from the running configuration.

## Acceptance and cleanup

Test each transport alone from a separate LAN device with no local VPN. The
management computer may remain behind another VPN but must not be used as
acceptance evidence. For each isolated path, run the verification gates in
`SKILL.md`, then test ordered failover by stopping only the active transport.

Reboot the router and restart the VPS once after all three isolated tests pass.
Confirm automatic recovery, listener ownership, the HydraRoute policy order,
AWG endpoint rotation, and absence of ordinary ISP fallback. Remove downloaded archives, transferred
secret bundles, failed test inbounds, obsolete proxy interfaces, and old client
daemons only after rollback and reboot tests pass.

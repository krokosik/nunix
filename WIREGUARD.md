# Public ingress tunnel

`modules/server/ingress-wireguard.nix` owns the WireGuard interface, addresses,
peer configuration, firewall rules, QUIC forwarding, and reply routing. Both
hosts opt in through `mkIngressWireguard` in their host configuration.

| Setting | Anubis (edge) | Osiris (origin) |
| --- | --- | --- |
| Interface | `wg-ingress` | `wg-ingress` |
| IPv4 | `10.253.43.1` | `10.253.43.2` |
| IPv6 | `fd42:6e75:6e69:443::1` | `fd42:6e75:6e69:443::2` |
| MTU | 1380 | 1380 |
| Peer endpoint | Learned from authenticated traffic | `144.24.185.41:51820` |

Osiris initiates the tunnel and sends a keepalive every 25 seconds, maintaining
its CGNAT mapping without home-router port forwarding. OCI must allow IPv4 UDP
destination port 51820 on anubis, in addition to the existing public web ports.

## Traffic and client addresses

- TCP/80 and TCP/443 remain on HAProxy. Its backend is osiris's WireGuard IPv4
  address, and PROXY v2 continues to convey the original client IP to Traefik.
- UDP/443 uses nftables DNAT for IPv4 and IPv6, without SNAT or masquerading.
  Traefik and CrowdSec therefore receive the original source address directly.
- On osiris, only traffic sourced from its WireGuard addresses uses routing
  table 51820. Its default home connection and Tailscale administration remain
  independent of the ingress tunnel.
- The origin peer accepts all source prefixes because it carries Internet
  client IPs. This does not install a main-table default route or trust the
  interface: the host firewall permits only QUIC and HAProxy's TCP web traffic.
- The 1380-byte tunnel MTU leaves room for quic-go's 1280-byte handshake datagrams
  plus IP/UDP headers, while allowing room for WireGuard encapsulation on the
  external path. End-to-end MTU and HTTP/3 still need verification at activation.

No Nginx, transparent proxy, runtime `ip rule` scripts, or manual WireGuard setup
is required. systemd-networkd creates the interface, routes, and policy rules.
Traefik's existing direct Tailscale HTTP/3 path is unchanged.

## Keys

Each host's private key is encrypted under `wireguard/ingress_private_key` in
its own `nunix-secrets/<host>/secrets.yaml`. Public peer keys live in the host
configurations. sops installs private keys with mode 0400 for `systemd-network`;
networkd is ordered after secret installation. Private keys never enter the
unencrypted Nix store. Update the secrets flake lock after rotating keys.

## Build and activation

Run evaluation and builds directly on `wkrokosz@lindbladian`, rather than relying
on `nh --build-host`, which still evaluates the flake on the invoking machine.
The local workstation has only 8 GiB RAM. Builds do not activate these changes.

When activation is authorized, activate osiris before switching anubis's HAProxy
backend. Keep Tailscale administration available during the change. Validate
the handshake, tunnel routes, source-based reply routing, public HTTP/2 and
HTTP/3 over both address families, and real client IPs in Traefik/CrowdSec logs.
Use passwordless elevation for remote activation.

This configuration has not been activated; runtime connectivity is untested.

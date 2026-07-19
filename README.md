### Hosts

To add a host:

1. Add it to `flake.nix` (`mkSystem`).
<!-- 2. Set its wireguard address in the host's `configuration.nix` -->
   <!-- (`networks."wg0".address`). -->
<!-- 3. Add its LAN IPs to `networking.hosts` in -->
   <!-- `hosts/modules/desktops/networking.nix`. -->
4. Add sops keys (see the install/post-install sections below).
5. Install per [General Install Procedures](#general-install-procedures).

## General Install Procedures

### Tips

1. Generate hostId (for ZFS systems): `head -c4 /dev/urandom | od -A none -t x4`
2. Hetzner VMs apparently require grub instead of systemd-boot (as of 2025-08)
3. Available options:
    a. isVirtual (bool) - set for virtual hardware (VPS or VM). Default false.
    b. latestZFSKernel (bool) - set to use latest available ZFS compatible kernel. Default false.
    c. username (string) - set to override default username. Default krokosik.
    d. role (desktop|server|shared) - set host role. Shared stands for a workstation also used by others. Default server.

### Installing using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)

1. Create new (Ubuntu is fine) cloud server. Add one of the public keys. Adjust
   DNS 'A' records if needed.
2. SSH into the new box and update the disk device name(s) and partition layout
   (if needed) in disko-config.nix.
3. Make sure the hostname and username are set in the same way as for the target host, so that connecting via ssh keeps working.
4. Prepare ssh key and add it to the secrets config:
```bash
mkdir -p /tmp/nixos-anywhere-extra/etc/ssh
ssh-keygen -t ed25519 -N "" -f /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key
cat /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```
5. Add the public key to the secrets config and run `sops updatekeys` on relevant files.
6. Commit the changes in the secrets repo.
7. `just deploy-new <host>` to install NixOS and the configuration for the new host.
8. If problems arise, add `--no-reboot` to the above command so you can
   troubleshoot the new install.
        
### PostgreSQL major-version upgrades

`services.postgresql.package` is pinned to a specific major
(`postgresql_17` at time of writing) in `modules/system/postgresql.nix` so
that rebuilds never silently dump-and-restore the cluster. Major upgrades
are a manual operation, following the canonical NixOS recipe:

- [NixOS manual — Upgrading PostgreSQL](https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading)

The short version: stop `postgresql.service`, run the
`upgrade-pg-cluster` script (made available by temporarily setting both the
old and new packages in a shell), bump `package = pkgs.postgresql_<new>` in
this repo, rebuild, and verify before deleting the old data directory.

# Services

To avoid Nix bloat and having to repeat the same service configuration across multiple services,
helper options should exist in `modules/oci-containers.nix` and shared services like Postgres, Traefik
or Authentik. If the helper options are insufficient for a service, it should be expanded to cover
the additional use case. A reference implementation is in `hosts/osiris/services/splitpro.nix` which
connects to Postgres in `hosts/osiris/services/postgresql.nix`, Traefik in `hosts/osiris/services/traefik.nix`,
and uses the helper options in `modules/oci-containers.nix`. Once Authentik is deployed, it should also
follow the same pattern for deploying providers via blueprints.

## Authentik (SSO)

`modules/apps/authentik.nix` deploys Authentik as native systemd units via
the [`nix-community/authentik-nix`](https://github.com/nix-community/authentik-nix)
flake input — *not* containers. The module's `services.authentik` runs three
units (`authentik`, `authentik-worker`, `authentik-migrate`) under
`DynamicUser=true`, talks to the shared postgres over the unix socket via
peer auth (so no role password is needed). Traefik fronts it
at `authentik.${config.publicDomain}`.

### Declarative configuration via blueprints

Groups, applications, OAuth/proxy providers, and group bindings are
all managed as Authentik **blueprints** (YAML, applied idempotently by the
worker on a periodic Celery task and on startup). No terraform, no UI
clicks except for user enrollemnt and management. Starter blueprints live under `hosts/osiris/authentik-blueprints/`.

The module merges its blueprints with the upstream-bundled set into a
single `blueprints_dir` via `pkgs.runCommandLocal` + `cp -rL`. **Do not
use `pkgs.symlinkJoin`** here: authentik's `retrieve_file` calls
`Path(...).resolve()` and rejects anything that resolves outside
`blueprints_dir`, so symlink-joined entries (which dereference back to
their original store paths) all fail with "Invalid blueprint path".
Real files via `cp -L` are required.

### Adding an OIDC service to Authentik

Services that speak OIDC natively register via the `myAuthentik.oidcApps`
aggregator from `hosts/osiris/services/authentik.nix`. The aggregator
generates the sops secret pair, contributes the per-app blueprint
dir, and stacks one merged worker-side env file onto authentik so
blueprint `!Env` placeholders resolve. Apps that read OIDC creds
from env vars get their own per-app env file too; apps that store
creds in their own DB/UI opt out via `clientCredsInAppEnv = false`.

Blueprint secrets must reference `!Env <APP>_OIDC_CLIENT_ID` /
`<APP>_OIDC_CLIENT_SECRET` (uppercased app name with hyphens →
underscores) so they never land in `/nix/store`.

**Always set `grant_types` explicitly.** authentik 2026.x added
`OAuth2Provider.grant_types` (defaults to an empty list) and the
authorize view now rejects any flow whose grant isn't listed
(`Invalid grant_type for provider` → the app sees a malformed-request
error and bounces back to its login page). Providers created under an
older authentik were back-filled by the migration, so the omission is
invisible until a provider is created **fresh** on 2026.x — a new app,
a new host, or a `recovery:all` / `bootstrap:reinstall` rebuild (which
recreates every provider at once and would otherwise break all SSO
simultaneously). `[authorization_code, refresh_token]` is authentik's
own UI default and the right value for every app here, including
`public`/PKCE clients.

Reference: [model fields](https://docs.goauthentik.io/customize/blueprints/v1/models),
[YAML tags](https://docs.goauthentik.io/customize/blueprints/v1/tags).

### Forward-auth via Traefik

For services that don't speak OIDC themselves, gate them via Authentik's embedded outpost +
Traefik's `forward_auth`. Register the app via
`myAuthentik.forwardAuthApps.<name>` — the aggregator emits the
proxy provider + application + policy binding into a single merged
blueprint per host (so two forward-auth apps don't clobber the
embedded outpost's global `providers` list) **and** wires a Traefik
`chain-authentik` middleware for the app's route.

OIDC apps use the `chain-no-auth` middleware instead, which skips the forward-auth check and
lets the app talk to Authentik directly.

## Secrets Management

Secrets are stored in a private `nunix-secrets` repository pulled in as a flake
input and managed with [sops-nix](https://github.com/Mic92/sops-nix).

- Secrets are YAML files in the `nunix-secrets` repo (`common/secrets.yaml`,
  `<hostname>/secrets.yaml`, `server/secrets.yaml`, etc.)
- Age encryption keys are bootstrapped from host SSH keys
  (`/etc/ssh/ssh_host_ed25519_key`)

## Guidance and Resources

- [NixOS.org Manuals](https://nixos.org/learn/)
- [Official Nix Documentation](https://nix.dev)
  - [Best practices](https://nix.dev/guides/best-practices)
- [Noogle](https://noogle.dev/) - Nix API reference documentation.
- [Official NixOS Wiki](https://wiki.nixos.org/)
- [NixOS Package Search](https://search.nixos.org/packages)
- [NixOS Options Search](https://search.nixos.org/options?)
- [Home Manager Option Search](https://home-manager-options.extranix.com/)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) - an excellent
  introductory book by Ryan Yin
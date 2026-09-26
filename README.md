### Hosts

To add a host:

1. Add it to `flake.nix` (`mkSystem`).
<!-- 2. Set its wireguard address in the host's `configuration.nix` -->
   <!-- (`networks."wg0".address`). -->
<!-- 3. Add its LAN IPs to `networking.hosts` in -->
   <!-- `hosts/modules/desktops/networking.nix`. -->
2. Add sops keys (see the install/post-install sections below).
3. Install per [General Install Procedures](#general-install-procedures).

## General Install Procedures

### Tips

1. Generate hostId (for ZFS systems): `head -c4 /dev/urandom | od -A none -t x4`
2. Hetzner VMs apparently require grub instead of systemd-boot (as of 2025-08)
3. Available options:
    a. isVirtual (bool) - set for virtual hardware (VPS or VM). Default false.
    b. latestZFSKernel (bool) - set to use latest available ZFS compatible kernel. Default false.
    c. username (string) - set to override default username. Default krokosik.
    d. role (desktop|server|shared) - set host role. Shared stands for a workstation also used by others. Default server.
4. For hosts with automatic secure boot setup (limine), disable secure boot before hand and make sure it is in setup mode if available in UEFI.
5. You can enroll the cryptroot passphrase in TPM2 via if SB is enabled. You should then switch from autologin to greeter auth (also do cryptswap if used). The id can be read by checking which partition is needed using `lsblk -f` and then comparing to symlinks in `/dev/disk/by-id`:
```shell
run0 systemd-cryptenroll \
   --tpm2-device=auto \
   --tpm2-pcrs=0+2+7 \
   /dev/disk/by-id/<partition-id>
```

### Installing using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)

1. Create new (Ubuntu is fine) cloud server. Add one of the public keys. Adjust
   DNS 'A' records if needed.
2. SSH into the new box and update the disk device name(s) and partition layout
   (if needed) in disko-config.nix.
3. Make sure the hostname and username are set in the same way as for the target host, so that connecting via ssh keeps working.
4. Prepare an ssh key and setup secrets in `nunix-secrets`:
```bash
mkdir -p /tmp/nixos-anywhere-extra/etc/ssh
ssh-keygen -t ed25519 -C "root@<hostname>" -N "" -f /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key
cat /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```
5. Run the `add_host` script in `nunix-secrets` using the hostname and age key as args.
6. Commit the changes in the secrets repo and run `nix flake update my-secrets`.
7. `just deploy-new <host>` to install NixOS and the configuration for the new host.
8. If problems arise, add `--no-reboot` to the above command so you can
   troubleshoot the new install.
9. Once the host boots, get its `~/.ssh/id_ed25519.pub` file and it to the `nunix-secrets` deploy keys as well as `ssh-keys.nix`
        
### PostgreSQL major-version upgrades

`services.postgresql.package` is pinned to a specific major
(`postgresql_17` at time of writing) in `hosts/osiris/services/postgresql.nix` so
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
and uses the helper options in `modules/oci-containers.nix`. SplitPro also
registers its OIDC provider via `mkAuthentik.oidcApps.splitpro`.

## Authentik (SSO)

`hosts/osiris/services/authentik.nix` deploys Authentik as native systemd units via
the [`nix-community/authentik-nix`](https://github.com/nix-community/authentik-nix)
flake input — *not* containers. The module's `services.authentik` runs three
units (`authentik`, `authentik-worker`, `authentik-migrate`) under
`DynamicUser=true`, talks to the shared postgres over the unix socket via
peer auth (so no role password is needed). Traefik fronts it
at `authentik.${config.publicDomain}`.

### Declarative configuration via blueprints

Groups, applications, OAuth/proxy providers, and group bindings are
managed as Authentik **blueprints** (YAML, applied idempotently by the
worker on startup and periodically). The factory generates the OIDC and
forward-auth app blueprints from Nix declarations; other blueprint
directories can be contributed via `mkAuthentik.extraBlueprints`.

The module merges its blueprints with the upstream-bundled set into a
single `blueprints_dir` via `pkgs.runCommandLocal` + `cp -rL`. **Do not
use `pkgs.symlinkJoin`** here: authentik's `retrieve_file` calls
`Path(...).resolve()` and rejects anything that resolves outside
`blueprints_dir`, so symlink-joined entries (which dereference back to
their original store paths) all fail with "Invalid blueprint path".
Real files via `cp -L` are required.

### Adding an OIDC service to Authentik

1. From this repo, run `just oidc-secrets <app> [host]` (default host:
   `osiris`). The recipe generates random client credentials under
    `<app>/oidc_client_id` and `<app>/oidc_client_secret` in
    `../nunix-secrets/<host>/secrets.yaml`, stages and commits only that
    file in the secrets repo, pushes, then runs
    `nix flake update my-secrets` here.
   It requires a clean secrets checkout on `main` synced with `origin/main`
   and refuses to overwrite existing or partial credentials. It never
   prints their values. If the push fails, the lockfile is not updated;
   resolve the push before updating the lockfile.
2. Register `mkAuthentik.oidcApps.<app>` in the application's module.
   Supply `redirectUris` (strictly matched callback URLs) and choose
   `accessGroup` and `displayGroup` as needed. Optional Authentik
   properties include `displayName`, `providerName` (default
   `provider for <app>`), `slug`, `host`, `launchUrl`, `iconUrl`, and
    `logoutUri` and `logoutMethod`. For Authentik back-channel logout,
    set `logoutMethod = "backchannel"` alongside the app's back-channel
    `logoutUri` (as in Immich). The computed `issuerUrl` defaults to the Authentik
    Traefik URL plus `/application/o/<slug>/` (including the trailing
    slash required to match Authentik's discovery `issuer`).
3. Deliver the credentials in the *app* module using the exposed
   `credentials.clientId.secretName` and
   `credentials.clientSecret.secretName`. SplitPro, for instance, maps
   these to `AUTHENTIK_ID` and `AUTHENTIK_SECRET` in its own
   `sops.templates."splitpro.env"`, and assigns `oidc.issuerUrl` to
   `AUTHENTIK_ISSUER`. Consumer env files, restarts, and startup ordering
   belong to the consuming service. Set its Traefik chain to
   `chain-no-auth` so the app can handle OIDC itself.
4. Review and commit `flake.lock` alongside the Nix changes and run
   `nix flake check` before deployment. A missing key at deployment
   usually means the pinned secrets revision is stale.

The factory registers the sops credentials, generates an Authentik OAuth2
provider, application and access-policy binding, and passes the values to
the blueprint importer using `!Env`. It does **not** generate random values
during Nix evaluation or configure the app's credential delivery. The
default sops secret names and source keys are `<app>/oidc_client_id` and
`<app>/oidc_client_secret`. Override `credentials.<kind>.key` only when
adopting differently named existing keys; `owner`, `group`, and `mode`
default to `root`, `root`, and `0400` for the decrypted files.

For a public/PKCE client, set `publicClient = true`: the factory reads only
the client ID and never provisions or references a client secret. The
`oidc-secrets` recipe currently generates *both* values, including an
unused secret for public clients.

**The generated blueprint sets `grant_types` explicitly.** authentik 2026.x added
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
`mkAuthentik.forwardAuthApps.<name>` — the aggregator emits the
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
- Home Manager userspace secrets are bootstrapped using the system secrets and stored in `home.yml` files

### Editing secrets locally

To configure SOPS to use an SSH private key that corresponds to an age recipient:

```bash
mkdir -p ~/.config/sops/age
read -rsp "Paste the SSH private key, then press Enter: " SSH_KEY
printf '\n' >&2
printf '%s\n' "$SSH_KEY" | ssh-to-age -private-key > ~/.config/sops/age/keys.txt
unset SSH_KEY
chmod 600 ~/.config/sops/age/keys.txt
```

The converted private age identity is used automatically by `sops edit`.

### Syncthing node identity

Generate a stable node identity for a host:

```bash
nix shell nixpkgs#syncthing --command syncthing generate --home /tmp/syncthing-config
```

Encrypt the generated `key.pem` and `cert.pem` into that host's secrets file as
`syncthing_key` and `syncthing_cert`.

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

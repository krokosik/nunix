# AGENTS.md

NixOS flake managing several hosts. Entry point is `flake.nix`; per-host
configs live in `hosts/<name>/`; shared modules under `modules/common`,
`modules/server`, `modules/desktop`; Home Manager wired via
`home-manager/`. See `README.md` for install procedures.

## Working here

The user is new to NixOS but an experienced sysadmin (Proxmox VMs, Docker).
- Always back design choices with a brief rationale; propose alternatives.
- Ask for confirmation before non-trivial system config changes.
- Security is a primary concern; prefer least-privilege defaults
  (firewall on, role-gated services, immutable users).

## Migration context

Legacy services run as a Docker compose stack on `osiris` (see the
`@web-services` reference in `opencode.json`). They are being migrated into
this flake incrementally. **Prefer a native NixOS module first**, fall back
to `virtualisation.oci-containers`/docker-compose only with justification.
Ignore the legacy `scripts/` directory. Each migration: explain the
native-module approach, ask before proceeding, note any secret wiring.

## Critical gotchas

- **`flake.lock` is gitignored.** Never commit it. Each machine keeps its
  own lockfile.
- **Secrets are a separate local repo.** `my-secrets` flake input points at
  `~/Work/nunix-secrets` (`flake = false`, path input) — the flake does not
  build without it. Per-host `secrets.yaml` + `common/` + `server/`.
- **autoUpgrade pulls from local `main` ref.** `modules/common/nix.nix`
  sets `flakePath = /home/<user>/Work/nunix?ref=main`, so the local repo
  must have `main` checked out and changes committed for autoUpgrade to see
  them. Uncommitted edits are not picked up.
- **Hardware is via nixos-facter, not `hardware-configuration.nix`.** Each
  host sets `hardware.facter.reportPath = ./facter.json` (committed).
- **`justfile` is not yet ready and should be adjusted** — recipes may be
  stale or incomplete. Verify against actual state before relying on them.

## Commands

Enter the devshell (provides `nh`, `sops`, `age`, `ssh-to-age`,
`nix-prefetch`, `nixfmt-tree`, `nixd`, `just`):

```
just dev          # or: nix develop .
```

Format (the only "lint"):

```
nix fmt .         # uses formatter.x86_64-linux = nixfmt-tree
nix flake check   # closest thing to validation; no test suite exists
```

Deploy (via justfile — see caveat above):

```
just deploy-local              # nh os switch .          (current host)
just deploy-remote <host> [ip] # nixos-rebuild switch --flake .#<host> --target-host <user>@<host> --use-remote-sudo
just repl [host]               # nix repl ".#nixosConfigurations.<host>"
```

Bootstrap a new host (template `.#host` is **referenced but not yet defined**
in `flake.nix` outputs — this is broken until a template is added):

```
just new-host <name>    # nix flake new ./hosts/<name> -t .#host
just deploy-new <host>  # nixos-anywhere + nixos-facter hardware config
```

Nix store utils: `just repair-store`, `just fetch-hash <url>`,
`just delete-broken-derivations [depth]`.

Adding a host (per README): add `mkSystem` entry in `flake.nix`, add sops
keys in `nunix-secrets`, set `networking.hostId`
(`head -c4 /dev/urandom | od -A none -t x4`).

Searching nixos options, also useful for checking if a package is natively supported:
`nh search options <option>` (e.g. `nh search options networking.firewall`).

## Custom options (`modules/common/options.nix`)

Read by other modules — set per-host in `hosts/<name>/configuration.nix`:
- `isVirtual` (bool, default false) — VPS/VM/container.
- `latestZFSKernel` (bool, default false) — pulls `zfs_unstable` + latest
  compatible kernel (see `modules/zfs.nix`).
- `username` (str, default `krokosik`).
- `role` (enum `desktop|shared|server`, default `server` — least
  privileged). `shared` = a workstation also used by others. Gate
  services on this (e.g. `docker.enableOnBoot = config.role == "server"`).

## Conventions

- Boot: `modules/boot.nix` = systemd-boot (used by osiris/anubis);
  `modules/boot-limine.nix` = Limine + secure boot + plymouth (for future
  desktops). README notes Hetzner VMs need grub (as of 2025-08).
- ZFS: `devNodes = "/dev/disk/by-id/"`, autoScrub monthly, encryption
  currently commented out in each host's `disko-config.nix`.
- Users: `mutableUsers = false`; password hash from sops
  (`login_password_hash`, `neededForUsers = true`); default shell fish;
  SSH-key sudo auth via `pam.rssh`.
- Firewall: nftables-only; `tailscale0` trusted; tailscale `--ssh` +
  `tag:server` on server hosts.
- Commit messages: short imperative, capitalized, no conventional-commit
  prefix, no body (e.g. `Add ghostty terminfo`, `Fix password key typo`).
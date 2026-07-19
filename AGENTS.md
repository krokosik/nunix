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

**Service-first architecture**: each service module (e.g. `splitpro.nix`)
owns its DB users, extensions, and postgres settings. `postgresql.nix` stays
server-level only (enableTCPIP, authentication, firewall, superuser
password, backup). Secrets live in service-specific sops blocks (e.g.
`splitpro:`), not a generic `postgresql:` block. See the `service-migration`
skill for the full migration runbook and postgres patterns.

## Critical gotchas

- **Secrets are a separate local repo.** `my-secrets` flake input points at
  `~/Work/nunix-secrets` (`flake = false`, path input) — the flake does not
  build without it. Per-host `secrets.yaml` + `common/` + `server/`.
- **`flake.lock` must be bumped when `my-secrets` changes.** Run
  `nix flake lock --update-input my-secrets` after editing secrets, then
  commit `flake.lock`. Otherwise the nix build uses a stale secrets hash
  and sops-install-secrets fails with "key not found".
- **Hardware is via nixos-facter, not `hardware-configuration.nix`.** Each
  host sets `hardware.facter.reportPath = ./facter.json` (committed).
- Never `find /nix/store` or anything equivalent. Prefer using
  `nix flake archive --json`.
- Do not execute `nix flake archive --json` with commands that actually search
  over the result of that, as it forces the user to review every single time.
  Run `nix flake archive --json` once, then refer to its output literally in
  other, separate find commands. Not like `NIXPKGS=/nix/store/... rg $NIXPKGS`,
  not like `np=/nix/store/...; sed -n 258,275p "$np/lib/modules.nix"`,
  _literally_, without any variables.
- Never use non-new `nix` commands. Prefer `nix build` over `nix-build` and so
  on. Always prefer new (nix3) commands.
- Never use python to parse json if jq can do it fine, jq avoids permission
  prompts.

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

Deploy (via justfile):

```
just deploy-local              # deploy on the current machine
just deploy-remote <host> [ip] # deploy on a remote host (ssh)
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
- Prefer `lib.lists.singleton` over a single item list.
- Always `let inherit (lib.<path>) foo;` with full paths like `lib.lists.head`,
  never `inherit (lib) foo` unless `foo` has no submodule path.
- Always prefer `${getExe pkgs.something}` over bare command names in shell
  aliases. Use `package = getExe pkgs.something` when there are multiple usages.
- Leave an empty line between unrelated options.
- Never put values in `let` bindings that duplicate module system options. If a
  value is set through `config.*`, always reference it through `config.*`. `let`
  bindings for hardcoded values that could be overridden via the module system
  are forbidden. `let` is fine for computed derivations, helper functions, and
  `getExe` shortcuts.
- Prefer destructuring attrset arguments when it improves clarity. Use
  `{ home, ... }:` instead of `value: value.home` where it makes sense.
- Always put `/* lang */` before multiline code strings, e.g. `/* bash */ ''`.
- Category/section comments should be uppercase with no period, e.g. `# DOCK`,
  not `# Dock.`.
- Prefer setting individual options with `mkIf` over wrapping entire attrsets.
  Use `foo.bar = mkIf condition value;` not
  `foo = mkIf condition { bar = value; };` when possible.
- Inline package definitions should use `pkgs.callPackage` with destructured
  args, e.g. `pkgs.callPackage ({ stdenv, writeText }: ...) { }`.
- For inline source code in packages, use `writeText` directly in the `src`
  attribute rather than a separate `let` binding.
- Do not use `builtins.` in modules.
- Never use `rec` ever. Worst case, define a custom `fix`.
- Do not use shortform CLI arguments if longform exists in source files. It's
  only OK for interactive use. (and never when providing scripts to the user)
- Never use `toString` for paths that need to preserve derivation contexts.
  Always `"${path}"`.
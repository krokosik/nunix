# AGENTS.md

NixOS flake managing several hosts. Entry point is `flake.nix`; per-host
configs live in `hosts/<name>/`; shared modules under `modules/common`,
`modules/server`, `modules/desktop`; Home Manager wired via
`home-manager/`. See `README.md` for install procedures.

## Working here

The user is new to NixOS but an experienced sysadmin (Proxmox VMs, Docker).
- Always back design choices with a brief rationale; propose alternatives.
- Check the current hostname with the shell command
- `lindbladian` is the designated build host for all flake hosts, including
  `anubis` via aarch64 emulation. Run full builds there; builds do not authorize
  deployment. Its `nunix-build-all.timer` fetches `main` into a separate checkout
  and tries to build every host daily at 04:00 local time, keeping successful outputs.
  It also runs `nix-grpc-daemon` with mTLS (`hosts/lindbladian/nix-grpc-daemon.nix`).
  Desktops listed in `nunix.grpcStore.trustedHosts` send their builds to it
  when they can (`modules/desktop/nix-grpc-store.nix`). They still build
  `preferLocalBuild` derivations locally, and they build everything locally
  while the daemon is unreachable. Servers only download store paths from it,
  using one shared read-only certificate (`modules/server/nix-grpc-store.nix`).
  The public certificates are stored in `nunix-secrets/nix-grpc-store/`. Issue
  them with `just grpc-store-init` and `just grpc-store-cert <host>`.
- Ask for confirmation before non-trivial system config changes.
- Security is a primary concern; prefer least-privilege defaults
  (firewall on, role-gated services, immutable users).

## Migration context

Legacy services run as a Docker compose stack on `osiris` (see the
`@web-services` reference in `opencode.json`). They are being migrated into
this flake incrementally. **Prefer a native NixOS module first**, fall back
to `virtualisation.oci-containers`/docker-compose only with justification.
Each migration: explain the
native-module approach, ask before proceeding, note any secret wiring.

**Service-first architecture**: each service module (e.g. `splitpro.nix`)
owns its DB users, extensions, and postgres settings. `postgresql.nix` stays
server-level only (enableTCPIP, authentication, firewall, superuser
password, backup). Secrets live in service-specific sops blocks (e.g.
`splitpro:`), not a generic `postgresql:` block. See the `service-migration`
skill for the full migration runbook and postgres patterns.

## Critical gotchas

- **Secrets are a separate private repo.** `my-secrets` flake input is
  `git+ssh://git@github-secrets/krokosik/nunix-secrets.git` (`flake = false`),
  checked out locally at `~/work/nunix-secrets` — the flake does not build
  without it. Per-host `secrets.yaml` + `common/` + `server/`.
- **`flake.lock` must be bumped when `my-secrets` changes.** Edit in
  `~/work/nunix-secrets`, commit and push to `main`, then run
  `nix flake update my-secrets` and commit `flake.lock`. Otherwise the nix build uses a stale secrets hash
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
- When investigating with `nix eval`, always bundle multiple invocations together,
  returning a single curated json object.
- When checking systemd unit properties, use `systemctl show <unit> -P <property1> -P <property2>`
  rather than calling `systemctl cat` and parsing the output.
- Suspected broken unit configs can be checked with `systemd-analyze verify <unit>`.
- When dealing with psql, prefer single-string queries over a sequence of psql commands.
- nix Comma is installed, meaning that if an executable is not found on the system, prepend the invocation with a comma "," to fetch from nixpkgs. For example `, cowsay dupa`

## Agent skills

- Skills hosted on GitHub are added as non-flake inputs (`flake = false`)
  in `flake.nix`, under `# AGENT SKILLS`. List the skill folders to link in
  `externalSkills` in `home-manager/private/common/slop.nix`, which links
  them into the Claude Code, Codex and OpenCode skills directories. Update
  one with `nix flake update <input>`.
- `ai/skills/` is only for personal skills written and maintained in this
  repo. Never copy a third-party skill into it.

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

`scripts/` holds small Python helpers. Run them as uv scripts, as described in
https://docs.astral.sh/uv/guides/scripts/. Each one starts with a
`#!/usr/bin/env -S uv run --script` shebang and an inline `# /// script` block
that declares `requires-python` and `dependencies`. Favour the standard
library. Add a dependency only when it is clearly better than the standard
library or than calling a command-line tool. The `secrets` recipes
(`oidc-secrets`, `grpc-store-init` and `grpc-store-cert`) call
`scripts/provision-secrets.py`.

Adding a host (per README): add `mkSystem` entry in `flake.nix`, add sops
keys in `nunix-secrets`, set `networking.hostId`
(`head -c4 /dev/urandom | od -A none -t x4`).

Searching nixos options, also useful for checking if a package is natively supported:
`nh search options <option>` (e.g. `nh search options networking.firewall`).

## Custom options (`modules/common/options.nix`)

Other modules read these options. Set them per-host in `hosts/<name>/configuration.nix`:
- `isVirtual` (bool, default false) — VPS/VM/container.
- `latestZFSKernel` (bool, default false) — pulls `zfs_unstable` + latest
  compatible kernel (see `modules/zfs.nix`).
- `nunix.hosts.<name>` (in `modules/common/hosts.nix`) — shared device inventory: `user` (default `krokosik`), `tailscale.{ipv4,ipv6}`, `hostKey`, `userKey`. Generates ssh_config + known_hosts. The fleet-wide `nunix.grpcStore.{host,port,trustedHosts}` options are defined in the same file. Read the current host via read-only `config.nunix.self` (e.g. `config.nunix.self.user`); set values only in the inventory.
- `role` (enum `desktop|server`, default `server` — least privileged). Gate
  services on this (e.g. `docker.enableOnBoot = config.role == "server"`).

## Conventions

- State management: whenever possible, rely on systemd for state management over
  bash scripting and other unstructured approaches.
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
- Commit messages: short imperative, capitalized, use prefixes for common tasks
  like update:, vscode:, desktop:, slop:, no body (e.g. `Add ghostty terminfo`, `Fix password key typo`).
- Prefer `singleton` over a single item list.
- Always `let inherit (lib.<path>) foo;` with full paths like `lib.lists.head`,
  never `inherit (lib) foo` unless `foo` has no submodule path.
- Use inherit for all lib functions, i.e. prefer `singleton` over `lib.lists.singleton`
- Always prefer `${somePkg}` over bare command names or full calls in scripts and shell aliases. Remember
  that `getExe'` exists for explicit binary names. Use `package = getExe somePkg` in let blocks.
  Note that a shell abbreviation expects the program to be on PATH, so always use
  bare command names.
- For attr enumeration, such as specifying dependencies or vscode extensions, remember
  to use `with`.
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
- Use nested attrsets when setting several attrs under the same prefix.
  Flat dot-based attrs (`foo.bar = ...;`) are allowed IF AND ONLY IF there is
  exactly one attr under that prefix; otherwise nest:
  `foo = { bar = ...; baz = ...; };`, not `foo.bar = ...; foo.baz = ...;`.
- Inline package definitions should use `pkgs.callPackage` with destructured
  args, e.g. `pkgs.callPackage ({ stdenv, writeText }: ...) { }`.
- For inline source code in packages, use `writeText` directly in the `src`
  attribute rather than a separate `let` binding.
- Do not use `builtins.` in modules.
- Never use `rec` ever. Worst case, define a custom `fix`.
- Do not use shortform CLI arguments if a longform exists in source files. Shortform
  flags are OK only for interactive use, never when providing scripts to the user.
- Never use `toString` for paths that need to preserve derivation contexts.
  Always `"${path}"`.

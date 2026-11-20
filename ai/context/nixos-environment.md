# NixOS environment

This machine runs NixOS, not a generic FHS distro. Adjust accordingly.

- **System**: declared by a flake at `~/work/nunix` with Home Manager. Never
  change the system imperatively (`nix-env -i`, `nix profile install`, editing
  `/etc`); propose a change to the flake instead.
- **Managed files**: anything under `~` that symlinks into `/nix/store` is
  read-only and owned by Home Manager. Edit its Nix source, not the file.
- **Shell**: the user's shell is `fish`. Commands you hand to the user must be
  fish syntax: `set -x VAR value`, `(cmd)` for substitution, no `export`, no
  heredocs. Your own tool shell may still be bash.
- **Shebangs**: write `#!/usr/bin/env bash` (or the relevant interpreter).
  `/bin` and `/usr/bin` are envfs mounts resolving names via `PATH`, so FHS
  paths like `/bin/bash` in third-party scripts work, but do not rely on them.
  envfs resolves names only on exec: `ls`, `stat` or `test -e /bin/bash`
  report them missing unless `ENVFS_RESOLVE_ALWAYS=1` is set.
- **Privilege**: `sudo` is disabled; use `run0`. `sudo` is only a compatibility
  shim, so don't rely on its flags. `run0` prompts for a polkit password you
  cannot enter: ask the user to run privileged commands themselves.
- **Missing binaries**: run them ad hoc with comma, `, <cmd> [args]`, which
  fetches from nixpkgs via the nix-index database without installing. For
  several tools at once use `nix shell nixpkgs#a nixpkgs#b --command <cmd>`.
  Find which package provides a file with `nix-locate`. Never install with
  `pip install --user`, `npm install --global`, `cargo install` or `apt`.
- **Nix tooling**: prefer Nix over ad hoc setups wherever it applies. Use only
  the nix3 CLI (`nix build`, `nix run`, `nix shell`, `nix develop`,
  `nix eval`, `nix flake …`), never `nix-build`, `nix-shell` or `nix-env`.
  `nh` wraps rebuilds (`nh os switch`) and searches (`nh search options …`).
  Projects with `flake.nix` or `.envrc` use direnv with nix-direnv: run their
  tooling through `nix develop --command …`. Never scan `/nix/store` with
  `find` or similar.
- **nix-ld**: enabled with a broad library set (libffi, glib, dbus,
  fontconfig, freetype, GL, Wayland, X11/xcb, vulkan, pulseaudio), so prebuilt
  dynamically linked binaries (Python wheels, npm native modules, rustup
  toolchains, downloaded release binaries) usually run as-is. If one fails
  with "No such file or directory" or a missing `.so`, report the library so
  it can be added to `programs.nix-ld.libraries`; don't `patchelf` or set
  `LD_LIBRARY_PATH` ad hoc.
- **Language tooling**: Python goes through `uv` with uv-managed interpreters
  only (`uv run`, `uvx`, `uv tool install`; `~/.local/bin` is on `PATH`). Node
  has corepack for pnpm/yarn. Rust uses `rustup`. A C toolchain is present,
  but `pkg-config` finds no library headers outside a dev shell, so pull
  `-dev` dependencies in with `nix shell` or `nix develop`.
- **Services**: systemd. Inspect units with `systemctl show <unit> -P <prop>`
  and `journalctl`; units are declared in Nix, never edited in `/etc`.
- **Secrets**: managed by sops-nix under `/run/secrets` and similar paths.
  Never read or print them.

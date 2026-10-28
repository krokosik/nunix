# Home directory garden

Findings and attempts maintained by `@home-gardener`. Work incrementally: find a
credible fix, test it, and investigate alternatives only if needed. All cases
below were investigated on **horus**, last reviewed **2026-10-16**.

## CURRENT ISSUES

| Application / path | Status | Next attempt |
| --- | --- | --- |
| psql / `~/.psql_history` | verified, deployed | User confirms working after switch; monitor recurrence |
| VSCodium / `~/.vscode-oss` | verified, deployed | User confirms working after switch; monitor package upgrades |
| NVIDIA / `~/.nv` | implemented, not deployed | System profile and patched GSR tested; recording/performance check after switch |
| OCI CLI / `~/.oci` | implemented, not deployed | Wrapper tested; existing credentials need a separate migration plan |
| Parsec / `~/.parsec`, `~/.parsec-persistent` | Flatpak installed | Test GUI/login/streaming; next switch removes native launcher |

Statuses: `investigating`, `approved`, `applied`, `verified`, `blocked`, `exception`.
Verification is limited to the version and launch route actually tested.

## PSQL — `~/.psql_history`

- **Found:** regular empty file, mode 0600. User used psql from
  `~/work/split-pro/flake.nix`, which declares PostgreSQL 18; client unavailable
  on the ordinary PATH. History contents were not read.
- **Solution:** documented `PSQL_HISTORY` override. User approved a **global**
  Home Manager setting rather than the previously proposed devshell-only fix.
  Implemented in `home-manager/shared/common/home-declutter.nix` at
  `$XDG_STATE_HOME/psql/history`; activation creates its parent with mode 0700.
- **Test:** PASS with PostgreSQL 18.6, disposable local server (Unix socket only),
  and two interactive PTY sessions. Synthetic history was saved, loaded, and
  recalled/executed in session two. Directory/file modes: 0700/0600. Neither
  session created `.psql_history`. Test server/data cleaned up.
- **Attempt note:** initial devshell lacked initdb; full pinned PostgreSQL enabled
  the test. An invalid `chmod --mode` activation command was caught and corrected
  to `chmod 0700`. Home Manager build passes.
- **Deployed:** user switched and reports psql working. Existing real history
  was not migrated by this cleanup. Monitor recurrence during normal use.
- **Rollback:** remove the setting; retain any new history until reconciled.
- **Sources:** [psql 18 manual](https://www.postgresql.org/docs/18/app-psql.html)
  via Context7 `/websites/postgresql_18`. Targeted postgres GitHub searches found
  no relevant issue; no further issue search needed to test this supported option.

## VSCODIUM — `~/.vscode-oss`

- **Found:** pinned package 1.116.02821. Original substitutions were present;
  the problem was incomplete coverage, not a confirmed string mismatch.
  AUR source retrieved via Git: its product.json-only patch adds no coverage.
- **Failed attempts:** patching only product.json/out/cli.js still created the
  legacy directory. Adding cliProcessMain.js alone also failed. Tracing found
  embedded product copies in other bundles and the Rust `codium-tunnel` helper's
  independent `.vscode-oss/cli` default.
- **Implemented:** `vscodium.nix` now patches product.json and all 11 relevant JS
  bundles fail-fast; wraps codium-tunnel to default `VSCODE_CLI_DATA_DIR` to
  `$HOME/.local/share/codium/cli`, respecting explicit overrides. Existing Home
  Manager profiles and extensions mapping are preserved. The home.file attr key
  is an identifier; its `.target` is the actual destination, not a legacy link.
- **Test:** PASS for isolated CLI and Xvfb GUI, without user-data/extension-dir
  flags masking defaults. Config/profiles used `$XDG_CONFIG_HOME/VSCodium`,
  extensions used `$HOME/.local/share/codium/extensions`, Rust state used its
  redirected CLI directory. No `.vscode-oss` recurrence. All test children and
  temporary profiles cleaned up. Build, format, and flake check (--no-build) pass.
- **Deployed:** user switched and reports VSCodium working. Data root remains
  HOME-relative; custom XDG_DATA_HOME is not supported by this patch. Recheck
  bundle assertions and recurrence on package upgrades.
- **Separate scope:** upstream has an XDG state logs patch; its presence in the
  pinned binary was not verified. Local changes do not relocate remote SSH data.
- **Rollback:** revert the package override; do not discard newer application data.
- **Sources:** [XDG issue #2825](https://github.com/VSCodium/vscodium/issues/2825),
  [logs issue #1903](https://github.com/VSCodium/vscodium/issues/1903),
  [logs PR #2636](https://github.com/VSCodium/vscodium/pull/2636).
  Context7 `/vscodium/vscodium` yielded portable-mode docs, not a complete XDG fix.

## NVIDIA — `~/.nv`

- **Found:** NVIDIA driver 595.71.05, RTX 3060 Laptop. `.nv` is mixed:
  empty `ComputeCache` and configuration file
  `nvidia-application-profiles-rc.d/10-gsr-cuda-no-stable-perf-limit`.
  Profile contents were not read.
- **Existing setting:** `home-manager/shared/common/home-declutter.nix` already
  sets `CUDA_CACHE_PATH=$XDG_CACHE_HOME/nv`; current environment agrees. This
  redirects CUDA JIT cache, not necessarily graphics caches or profiles.
- **Producer:** GPU Screen Recorder explicitly writes the named profile to
  `$HOME/.nv/nvidia-application-profiles-rc.d` in its `src/main.cpp`.
- **Attempt:** a synthetic directory-symlink test redirects profile writes into
  a config directory, but leaves `.nv` in home and does not test NVIDIA loading.
  It does not meet the clutter-removal goal; no production change made.
- **Follow-up:** NVIDIA 595.71.05 docs support profiles under `/etc/nvidia` and
  `/usr/share/nvidia` as well as the user paths, but no documented custom search
  path was found. A system profile could preserve driver behavior, provided GSR's
  user-profile write is suppressed. Whether GSR already skips equivalent system
  profiles has not been established.
- **Pinned GSR 5.13.8:** `install_cuda_no_stable_perf_limit()` runs before argument
  parsing, unconditionally creating the directory and rewriting the profile with
  `fopen(..., "wb")`. No existing-system-profile check, disable flag, or cleanup.
- **Test:** compiled upstream installer/helper against synthetic homes. Original
  code created/overwrote profiles; removing the startup call prevented `.nv`
  creation on repeated runs and preserved synthetic existing files. No GPU work.
- **Implemented (user-approved):** `hosts/horus/gsr.nix` installs upstream's
  GSR-only `0x166c5e = 0` profile under
  `/etc/nvidia/nvidia-application-profiles-rc.d/10-gsr-cuda-no-stable-perf-limit`
  and a host-local package overlay removes the startup call fail-fast. DMS's
  native GSR route uses the patched package too. Existing
  `CUDA_DISABLE_PERF_BOOST=1` behavior is unchanged.
- **Validation:** package/profile build passes; generated profile is byte-identical
  to pinned upstream and JSON assertions pass. Repeated isolated `--version`
  launches create no `.nv` and preserve existing synthetic files. Formatting and
  flake check (--no-build) pass. No GPU workload or real profile edits.
- **Next:** switch and test recording/performance with the driver-loaded system
  profile. Existing user profile has not been removed; retire it only after
  confirming the replacement is active.
- **Rollback:** no change applied; reverting CUDA_CACHE_PATH restores its default.
- **Sources:** [CUDA environment variables](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/environment-variables.html),
  [GSR source](https://github.com/antonlobanovskiy/gpu-screen-recorder/blob/master/src/main.cpp),
  [xdg-ninja CUDA rule](https://github.com/b3nj5m1n/xdg-ninja/blob/main/programs/cuda.json).
  The rule overlooks mixed profile data on this host. Context7 did not return
  relevant CUDA docs; prior kernel-module issue searches found no applicable fix.

## OCI CLI — `~/.oci`

- **Found:** real directory with `config` (0600) and `sessions/`; no credential
  contents read. CLI absent from PATH and evaluated Home Manager packages;
  installed version unknown.
- **Candidate:** `OCI_CLI_CONFIG_FILE` selects config, `OCI_CLI_RC_FILE` selects
  CLI defaults. These alone do not establish relocation of keys and sessions.
  Inspected Python SDK source checks existing default config before its env
  fallback; CLI/SDK behavior must be tested separately.
- **Test:** OCI CLI 3.82.0 / SDK 2.165.1, isolated fake HOME and synthetic identities.
  Setup with default paths completed in a controlling PTY, writing config and
  matching RSA keys to `$FAKE_HOME/.oci` (0600). SDK loaded/validated that config.
  Installed session helpers resolve tokens/keys under `$FAKE_HOME/.oci/sessions`;
  verified path computation/source only, not live authentication. Initial piped
  input failed at getpass; proper PTY and `N/A` passphrase responses fixed it.
  No authentication/API calls; all test keys/homes cleaned up.
- **Implemented (user-approved):** shared Home Manager installs an `oci` wrapper
  in `home-declutter.nix`, setting process-local HOME to the configured absolute
  `${config.xdg.dataHome}/oci-cli/home`. Existing XDG values are preserved and
  unset/empty values default to configured real-home paths. Runtime/session
  variables, OCI overrides, and arguments are preserved; wrapper execs OCI CLI.
  Activation creates both private parent and home directories with mode 0700.
- **Wrapper tests:** build/version (3.82.0), paths containing spaces, argument
  forwarding, overrides, parent-shell isolation, exit status, and directory
  permissions passed. Formatting and flake check (--no-build) passed.
- **Live check:** current deployed profile has no `oci` on PATH; wrapper is built
  but still needs a switch. Redacted local inspection found two absolute
  credential references into the original `.oci`, both pointing to existing
  files. No credential values were printed.
- **Next:** deploy when requested, then migrate real profiles/keys/tokens under
  a separately approved plan or authenticate afresh. Existing `~/.oci` is not
  copied automatically; embedded absolute paths and independent SDK callers need
  review. No private key/token contents were read or cloud resources changed.
- **Migration constraint:** a protected, non-overwriting copy preserves the old
  state, but the copied config's absolute key/token references must also be
  remapped before retiring the old directory. No copy or migration performed.
- **Rollback:** revert overrides; keep existing credentials and sessions intact.
- **Sources:** [CLI setup](https://github.com/oracle/oci-cli/blob/master/src/oci_cli/cli_setup.py),
  [CLI entry point](https://github.com/oracle/oci-cli/blob/master/src/oci_cli/cli_root.py),
  [Python SDK config](https://github.com/oracle/oci-python-sdk/blob/master/src/oci/config.py).
  Context7 `/oracle/oci-cli` confirmed config mechanisms. No applicable xdg-ninja
  rule or relocation issue was found in prior targeted searches.

## PARSEC — `~/.parsec` AND `~/.parsec-persistent`

- **Found:** proprietary `parsec-bin-150_97c`, declared in
  `home-manager/shared/desktop/apps.nix`. Both directories are real, mode 0755.
  `.parsec` contains mixed config/state/logs; `.parsec-persistent` contains
  `devid.bin` and `status.json` (contents not read; exact role unconfirmed).
- **Packaging:** launcher seeds `$HOME/.parsec` when `appdata.json` is absent.
  Desktop/URI entry invokes `parsecd %u`.
- **Failed attempt:** initial fake-HOME launch seeded a temporary `.parsec`, but
  a follow-up trace showed the actual binary still accessed real `.parsec` and
  checked real `.parsec-persistent`, including opening the real log for writing.
  No identity/token/status contents were read or authentication attempted. HOME
  alone does not isolate this app; do not repeat that test without path isolation.
- **Proven identity role:** static inspection of the installed bundled library
  found `devid.bin`'s `device_id` used for the `X-Parsec-Device-ID` HTTP header.
  This is durable device identity, plausibly involved in device recognition/auth,
  not proof it stores login credentials. `status.json` remains unexplained.
- **Root cause:** both library and launcher's `MTY_GetDir` resolve home via
  `getuid()`/`getpwuid()` and `pw_dir`, bypassing the HOME environment variable.
  No supported override surfaced in inspected code/docs.
- **Superseded attempt:** custom bubblewrap wrapper passed protected app/state
  tests, but required home scaffolding with ephemeral unrelated entries and
  restrictions on atomic replacement of top-level files. Replaced by maintained
  Flatpak packaging; removed the custom `parsec.nix` and native package/import.
- **Implemented (user-approved):** `com.parsecgaming.parsec` added to existing
  declarative packages in `modules/desktop/flatpak.nix` and installed system-wide
  on horus. No duplicate user installation. Native deployed launcher remains
  until the next switch; explicitly run `flatpak run --system com.parsecgaming.parsec`.
- **Tests:** protected offline/display-disabled launch exited successfully and
  wrote under `~/.var/app/com.parsecgaming.parsec`; legacy directory timestamps
  unchanged. Home Manager and Flatpak installer builds, formatting, and flake
  checks pass. No login, real-state migration or whole-system deployment.
- **Next:** interactive GUI/login/streaming test. Fresh login may register a new
  device identity; preserve existing state until deciding on migration.
- **Rollback:** remove the declarative Flatpak entry and restore native packaging;
  preserve both old and Flatpak state rather than uninstalling with data deletion.
- **Sources:** [Parsec Linux guide](https://support.parsec.app/hc/en-us/articles/32381494397332-Parsec-App-for-Linux),
  [xdg-ninja rule](https://github.com/b3nj5m1n/xdg-ninja/blob/main/programs/parsec.json).
  Context7 matched an unrelated parser library; use vendor docs instead.
- **Flatpak mechanism:** current [Flathub manifest](https://github.com/flathub/com.parsecgaming.parsec/blob/master/com.parsecgaming.parsec.yml)
  uses `--persist=.` without host/home filesystem access, specifically to retain
  login/settings from hardcoded home paths. Flatpak manages the persistent home
  under `~/.var/app/com.parsecgaming.parsec`, avoiding bespoke home scaffolding.
  Manifest requests X11, PulseAudio, network, all devices and notifications.
  Login/streaming still needs testing. Do not grant host/home access,
  which defeats this persistence mechanism. Verified manifest and Flatpak persist
  documentation through Context7 `/flatpak/flatpak-docs` on 2026-10-16.

## LOGGING CONVENTIONS

Keep entries short: finding, attempted fix, actual test result, next action,
rollback, and useful source links. Preserve failed attempts; omit empty template
fields and repeated boilerplate. Do not log secrets or user history contents.
Use [ArchWiki](https://wiki.archlinux.org/title/XDG_Base_Directory),
[XDG spec](https://specifications.freedesktop.org/basedir-spec/latest/), Context7,
xdg-ninja and upstream issues as needed, not as an exhaustive per-case checklist.

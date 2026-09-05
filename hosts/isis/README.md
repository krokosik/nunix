# ISIS — SURFACE PRO 8

Prepared on `surfacewk` on 2026-09-05. The NixOS hostname will be `isis`.
The kernel and complete system must be built on the more powerful machine
before installation. Nothing has been repartitioned, installed, or booted.

## DISK AND MIGRATION

The hardware report identifies an 8 GB Surface Pro 8 (about 7.6 GiB usable RAM)
with a 128 GB SK hynix SSD (118.3 GiB). Disko targets its persistent NVMe ID,
including the namespace suffix `_1`, recorded in `facter.json`.

| Partition | Size | Contents |
| --- | --- | --- |
| EFI | 2 GiB | FAT32, `/boot`, restrictive mount permissions |
| Root | Remaining space before swap, about 106 GiB | LUKS → Btrfs |
| Swap | 10 GiB | Persistent LUKS → swap, `/dev/mapper/cryptswap` |

This follows Horus: separate Btrfs subvolumes for `/`, `/home`, `/nix`, and
`/var/log`, with zstd compression and noatime. There is no Windows partition,
mount, or boot entry. The smaller swap still exceeds physical RAM and provides
headroom for a hibernation image. Runtime swap occupancy can reduce that
headroom; successful resume still needs testing. A smaller swap or zram-only
layout is an alternative if hibernation is dropped.

**Executing Disko destroys the current installation on this SSD.** Back up and
verify restoration of home data, SSH and age identities, application profiles,
and both repositories first. Preserve the existing LUKS recovery material and
any Secure Boot signing keys separately. The existing Arch partition layout is
not converted in place. Use the same strong passphrase for both new LUKS
containers if you want initrd password caching to avoid a second prompt.

Discards remain enabled through LUKS, matching Horus and allowing SSD trimming.
This exposes allocation/discard patterns, although not plaintext. Disable them
on both containers if hiding those patterns matters more than trimming.

## HARDWARE REPORT AND INPUT

`facter.json` was generated on this actual device using:

```sh
run0 nix run github:numtide/nixos-facter/bea5e52d673995f35ad26624f9882ff5821e9689 -- --output /home/krokosik/work/nunix/hosts/isis/facter.json
```

Do not regenerate it on the build machine. Ephemeral filesystem and swap
capture was not enabled; Disko owns the target layout.

`91-calibration-045E-0C37.conf` is a byte-for-byte copy of the current
`/etc/iptsd.d/91-calibration-045E-0C37.conf`. It preserves device matching,
contact size 0.600–1.500, aspect ratio 1.000–1.700, and palm/stylus suppression.
Nix installs it under the same `/etc/iptsd.d/` path and restarts iptsd instances
when it changes. The old main config contains only comments and section headers;
the NixOS module supplies its replacement. Future recalibration results belong
in the repository because the installed file is immutable. See the
[iptsd calibration guide](https://github.com/linux-surface/iptsd/wiki/Calibrating-iptsd).

The initrd includes Surface Aggregator/HID, Intel serial/GPIO, and USB keyboard
drivers for disk unlocking. **Touch-only unlocking is not configured**: regular
iptsd runs after the root filesystem is available, and Plymouth does not supply
an on-screen keyboard. Test the Type Cover at a cold-boot LUKS prompt and keep a
USB keyboard available. An initrd with iptsd and an on-screen keyboard would be
a separate extension. See the [disk encryption notes](https://github.com/linux-surface/linux-surface/wiki/Disk-Encryption).

## SURFACE SUPPORT AND CAMERA

The pinned `microsoft-surface-pro-intel` module builds Linux 6.19.8 with the
linux-surface patch set. Both its `stable` and `longterm` choices currently
resolve to that same version; the labels do not guarantee a current LTS kernel.
Intel microcode, redistributable firmware, iptsd, IIO sensor support, and
thermald are enabled. A host-local libwacom override supplies the Surface
virtual-bus support and tablet definitions to applications. These implement the
relevant [post-installation recommendations](https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup#post-installation).

**There is no upstream surface-control daemon.** The pinned NixOS hardware module
installs the `surface` CLI; its older README's service-option names are stale.
Use `surface status` and `surface profile get` for inspection. TLP and `tlp-pd`
provide automatic policy and the desktop power-profile interface. A Surface Book
detachment daemon is not applicable to this tablet. See
[surface-control](https://github.com/linux-surface/surface-control).

All 29 comments in [PR #2171](https://github.com/linux-surface/linux-surface/pull/2171)
were read using `gh api --paginate`, along with the PR body; the review and inline
comment lists were empty. The initial `0x2d` write evolved into a bit-5-only
read-modify-write. The local patch backports that behavior, gated to the exact
Surface Pro 8 DMI identity, before every stream-on. It preserves other register
bits and propagates I2C errors. It is **not** the full upstream v4 bridge-property
series. Replace it when the selected kernel includes the upstream solution.

The Nix kernel derivation includes the patch after the Surface patches and enables
the in-tree IPU6 driver. Libcamera and PipeWire use the software ISP path;
Facter's generic proprietary IPU6 HAL/relay setup is disabled for this host.
Camera-monitor startup is optional so its failure does not make audio startup
depend on the experimental camera stack.

After booting the built kernel, capture twice in the same boot, including a
resolution change, and check actual images. Reboot between kernel versions;
live module replacement can leave stale camera graph state. Streaming success
does not establish tuning quality, binned-mode reliability, rear/IR support, or
compatibility with every conferencing application. These remain hardware checks.

## POWER MANAGEMENT

`power.nix` is a conservative starting policy for the pinned TLP 1.9.1, with its
three AC/BAT/SAV profiles. It does not import the old generic `modules/power.nix`.

* Intel HWP uses `powersave` in all profiles. This governor still scales and
  boosts; it does not lock the CPU to its lowest frequency. EPP changes from
  `balance_performance` to `balance_power` and `power`. There is no arbitrary
  frequency ceiling or forced turbo disable. See [TLP processor settings](https://linrunner.de/tlp/settings/processor.html).
* The measured firmware profile choices include `balanced` and `low-power`.
  Balanced is selected on AC and battery, low-power in saver mode. The generic
  Surface thermald configuration is retained; investigate adaptive DPTF mode if
  its conservative thermal threshold unnecessarily limits sustained work.
  See [TLP platform settings](https://linrunner.de/tlp/settings/platform.html).
* Power-profiles-daemon, auto-cpufreq, and PowerTOP auto-tuning are disabled.
  Thermald handles temperature while TLP handles policy. `tlp-pd` exposes the
  desktop profile interface without running a second competing manager.
  See [TLP conflicts](https://linrunner.de/tlp/faq/conflicts.html).
* PCI runtime PM, USB autosuspend, and Wi-Fi power saving start disabled; ASPM
  retains firmware policy. This favors a reliable first installation and may
  cost battery life. After measuring idle and suspend drain, enable PCI runtime
  PM and USB autosuspend separately, retaining exceptions only for devices that
  fail repeated camera, touch, dock, Bluetooth, or resume tests. Input and audio
  USB devices already have default exclusions in TLP. See
  [PCI power management](https://linrunner.de/tlp/settings/runtimepm.html) and
  [USB autosuspend](https://linrunner.de/tlp/settings/usb.html).

No 75/80% charge thresholds are assumed: the current battery sysfs interface
does not expose threshold controls. Check `tlp-stat --battery` on NixOS before
adding any. Firmware Battery Limit, if available, is a separate fixed-limit
alternative for prolonged docked use. TLP cannot invent unsupported thresholds;
see [battery care](https://linrunner.de/tlp/settings/battery.html).

Wi-Fi is explicitly enabled at boot with `DEVICES_TO_ENABLE_ON_STARTUP="wifi"`,
as described in the [ArchWiki TLP guide](https://wiki.archlinux.org/title/TLP#Enable_Wi-Fi_radio_on_boot).
The `WIFI_PWR_*="off"` settings disable power saving, not the radio. TLP's
previous-radio-state restoration remains disabled by default, and the NixOS
TLP module disables the competing systemd-rfkill service and socket. A saved
NetworkManager connection with autoconnect and available credentials is still
needed to join a network automatically. See [upstream radio settings](https://linrunner.de/tlp/settings/radio.html).

## INSTALLATION GATES AND RISKS

1. **Secrets:** this machine's flake uses a private Git input through the
   `github-secrets` SSH alias, which is unavailable here. The local
   `~/work/nunix-secrets` checkout also lacks `isis/`. Provision the host's
   `isis/secrets.yaml` and `isis/home.yaml`, its decryption recipients, and the
   shared files required by the imported modules on the build machine. Required
   system keys include `login_password_hash` and `home_manager_age_key`; the
   shared `nix_access_token` and `niks3/api_token` are also used. Home Manager
   needs the Syncthing key/certificate in `isis/home.yaml` and shared credentials
   in `common/home.yaml`. Preserve/provision the corresponding
   root SSH/age identity before first activation. Never put plaintext secrets
   into this flake. Commit/push secret changes and update `my-secrets` in
   `flake.lock` before building; this session has not changed that input.
2. **Secure Boot:** Limine signing and key generation are retained from Horus,
   but automatic firmware enrollment is disabled for this host. Check the
   Surface firmware's enrollment capabilities and existing keys before enabling
   enforcement. A newly generated key is not automatically trusted. The public
   linux-surface MOK does not sign this locally built kernel. A shim-based chain
   is an alternative if direct enrollment is unavailable, but needs separate
   setup. See [Surface Secure Boot](https://github.com/linux-surface/linux-surface/wiki/Secure-Boot).
3. **Hibernation:** encrypted swap and initrd resume are wired, not hardware
   verified. Kernel lockdown may reject hibernation. The Surface patch set has
   a `lockdown_hibernate` bypass, deliberately not enabled here; review its
   security implications before choosing it. Do not disable Secure Boot just
   to make an untested resume path appear to work.
4. **Suspend:** the device advertises only `s2idle`; no forced S3/deep sleep is
   configured. Measure overnight drain, lid/type-cover behavior, and wakeups
   with accessories both attached and removed before relying on bag suspend.
   Prefer shutdown until those tests pass. See [kernel sleep states](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html).
5. **Firmware and display:** check firmware currency before erasing the existing
   installation; fwupd is enabled but does not promise all Microsoft firmware
   updates. Keep recovery media. The SP8 wiki's EDID workaround removes 60 Hz,
   so do not apply it preemptively. First test native resolution, scaling,
   rotation, 60/120 Hz, and external displays. IIO availability alone does not
   configure compositor rotation. See the [SP8 notes](https://github.com/linux-surface/linux-surface/wiki/Surface-Pro-8).
6. **Desktop migration:** shared Hyprland configuration still contains Horus
   monitor descriptions and DMS-generated output settings. Review those on this
   device; the iptsd migration is complete, but this is not a wholesale migration
   of Arch/Omarchy application data or per-user desktop state.
7. **Kernel upkeep:** the pinned custom kernel requires periodic security review
   and rebuilds. Build on the stronger machine, retain a known-good generation,
   and keep rescue media that can unlock Btrfs/LUKS with a USB keyboard. Space
   for the build and retained closures matters on this 128 GB SSD.

## VALIDATION AND HANDOFF

Completed here: actual-device Facter scan, exact calibration copy comparison,
initial Nix host evaluation with no failed assertions, and clean application
of the local patch after the pinned Surface camera changes to the matching
6.19.8 driver source (zero fuzz). Evaluation used a temporary
local-secrets input override and is not proof that secrets can be installed.
The complete Surface-patched kernel, modules, initrd, and system have not been
built or tested on hardware. The final targeted evaluation passed for the kernel
derivation, Surface libwacom override, LUKS/resume settings, and power/input
services with build execution disabled. Full desktop assertion checking requires a
theme-generation derivation, so the final checks prohibit builds and cover the
hardware settings directly. Builds were deferred at the user's request.

On the stronger machine, after transferring **all new host files** and fixing
the secrets input, run from the repository:

```sh
nix fmt .
nix flake check --no-build
nix build .#nixosConfigurations.isis.config.boot.kernelPackages.kernel --out-link result-isis-kernel
nix build .#nixosConfigurations.isis.config.system.build.toplevel --out-link result-isis
```

Git flakes omit untracked files, so include the new files in the checkout
before evaluating `.#nixosConfigurations.isis`. The tablet's `nix.settings` limits apply after
deployment; they do not restrict the build machine's daemon. Build success
must precede a separately reviewed Disko/install operation. The existing
`just deploy-new` recipe regenerates Facter and performs installation, so it
is not a build-only handoff command.

After installation, inspect without changing power or camera state:

```sh
uname --kernel-release
surface status
surface profile get
systemctl list-units 'iptsd@*.service'
systemctl show tlp.service -P ActiveState -P SubState
systemctl show thermald.service -P ActiveState -P SubState
run0 tlp-stat --system --processor --battery
cam --list
```

Then explicitly test cold-boot unlock, pen/palm behavior, two consecutive
camera captures, AC/battery profile switching, suspend/resume, and hibernation.
Keep the existing system backup until those tests pass.

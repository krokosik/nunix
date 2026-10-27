# Surface Pro 8 color cameras

`../cameras.nix` keeps the native IPU6 ISYS driver and libcamera software ISP.
It adds OV5693 analogue binning, OV13858 rotation/flip controls, and the
software ISP processing fixes from the pinned camera repository. IR is omitted.
The host-wide libcamera overlay also reaches PipeWire and its SPA plugin.

## Calibration

The firmware IDs read on isis are MSHW0260 (front), MSHW0261 (rear), and
MSHW0262 (IR). `tuning.nix` downloads a hash-pinned Microsoft Surface Pro 8
driver MSI and extracts only:

- `OV5693_MSHW0260_TGL.aiqb`
- `OV13858_MSHW0261_TGL.aiqb`

It generates `ov5693.yaml` and `ov13858.yaml` using the pinned repository's
`factory-tuning.py`. They are installed into libcamera's own data directory,
so normal camera clients need no tuning environment variables. The original
blobs are retained under `/etc/libcamera/surface-pro-8/aiqb` after deployment.
They are tuning for the identified module variants, not a measurement of this
individual tablet. No Microsoft blobs or derived YAML are committed here.

The rear tuning assumes a zero sensor black-level target; the accompanying
kernel patch programs that target after each mode table. The front tuning
retains the generator's pedestal workaround. Factory color correction remains
imperfect, and this software ISP does not provide the complete Windows lens
shading, noise reduction, or sharpening pipeline.

## Kernel patches

- `ov5693-surface-pro-8-binning.patch`: OV5693 portion of linux-surface PR
  [2252](https://github.com/linux-surface/linux-surface/pull/2252), extracted
  from patch commit `d5253e9181f6d392468dfcd454ffdd98fe7a13ee`.
  The unconditional MIPI register write was removed to retain our existing
  DMI-scoped clock-gating patch. The binned mode defaults to even Y offset
  (BGGR) and caps the calculated frame rate at 30 fps.
- `ov13858-surface-rotation.patch`: rear rotation and Bayer-preserving sensor
  flips from linux-surface PR
  [2227](https://github.com/linux-surface/linux-surface/pull/2227), patch commit
  `3d5baacb32a70d974c5617b7f11911bdc5bb1565`.
- `ov13858-surface-black-level.patch`: zero BLC target from the pinned camera
  repository, matching its generated rear tuning.

These apply after nixos-hardware's Surface patches for Linux 6.19.8. Recheck
them when updating the Surface kernel; remove local changes once upstream
includes equivalent fixes. The old driver's missing OV13858 selection API is
not repaired here; libcamera currently supplies fallback crop properties.

## Verification after deployment and reboot

List cameras and request 1280x960 output from the front camera's 1296x972
binned sensor mode. The software debayer crops a few edge pixels, so requesting
1296 output pixels can instead select the full-resolution sensor mode.
Output resolution alone does not prove sensor binning: inspect
the selected sensor format in libcamera logs or the media graph while active.

```bash
cam --list
cam --camera 2 --stream width=1280,height=960 --capture=60
cam --camera 1 --stream width=1280,height=720 --capture=60
media-ctl --print-topology
```

`--capture` without `--file` discards frames. Camera indices can change; select
the front/back IDs reported by `cam --list` if needed. Repeat capture to check
restart behavior. Confirm the logs load `ov5693.yaml` and `ov13858.yaml` rather
than `uncalibrated.yaml`, then check indoor/daylight colors and rear orientation
in the desktop camera application.

Keep PipeWire as the first application path. V4L2-only applications may need
an additional on-demand v4l2-relayd/v4l2loopback setup; it is not enabled here.
If cameras disappear only after boot, inspect software ISP DMA allocation and
logind device ACL timing before adding broader device permissions.

## Sources

- [Camera repository](https://github.com/fildunsky/linux-surface-pro8-cameras/tree/6fe8974fba84d7abbe4f1df6c23e6f5edfd4699c)
- [Microsoft Surface Pro 8 downloads](https://www.microsoft.com/en-us/download/details.aspx?id=103503)

The upstream calibration guide's download ID 104114 is incorrect; use 103503.
When updating the MSI, update its hash and verify its File-table identifiers
before changing the two hardcoded extraction keys in `tuning.nix`.

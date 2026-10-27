{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkAfter;
in
{
  # Keep mainline ISYS and libcamera's software ISP instead of Facter's HAL stack.
  hardware.facter.detected.camera.ipu6.enable = false;

  # Preserve the original calibration alongside the generated libcamera YAML.
  environment.etc."libcamera/surface-pro-8/aiqb".source = pkgs.libcamera.surfaceCameraTuning.blobs;

  boot.kernelPatches = mkAfter [
    {
      name = "surface-pro-8-ov5693-binning";
      patch = ./patches/ov5693-surface-pro-8-binning.patch;
    }
    {
      name = "surface-pro-8-ov5693-clock-gate";
      patch = ./patches/ov5693-surface-pro-8-clock-gate.patch;
      structuredExtraConfig = {
        VIDEO_INTEL_IPU6 = lib.kernel.module;
      };
    }
    {
      name = "surface-pro-8-ov13858-rotation";
      patch = ./patches/ov13858-surface-rotation.patch;
    }
    {
      name = "surface-pro-8-ov13858-black-level";
      patch = ./patches/ov13858-surface-black-level.patch;
    }
  ];

  # The overlay also rebuilds PipeWire's libcamera SPA plugin against this build.
  # Installing only a separate cam executable would leave applications untuned.
  nixpkgs.overlays = singleton (
    _final: prev:
    let
      cameraSource = prev.callPackage ./cameras/source.nix { };
      tuning = prev.callPackage ./cameras/tuning.nix {
        inherit cameraSource;
        # PipeWire's 32-bit compatibility build also evaluates this overlay.
        # nixpkgs' default assembler is unavailable on i686.
        _7zz = prev._7zz.override { useAsmc = prev.stdenv.hostPlatform.isx86_64; };
      };
    in
    {
      libcamera = prev.libcamera.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          "${cameraSource}/patches/libcamera/softisp-agc-proportional.patch"
          "${cameraSource}/patches/libcamera/softisp-fix-black-level-order.patch"
          "${cameraSource}/patches/libcamera/softisp-split-awb-from-ccm.patch"
          "${cameraSource}/patches/libcamera/softisp-awb-use-libipa-bayes.patch"
          "${cameraSource}/patches/libcamera/softisp-stats-sums-to-8bit.patch"
          "${cameraSource}/patches/libcamera/softisp-agc-gain-floor.patch"
        ];
        postInstall = (old.postInstall or "") + /* bash */ ''
          install --mode=0644 ${tuning}/*.yaml "$out/share/libcamera/ipa/simple/"
        '';
        passthru = (old.passthru or { }) // {
          surfaceCameraTuning = tuning;
        };
      });
    }
  );

  services.pipewire.wireplumber.extraConfig."10-surface-camera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "wanted";
  };
}

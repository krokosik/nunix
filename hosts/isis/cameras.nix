{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkAfter;

  cameraSource = pkgs.callPackage ./cameras/source.nix { };
  tuning = pkgs.callPackage ./cameras/tuning.nix {
    inherit cameraSource;
  };
  surfaceLibcamera = pkgs.libcamera.overrideAttrs (old: {
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
  });
in
{
  # Keep mainline ISYS and libcamera's software ISP instead of Facter's HAL stack.
  hardware.facter.detected.camera.ipu6.enable = false;

  # Preserve the original calibration alongside the generated libcamera YAML.
  environment.etc."libcamera/surface-pro-8/aiqb".source = tuning.blobs;

  environment.systemPackages = singleton surfaceLibcamera;

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

  # Scope the tuned camera stack to the services. Overriding pkgs.libcamera
  # globally also changes application libraries through PipeWire and GStreamer.
  services.pipewire.package = pkgs.pipewire.override { libcamera = surfaceLibcamera; };

  services.pipewire.wireplumber.package = pkgs.wireplumber.override {
    pipewire = config.services.pipewire.package;
  };

  services.pipewire.wireplumber.extraConfig."10-surface-camera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "wanted";
  };
}

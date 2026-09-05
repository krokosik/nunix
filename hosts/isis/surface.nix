{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkAfter;
in
{
  # INPUT
  services.iptsd = {
    enable = true;
    config.Touchscreen = {
      DisableOnPalm = true;
      DisableOnStylus = true;
    };
  };

  environment.etc."iptsd.d/91-calibration-045E-0C37.conf".source = ./91-calibration-045E-0C37.conf;

  systemd.services."iptsd@".restartTriggers = singleton (
    config.environment.etc."iptsd.d/91-calibration-045E-0C37.conf".source
  );

  # The Type Cover and a USB keyboard must work at the LUKS prompt.
  boot.initrd.availableKernelModules = [
    "pinctrl_tigerlake"
    "intel_lpss_pci"
    "8250_dw"
    "surface_aggregator"
    "surface_aggregator_registry"
    "surface_aggregator_hub"
    "surface_hid_core"
    "surface_hid"
    "hid_multitouch"
    "usbhid"
    "xhci_pci"
  ];

  # This device advertises s2idle only; deep/S3 is unavailable.
  boot.kernelParams = singleton "mem_sleep_default=s2idle";

  # CAMERAS
  # Use the in-tree ISYS driver and libcamera's software ISP. Facter's generic
  # IPU6 module installs a different proprietary HAL/relay stack.
  hardware.facter.detected.camera.ipu6.enable = false;

  boot.kernelPatches = mkAfter (singleton {
    name = "surface-pro-8-ov5693-clock-gate";
    patch = ./patches/ov5693-surface-pro-8-clock-gate.patch;
    structuredExtraConfig = {
      VIDEO_INTEL_IPU6 = lib.kernel.module;
    };
  });

  services.pipewire.wireplumber.extraConfig."10-surface-camera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "wanted";
  };

  # iptsd exposes virtual input devices; applications need libwacom's Surface
  # bus support as well as its tablet definitions. Keep this override host-local.
  nixpkgs.overlays = singleton (
    _final: prev: {
      libwacom = prev.callPackage "${inputs.nixpkgs}/pkgs/by-name/li/libwacom-surface/package.nix" {
        libwacom = prev.libwacom;
      };
    }
  );

  # FIRMWARE AND TOOLS
  hardware.cpu.intel.updateMicrocode = true;

  hardware.enableRedistributableFirmware = true;

  # iio-hyprland consumes accelerometer orientation from iio-sensor-proxy.
  hardware.sensor.iio.enable = true;

  # surface-control is a CLI, not a daemon. TLP owns automatic profile changes.
  environment.systemPackages = [
    pkgs.surface-control
    pkgs.iptsd
    pkgs.libcamera
    pkgs.v4l-utils
  ];
}

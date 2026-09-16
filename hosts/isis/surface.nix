{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkAfter;

  rdmsr = getExe' pkgs.msr-tools "rdmsr";
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

  # The default also includes --firmware-builtin
  boot.loader.limine.secureBoot.autoEnrollKeys.extraArgs = singleton "--microsoft";

  # FIRMWARE AND TOOLS
  hardware.cpu.intel.updateMicrocode = true;

  hardware.enableRedistributableFirmware = true;

  # Capture firmware-enforced CPU limits during the first minute after boot.
  boot.kernelModules = singleton "msr";

  systemd.services.surface-power-diagnostics = {
    description = "Record Surface CPU power and throttle state after boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];

    serviceConfig = {
      Type = "simple";
      Nice = 19;
      IOSchedulingClass = "idle";
      NoNewPrivileges = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };

    script = /* bash */ ''
      snapshot() {
        printf 'snapshot=%s monotonic=%s\n' "$1" "$(cut --delimiter=' ' --fields=1 /proc/uptime)"

        for file in \
          /sys/devices/system/cpu/cpufreq/policy0/scaling_driver \
          /sys/devices/system/cpu/cpufreq/policy0/scaling_governor \
          /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference \
          /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq \
          /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq \
          /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq \
          /sys/devices/system/cpu/intel_pstate/status \
          /sys/devices/system/cpu/intel_pstate/no_turbo \
          /sys/devices/system/cpu/intel_pstate/min_perf_pct \
          /sys/devices/system/cpu/intel_pstate/max_perf_pct \
          /sys/firmware/acpi/platform_profile \
          /sys/class/power_supply/ADP*/online \
          /sys/class/power_supply/BAT*/status \
          /sys/class/power_supply/BAT*/capacity \
          /sys/class/power_supply/BAT*/voltage_now \
          /sys/class/power_supply/BAT*/power_now \
          /sys/class/powercap/intel-rapl:0/enabled \
          /sys/class/powercap/intel-rapl:0/constraint_*_name \
          /sys/class/powercap/intel-rapl:0/constraint_*_power_limit_uw; do
          if [[ -r "$file" ]]; then
            printf '%s=%s\n' "$file" "$(<"$file")"
          fi
        done

        for zone in /sys/class/thermal/thermal_zone*; do
          if [[ -r "$zone/type" && -r "$zone/temp" ]]; then
            printf '%s type=%s temp=%s\n' "$zone" "$(<"$zone/type")" "$(<"$zone/temp")"
          fi
        done

        for device in /sys/class/thermal/cooling_device*; do
          if [[ -r "$device/type" && -r "$device/cur_state" ]]; then
            printf '%s type=%s state=%s/%s\n' \
              "$device" "$(<"$device/type")" "$(<"$device/cur_state")" "$(<"$device/max_state")"
          fi
        done

        for register in 0x19c 0x1b1 0x610 0x64f 0x771 0x774 0x777; do
          printf 'msr[%s]=' "$register"
          ${rdmsr} --all --zero-pad --hexadecimal "$register" || true
        done
      }

      printf 'surface-power-diagnostics start\n'
      ${getExe pkgs.linuxPackages.turbostat} \
        --quiet \
        --Summary \
        --interval 5 \
        --num_iterations 12 &
      turbostat_pid=$!

      for iteration in $(seq 0 12); do
        snapshot "$iteration"
        if (( iteration < 12 )); then
          sleep 5
        fi
      done

      wait "$turbostat_pid"
      printf 'surface-power-diagnostics complete\n'
    '';
  };

  # iio-hyprland consumes accelerometer orientation from iio-sensor-proxy.
  hardware.sensor.iio.enable = true;

  environment.systemPackages = [
    pkgs.surface-control
    pkgs.iptsd
    pkgs.libcamera
    pkgs.v4l-utils
  ];
}

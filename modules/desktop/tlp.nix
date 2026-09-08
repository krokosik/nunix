{ lib, ... }:
let
  inherit (lib.modules) mkForce;
in
{
  # One policy manager; thermald independently protects against overheating.
  services.power-profiles-daemon.enable = mkForce false;

  services.auto-cpufreq.enable = mkForce false;

  powerManagement.powertop.enable = mkForce false;

  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    pd.enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_SAV = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PLATFORM_PROFILE_ON_SAV = "low-power";

      # Preserve firmware PCIe policy until suspend/camera/dock testing passes.
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "default";
      PCIE_ASPM_ON_SAV = "default";

      # Avoid autosuspending the camera and touch controller during migration.
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "on";
      RUNTIME_PM_ON_SAV = "on";

      USB_AUTOSUSPEND = 0;

      # Enable the Wi-Fi radio at boot, independently of power-saving policy.
      DEVICES_TO_ENABLE_ON_STARTUP = "wifi";

      # Start with reliable Wi-Fi; measure before enabling power saving.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
      WIFI_PWR_ON_SAV = "off";
    };
  };
}

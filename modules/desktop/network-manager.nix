{
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  networking.wireless.iwd.settings.General.AddressRandomization = "network";

  services.resolved.enable = true;

  hardware.facter.detected.dhcp.enable = false;
}

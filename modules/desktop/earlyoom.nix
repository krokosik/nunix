{ config, ... }:
{
  services.systembus-notify.enable = config.services.earlyoom.enableNotifications;

  services.earlyoom = {
    enable = true;

    enableNotifications = true;

    extraArgs = [
      "--prefer"
      # earlyoom matches comm (15 bytes), so mattermost-desktop is truncated.
      "^([Mm]attermost(-desk)?|[Bb]eeper(texts)?|[Oo]bsidian|[Zz]otero(-bin)?|zen(-bin|-twilight)?|nix|python([0-9]+([.][0-9]+)*)?)$"
    ];
  };
}

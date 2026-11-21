{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  tvPkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  services.flatpak.enable = true;

  home-manager.users.tv.systemd.user.services.flatpak-repo = {
    Unit.Description = "Add the per-user Flathub remote";
    Service = {
      Type = "oneshot";
      ExecStart = "${getExe config.services.flatpak.package} remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
    };
    Install.WantedBy = singleton "default.target";
  };

  environment.systemPackages = with tvPkgs; [
    moonlight-qt
    jellyfin-desktop
    vacuum-tube
  ];
}

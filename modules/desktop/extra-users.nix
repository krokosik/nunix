{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) concatMapStringsSep;

  flatpakExe = getExe pkgs.flatpak;
  install = getExe' pkgs.coreutils "install";
  dmsFiles = [
    "DankMaterialShell/settings.json"
    "DankMaterialShell/zen.css"
    "hypr/dms/binds.conf"
    "hypr/dms/colors.conf"
    "hypr/dms/cursor.conf"
    "hypr/dms/layout.conf"
    "hypr/dms/outputs.conf"
    "hypr/dms/windowrules.conf"
  ];
  seedDmsConfig = username: /* bash */ ''
    ${install} \
      --directory \
      --owner=${username} \
      --group=${username} \
      --mode=0700 \
      "/home/${username}/.config/DankMaterialShell" \
      "/home/${username}/.config/hypr/dms"

    ${concatMapStringsSep "\n" (file: ''
      copy_if_missing \
        "/home/${config.username}/.config/${file}" \
        "/home/${username}/.config/${file}" \
        "${username}"
    '') dmsFiles}
  '';
in
{
  home-manager.users = genAttrs config.extraUsers (username: {
    imports = [ ../../home-manager/shared/desktop ];

    home.username = username;
    home.homeDirectory = "/home/${username}";

    home.packages = with pkgs; [
      flatpak
      bazaar
    ];

    programs.fish.shellAliases.flatpak = "${flatpakExe} --user";

    systemd.user.services.flatpak-repo = {
      Unit.Description = "Add the per-user Flathub remote";
      Service = {
        Type = "oneshot";
        ExecStart = "${flatpakExe} remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
      };
      Install.WantedBy = [ "default.target" ];
    };
  });

  services.flatpak.enable = config.extraUsers != [ ];

  system.activationScripts.seedExtraUserDms = {
    deps = [ "users" ];
    text = /* bash */ ''
      copy_if_missing() {
        local source="$1"
        local destination="$2"
        local owner="$3"

        if [[ -f "$source" && ! -e "$destination" ]]; then
          ${install} \
            --owner="$owner" \
            --group="$owner" \
            --mode=0600 \
            "$source" \
            "$destination"
        fi
      }

      ${concatMapStringsSep "\n" seedDmsConfig config.extraUsers}
    '';
  };
}

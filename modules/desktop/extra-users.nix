{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatMapStringsSep;

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
  });

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

{
  config,
  inputs,
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
  chown = getExe' pkgs.coreutils "chown";
  dmsHyprlandConfig = pkgs.callPackage (
    { runCommand }:
    runCommand "dms-hyprland-config" { } /* bash */ ''
      mkdir --parents "$out"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-colors.lua" "$out/colors.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-outputs.lua" "$out/outputs.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-layout.lua" "$out/layout.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-cursor.lua" "$out/cursor.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-binds.lua" "$out/binds.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-binds-user.lua" "$out/binds-user.lua"
      cp "${inputs.dms}/core/internal/config/embedded/hypr-windowrules.lua" "$out/windowrules.lua"
      substituteInPlace "$out/binds.lua" \
        --replace-fail '{{TERMINAL_COMMAND}}' 'uwsm-app -- ghostty'
    ''
  ) { };
  legacyDmsFiles = [
    "DankMaterialShell/settings.json"
    "DankMaterialShell/zen.css"
    "hypr/dms/binds.conf"
    "hypr/dms/colors.conf"
    "hypr/dms/cursor.conf"
    "hypr/dms/layout.conf"
    "hypr/dms/outputs.conf"
    "hypr/dms/windowrules.conf"
  ];
  dmsLuaFiles = [
    "binds.lua"
    "binds-user.lua"
    "colors.lua"
    "cursor.lua"
    "layout.lua"
    "outputs.lua"
    "windowrules.lua"
  ];
  dmsFiles = legacyDmsFiles ++ map (file: "hypr/dms/${file}") dmsLuaFiles;
  initializePrimaryDms = /* bash */ ''
    ${install} \
      --directory \
      --owner=${config.username} \
      --group=${config.username} \
      --mode=0700 \
      "/home/${config.username}/.config/hypr/dms"

    # install --directory owns the final directory, but not parents it creates.
    ${chown} --no-dereference ${config.username}:${config.username} \
      "/home/${config.username}/.config" \
      "/home/${config.username}/.config/hypr"

    ${concatMapStringsSep "\n" (file: ''
      copy_if_missing \
        "${dmsHyprlandConfig}/${file}" \
        "/home/${config.username}/.config/hypr/dms/${file}" \
        "${config.username}"
    '') dmsLuaFiles}
  '';
  seedDmsConfig = username: /* bash */ ''
    ${install} \
      --directory \
      --owner=${username} \
      --group=${username} \
      --mode=0700 \
      "/home/${username}/.config/DankMaterialShell" \
      "/home/${username}/.config/hypr/dms"

    ${chown} --no-dereference ${username}:${username} \
      "/home/${username}/.config" \
      "/home/${username}/.config/hypr"

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

      ${initializePrimaryDms}

      ${concatMapStringsSep "\n" seedDmsConfig config.extraUsers}
    '';
  };
}

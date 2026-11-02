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
  preserveProfile = pkgs.writeShellApplication {
    name = "preserve-zen-profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.procps
    ];
    text = lib.fileContents ./zen-preserve-profile.sh;
  };
in
{
  imports = singleton inputs.zen-browser.homeModules.beta;

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    profiles.default.isDefault = true;
  };

  stylix.targets.zen-browser.profileNames = singleton "default";

  # Preserve files that Home Manager will stop owning before it cleans up links.
  # Remove once all desktops are migrated
  home.activation.preserveZenProfile =
    lib.hm.dag.entryBetween (singleton "linkGeneration") (singleton "writeBoundary")
      /* bash */ ''
        run ${getExe preserveProfile} \
          ${lib.escapeShellArg config.programs.zen-browser.profilesPath} \
          ${lib.escapeShellArg config.xdg.stateHome}
      '';
}

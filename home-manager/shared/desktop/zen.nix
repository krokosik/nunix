{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.hm.dag) entryBetween;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArg fileContents;
  preserveProfile = pkgs.writeShellApplication {
    name = "preserve-zen-profile";
    runtimeInputs = with pkgs; [
      coreutils
      gnutar
      procps
    ];
    text = fileContents ./zen-preserve-profile.sh;
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
    entryBetween (singleton "linkGeneration") (singleton "writeBoundary")
      /* bash */ ''
        run ${getExe preserveProfile} \
          ${escapeShellArg config.programs.zen-browser.profilesPath} \
          ${escapeShellArg config.xdg.stateHome}
      '';
}

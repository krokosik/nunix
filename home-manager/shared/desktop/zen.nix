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

  # Before Home Manager cleans up its links, preserve the files it will stop
  # owning.
  # Remove this once all desktops are migrated
  home.activation.preserveZenProfile =
    entryBetween (singleton "linkGeneration") (singleton "writeBoundary")
      /* bash */ ''
        run ${getExe preserveProfile} \
          ${escapeShellArg config.programs.zen-browser.profilesPath} \
          ${escapeShellArg config.xdg.stateHome}
      '';
}

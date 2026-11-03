{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) elem singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) getName;
  user = config.username;
  flakePath = "/home/${user}/work/nunix";
  cutExe = getExe' pkgs.coreutils "cut";
  gawkExe = getExe pkgs.gawk;
  gitExe = getExe config.programs.git.package;
  lessExe = getExe pkgs.less;
  nixExe = getExe config.nix.package;
  nixStoreExe = getExe' config.nix.package "nix-store";
  sortExe = getExe' pkgs.coreutils "sort";
in
{
  nix = {
    channel.enable = false;

    settings = {
      # ENABLE FLAKES
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # TRUSTED USERS
      trusted-users = [
        "root"
        "${user}"
      ];
      download-buffer-size = 500000000;

      # add extra cache substituters for binary cache access (e.g. cachix)
      substituters = [
        "https://nix-community.cachix.org/"
        "https://niks3.${config.privateDomain}"
      ];
      # add extra cache signing keys for binary cache access (e.g. cachix)
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3-1:hTt2LKPgxvboGPM2ZNZYLhuAkUQVJz9SmxDZh6vWqtw="
      ];
      connect-timeout = 2;
      fallback = true;

      use-xdg-base-directories = true;
    };

    # Add unstable to flake registry to use locally (e.g. `nix run nixpkgs-unstable#hatch`)
    registry.nixpkgs-unstable.flake = inputs.nixpkgs-unstable;

    optimise.automatic = true;
  };

  programs = {
    # ENABLE GIT
    git = {
      enable = true;
      package = pkgs.gitFull;

      config.safe."directory" = flakePath;
    };

    # ENABLE NH
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 4d";
      };
      flake = flakePath;
    };
  };

  environment = {
    sessionVariables.NIXOS_HOST = config.networking.hostName;

    shellAliases = {
      # SHOW NIX UPDATES
      nd = /* bash */ ''
        ${nixExe} profile diff-closures --profile /nix/var/nix/profiles/system |
              ${gawkExe} '/^Version [0-9]+ -> [0-9]+:$/ {block=""} {block=block $0 "\n"} END {print block}'
      '';
      # SHOW INSTALLED PACKAGES
      ni = "${nixStoreExe} --query --requisites /run/current-system/sw | ${cutExe} --delimiter=- --fields=2- | ${sortExe} | ${lessExe}";
      # PULL NUNIX AND NUNIX-SECRETS REPOS
      nl = "${gitExe} -C ${flakePath} pull";
    };

    systemPackages = singleton pkgs.nixfmt-tree;
  };

  # Allow unfree packages and pulling some packages from stable
  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      elem (getName pkg) [
        "beeper"
        # RTK 1.x includes BSL-licensed components.
        "rtk"
        "parsec-bin"
        "Wolfram_15.0.1.sh"
        "mathematica"
        "nvidia-x11"
        "nvidia-settings"
        "nvidia-kernel-modules"
        "obsidian"
        "vscode-extension-fill-labs-dependi"
        "vscode-extension-ms-vscode-remote-vscode-remote-extensionpack"
        "inventor"
        "inventor-overlay"
        "surface-pro-8-camera-tuning"
      ];
    packageOverrides = pkgs: {
      stable = import inputs.nixpkgs {
        config = config.nixpkgs.config;
        system = pkgs.stdenv.hostPlatform.system;
      };
      unstable = import inputs.nixpkgs-unstable {
        config = config.nixpkgs.config;
        system = pkgs.stdenv.hostPlatform.system;
      };
    };
    permittedInsecurePackages = [ ];
  };

  # SYSTEM MAINTENANCE
  # system.autoUpgrade = {
  #   enable = true;
  #   flake = "${flakePath}#${config.networking.hostName}";
  #   flags = [
  #     "-L"
  #   ];
  #   dates = "04:40";
  #   persistent = true;
  #   randomizedDelaySec = "45min";
  # };

  # Allow nixos-upgrade to restart on failure (e.g. when laptop wakes up before network connection is set)
  systemd.services.nixos-upgrade = {
    preStart = "${pkgs.host}/bin/host ${config.publicDomain}"; # Check network connectivity
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "120";
    };
    unitConfig = {
      StartLimitIntervalSec = 600;
      StartLimitBurst = 2;
    };
    path = singleton pkgs.host;
  };
}

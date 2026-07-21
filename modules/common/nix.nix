{
  config,
  inputs,
  pkgs,
  ...
}:
let
  user = config.username;
  flakePath = "/home/${user}/Work/nunix";
in
{
  nix.settings = {
    # Enable flakes
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Trusted users
    trusted-users = [
      "root"
      "${user}"
    ];
    download-buffer-size = 500000000;

    # add extra cache substituters for binary cache access (e.g. cachix)
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.nix.cachix.org/"
    ];
    # add extra cache signing keys for binary cache access (e.g. cachix)
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Enable git
  programs.git = {
    enable = true;
    config = {
      safe."directory" = "/home/${user}/Work/nunix";
    };
  };

  # Enable nh
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep 5 --keep-since 4d";
    flake = flakePath;
  };

  # Add unstable to flake registry to use locally (e.g. `nix run nixpkgs-unstable#hatch`)
  nix.registry.nixpkgs-unstable.flake = inputs.nixpkgs-unstable;

  # Allow unfree packages and pulling some packages from stable
  nixpkgs.config = {
    allowUnfree = true;
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

  environment.shellAliases = {
    # Show nix updates
    nd = ''
      nix profile diff-closures --profile /nix/var/nix/profiles/system |
            awk '/^Version [0-9]+ -> [0-9]+:$/ {block=""} {block=block $0 "\n"} END {print block}'
    '';
    # Show installed packages
    ni = "nix-store --query --requisites /run/current-system/sw | cut -d- -f2- | sort | less";
    # Rebuild system
    nrb = "sudo nixos-rebuild switch --flake ${flakePath}#${config.networking.hostName}";
    # Pull nunix and nunix-secrets repos
    nl = "git -C /home/${user}/Work/nunix pull && git -C /home/${user}/Work/nunix-secrets pull";
  };

  # System maintenance
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
    path = [ pkgs.host ];
  };
  nix.optimise.automatic = true;
  environment.systemPackages = [ pkgs.nixfmt-tree ];
}

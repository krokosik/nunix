{ inputs, ... }:
{
  imports = [
    ../../home-manager/home-manager.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ./avahi.nix
    ./env.nix
    ./dev.nix
    ./fwupd.nix
    ./firewall.nix
    ./nix.nix
    ./niks3.nix
    ./options.nix
    ./packages.nix
    ./resolved.nix
    ./run0.nix
    ./smartmon.nix
    ./ssh.nix
    ./sops.nix
    ./timesyncd.nix
    ./tz_locale.nix
    ./users.nix
  ];
}

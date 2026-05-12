{ inputs, ... }:
{
  imports = [
    # inputs.crowdsec.nixosModules.crowdsec
    # inputs.crowdsec.nixosModules.crowdsec-firewall-bouncer
    # ./crowdsec.nix
    # ./msmtp.nix
    ./neovim.nix
    ./tailscale.nix
  ];
}
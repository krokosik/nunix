{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  ### SSH
  services.openssh = {
    enable = true;
    authorizedKeysFiles = singleton "/etc/ssh/%u";
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    extraConfig = /* sshd_config */ ''
      UsePAM yes
      PrintMotd no
      TCPKeepAlive yes
      ClientAliveInterval 30
      ClientAliveCountMax 1000
    '';
  };

  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1; # Solve common flakiness with SSH

  networking.firewall.allowedTCPPorts = singleton 22;
}

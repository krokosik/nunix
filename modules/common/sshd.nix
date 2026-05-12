{
  ### SSH
  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/etc/ssh/%u" ];
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.X11Forwarding = false;
  services.openssh.extraConfig = ''
    UsePAM yes
    PrintMotd no
    TCPKeepAlive yes
    ClientAliveInterval 30
    ClientAliveCountMax 1000
  '';

  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1; # Solve common flakiness with SSH

  networking.firewall.allowedTCPPorts = [ 22 ];
}
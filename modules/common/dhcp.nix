{
  networking.dhcpcd.denyInterfaces = [ "ip6tnl0" ]; # Prevent log spam from dhcpd on IPv6 kernel tunnel interface
}
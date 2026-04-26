{
  services.timesyncd = {
    servers = [
      "ntp1.net.uw.edu.pl"
      "ntp2.net.uw.edu.pl"
      "ntp.icm.edu.pl"
    ];
    fallbackServers = [
      "time.coi.pw.edu.pl"
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

}

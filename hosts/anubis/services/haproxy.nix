{ ... }:
{
  services.haproxy = {
    enable = true;
    config = ''
      global
        stats socket /var/run/api.sock user haproxy group haproxy mode 660 level admin expose-fd listeners
        log stdout format raw local0 info

      defaults
        log  global
        mode tcp
        option  http-server-close
        timeout client 10s
        timeout connect 5s
        timeout server 10s
        maxconn 2000

      frontend https-frontend
        bind *:443
        option tcplog
        default_backend homebackend

        stick-table type ip size 1m expire 10m store conn_cur,conn_rate(10s),sess_rate(10s)
        tcp-request connection track-sc0 src
        acl too_many_conn sc0_conn_cur gt 40
        acl too_fast_conn sc0_conn_rate gt 80
        acl too_many_sess sc0_sess_rate gt 120
        tcp-request connection reject if too_many_conn || too_fast_conn || too_many_sess

      backend homebackend
        balance roundrobin
        server localserver 100.100.250.77:443 check send-proxy-v2
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}

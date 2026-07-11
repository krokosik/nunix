{ config, ... }:
{
  services.haproxy = {
    enable = true;
    config = ''
      # HAProxy Configuration - serving only as a proxy for the homeserver, with rate limiting and connection limiting
      # Utilizes the PROXY protocol to pass the original client IP to the homeserver
      # requires the homeserver to be configured to accept the PROXY protocol on its ports
      global
        # note the systemd socket is used for the stats socket
        stats socket /run/haproxy/api.sock user haproxy group haproxy mode 660 level admin expose-fd listeners
        log stdout format raw local0 info

      defaults
        log  global
        mode tcp
        option  http-server-close
        timeout client 10s
        timeout connect 5s
        timeout server 10s
        maxconn 2000

      # --- HTTP (Port 80) Frontend ---
      frontend http-frontend
        bind *:80
        option tcplog
        default_backend http-backend

        stick-table type ip size 1m expire 10m store conn_cur,conn_rate(10s),sess_rate(10s)
        tcp-request connection track-sc0 src
        acl too_many_conn sc0_conn_cur gt 40
        acl too_fast_conn sc0_conn_rate gt 80
        acl too_many_sess sc0_sess_rate gt 120
        tcp-request connection reject if too_many_conn || too_fast_conn || too_many_sess

      backend http-backend
        balance roundrobin
        server localserver ${config.homeserverPrivateIp}:80 check send-proxy-v2

      # --- HTTPS (Port 443) Frontend ---
      frontend https-frontend
        bind *:443
        option tcplog
        default_backend https-backend

        stick-table type ip size 1m expire 10m store conn_cur,conn_rate(10s),sess_rate(10s)
        tcp-request connection track-sc0 src
        acl too_many_conn sc0_conn_cur gt 40
        acl too_fast_conn sc0_conn_rate gt 80
        acl too_many_sess sc0_sess_rate gt 120
        tcp-request connection reject if too_many_conn || too_fast_conn || too_many_sess

      backend https-backend
        balance roundrobin
        server localserver ${config.homeserverPrivateIp}:443 check send-proxy-v2
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}

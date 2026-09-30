{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
in
{
  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      data_dir = "/var/lib/vector";
      sources.traefik = {
        type = "journald";
        include_units = singleton "traefik.service";
        since_now = true;
      };
      sources.internal.type = "internal_metrics";
      enrichment_tables = {
        city = {
          type = "geoip";
          path = "${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-City.mmdb";
        };
        asn = {
          type = "geoip";
          path = "${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-ASN.mmdb";
        };
      };
      transforms.access = {
        type = "remap";
        inputs = singleton "traefik";
        drop_on_abort = true;
        source = /* vrl */ ''
          raw = string!(.message)
          access, err = parse_json(raw)
          if err != null || !is_object(access) { abort }
          if !exists(access.RequestMethod) { abort }
          . = object!(access)
          .host = "${config.networking.hostName}"
          .service = "traefik"
          .log_type = "traefik_access"
          .timestamp = parse_timestamp(.StartUTC, format: "%+") ?? now()
          .message = raw
          client = to_string(.ClientHost) ?? ""
          .client_ip = client
          ua = parse_user_agent(to_string(."request_User-Agent") ?? "", mode: "enriched")
          .browser = if is_string(ua.browser.family) { ua.browser.family } else { "Unknown" }
          .os = if is_string(ua.os.family) { ua.os.family } else { "Unknown" }
          .device = if is_string(ua.device.category) { ua.device.category } else { "Unknown" }
          city, city_error = get_enrichment_table_record("city", {"ip": client})
          if city_error == null {
            .country = city.country_name
            .city = city.city_name
            .latitude = city.latitude
            .longitude = city.longitude
          }
          asn, asn_error = get_enrichment_table_record("asn", {"ip": client})
          if asn_error == null {
            .asn = asn.autonomous_system_number
            .asn_org = asn.autonomous_system_organization
          }
        '';
      };
      sinks.logs = {
        type = "http";
        inputs = singleton "access";
        uri = "http://127.0.0.1:9429/insert/jsonline?_stream_fields=host,service,log_type&_time_field=timestamp&_msg_field=message";
        encoding.codec = "json";
        framing.method = "newline_delimited";
        compression = "gzip";
        healthcheck.enabled = false;
        buffer = {
          type = "disk";
          max_size = 1073741824;
          when_full = "block";
        };
      };
      sinks.metrics = {
        type = "prometheus_exporter";
        inputs = singleton "internal";
        address = "127.0.0.1:9598";
      };
    };
  };

  systemd.services.vector = {
    wants = singleton "geoipupdate.service";
    after = singleton "geoipupdate.service";
    serviceConfig = {
      AmbientCapabilities = lib.mkForce "";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  systemd.services.geoipupdate.serviceConfig.ExecStartPost =
    singleton "+${getExe' pkgs.systemd "systemctl"} --no-block try-reload-or-restart vector.service";

  mkObservabilityServices.traefik-logs = {
    units = singleton "vector.service";
    metrics.url = "http://127.0.0.1:9598/metrics";
  };
}

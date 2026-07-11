{ config, ... }:
{
  services.geoipupdate = {
    enable = true;
    settings = {
      AccountID = 1328988;
      LicenseKey = { _secret = config.sops.secrets.geoip_license_key.path; };
      EditionIDs = [
        "GeoLite2-ASN"
        "GeoLite2-City"
        "GeoLite2-Country"
      ];
    };
    interval = "12h";
  };

  sops.secrets.geoip_license_key = {
      key = "geoip/license_key";
      mode = "0400";
    };
}

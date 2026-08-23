{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  sops.secrets = {
    niks3_s3_access_key = {
      key = "niks3/s3_access_key";
      owner = "niks3";
      restartUnits = [
        "niks3-garage-bootstrap.service"
        "niks3.service"
      ];
    };
    niks3_s3_secret_key = {
      key = "niks3/s3_secret_key";
      owner = "niks3";
      restartUnits = [
        "niks3-garage-bootstrap.service"
        "niks3.service"
      ];
    };
    niks3_api_token = {
      key = "niks3/api_token";
      owner = "niks3";
      restartUnits = [ "niks3.service" ];
    };
    niks3_signing_key = {
      key = "niks3/signing_key";
      owner = "niks3";
      restartUnits = [ "niks3.service" ];
    };
  };

  systemd.services.niks3-garage-bootstrap = {
    description = "Provision the niks3 Garage bucket and access key";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    before = [ "niks3.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      LoadCredential = [
        "s3_access_key:${config.sops.secrets.niks3_s3_access_key.path}"
        "s3_secret_key:${config.sops.secrets.niks3_s3_secret_key.path}"
      ];
    };
    script = ''
      access_key="$(<"$CREDENTIALS_DIRECTORY/s3_access_key")"
      secret_key="$(<"$CREDENTIALS_DIRECTORY/s3_secret_key")"
      garage=${lib.getExe pkgs.garage_2}

      if ! "$garage" key info "$access_key" > /dev/null 2>&1; then
        "$garage" key import --yes "$access_key" "$secret_key"
      fi

      if ! "$garage" bucket info niks3 > /dev/null 2>&1; then
        "$garage" bucket create niks3
      fi

      "$garage" bucket allow --read --write niks3 --key "$access_key"
    '';
  };

  services.niks3 = {
    enable = true;
    apiTokenFile = config.sops.secrets.niks3_api_token.path;
    signKeyFiles = singleton config.sops.secrets.niks3_signing_key.path;
    cacheUrl = "https://niks3.${config.privateDomain}";
    serverUrl = "https://niks3.${config.privateDomain}";
    readProxy.enable = true;
    s3 = {
      endpoint = "garage.${config.privateDomain}";
      bucket = "niks3";
      region = "garage";
      useSSL = true;
      bucketLookup = "path";
      accessKeyFile = config.sops.secrets.niks3_s3_access_key.path;
      secretKeyFile = config.sops.secrets.niks3_s3_secret_key.path;
    };
  };

  mkTraefikServices.niks3 = {
    host = "127.0.0.1";
    port = 5751;
    chain = singleton "chain-tailscale";
  };

  systemd.services.niks3 = {
    after = [ "niks3-garage-bootstrap.service" ];
    requires = [ "niks3-garage-bootstrap.service" ];
  };
}

{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  sops.secrets = {
    niks3_api_token = {
      owner = "niks3";
      restartUnits = [ "niks3.service" ];
    };
    niks3_signing_key = {
      key = "niks3/signing_key";
      owner = "niks3";
      restartUnits = [ "niks3.service" ];
    };
  };

  mkGarageBucket.niks3 = { };

  services.niks3 = {
    enable = true;
    apiTokenFile = config.sops.secrets.niks3_api_token.path;
    signKeyFiles = singleton config.sops.secrets.niks3_signing_key.path;
    cacheUrl = "https://niks3.${config.privateDomain}";
    serverUrl = "https://niks3.${config.privateDomain}";
    readProxy.enable = true;
    s3 = {
      endpoint = "garage.${config.privateDomain}";
      bucket = config.mkGarageBucket.niks3.bucketName;
      region = "garage";
      useSSL = true;
      bucketLookup = "path";
      accessKeyFile = config.mkGarageBucket.niks3.accessKeyFile;
      secretKeyFile = config.mkGarageBucket.niks3.secretKeyFile;
    };
  };

  mkTraefikServices.niks3 = {
    host = "127.0.0.1";
    port = 5751;
    chain = singleton "chain-tailscale";
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  rpc_port = 3901;
  s3_port = 3900;
in
{
  users.groups.garage = { };
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };

  sops.secrets = {
    garage_rpc_secret = {
      key = "garage/rpc_secret";
      owner = "garage";
      restartUnits = [ "garage.service" ];
    };
    garage_default_access_key.key = "garage/default_access_key";
    garage_default_secret_key.key = "garage/default_secret_key";
  };

  sops.templates."garage-default.env" = {
    content = ''
      GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage_default_access_key}
      GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage_default_secret_key}
      GARAGE_DEFAULT_BUCKET=default
    '';
    restartUnits = [ "garage.service" ];
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    environmentFile = config.sops.templates."garage-default.env".path;
    settings = {
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/var/lib/garage/data";
      db_engine = "sqlite";
      replication_factor = 1;
      rpc_secret_file = config.sops.secrets.garage_rpc_secret.path;

      rpc_bind_addr = "127.0.0.1:${rpc_port}";
      rpc_public_addr = "127.0.0.1:${rpc_port}";

      s3_api = {
        api_bind_addr = "127.0.0.1:${s3_port}";
        s3_region = "garage";
      };
    };
  };

  systemd.services.garage.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "garage";
    Group = "garage";
    ExecStart = lib.mkForce ''
      ${lib.getExe pkgs.garage_2} server --single-node --default-bucket
    '';
  };

  mkAllowlistChain.garage = [
    "100.64.0.0/10"
    "127.0.0.1/32"
    "::1/128"
  ];

  mkTraefikServices.garage = {
    port = s3_port;
    chain = singleton "chain-garage";
  };
}

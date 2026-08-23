{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.niks3.nixosModules.niks3-auto-upload ];

  sops.secrets.niks3_api_token = {
    sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
    key = "niks3/api_token";
    owner = lib.mkDefault "root";
    restartUnits = [ "niks3-auto-upload.service" ];
  };

  services.niks3-auto-upload = {
    enable = true;
    serverUrl = "https://niks3.${config.privateDomain}";
    authTokenFile = config.sops.secrets.niks3_api_token.path;
  };
}

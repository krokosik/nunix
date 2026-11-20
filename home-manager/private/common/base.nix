{ osConfig, inputs, ... }:
let
  user = osConfig.nunix.self.user;
in
{
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  sops = {
    # The system service supplies this 0400 key outside the Nix store.
    age.keyFile = osConfig.sops.secrets.home_manager_age_key.path;
    defaultSopsFile = "${inputs.my-secrets}/${osConfig.networking.hostName}/home.yaml";
  };
}

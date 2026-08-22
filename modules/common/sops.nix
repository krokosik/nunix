{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # Sops-nix
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = true;
    defaultSopsFile = "${inputs.my-secrets}/${config.networking.hostName}/secrets.yaml";
  };
  # Set github access token for nixpkgs
  sops.secrets.nix_access_token = {
    sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
  };

  sops.secrets.home_manager_age_key = {
    sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
    owner = config.username;
    mode = "0400";
  };

  nix.extraOptions = ''
    !include ${config.sops.secrets.nix_access_token.path}
  '';

  environment.systemPackages = [ pkgs.sops ];
}

{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # The root-only host identity decrypts per-host system secrets.
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = true;
    defaultSopsFile = "${inputs.my-secrets}/${config.networking.hostName}/secrets.yaml";
  };

  # System sops provisions this per-host identity before user sops-nix starts.
  # It decrypts only the host's home.yaml and the intentionally shared home file.
  sops.secrets.home_manager_age_key = {
    sopsFile = "${inputs.my-secrets}/${config.networking.hostName}/secrets.yaml";
    owner = config.username;
    mode = "0400";
  };

  # Only the Nix daemon reads this shared system credential.
  sops.secrets.nix_access_token = {
    sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
  };

  nix.extraOptions = ''
    !include ${config.sops.secrets.nix_access_token.path}
  '';

  environment.systemPackages = [ pkgs.sops ];
}

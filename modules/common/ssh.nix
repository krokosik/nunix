{ ... }:
let
  sshKeys = import ./ssh-keys.nix;
in
{
  programs.ssh = {
    knownHosts = sshKeys.knownHosts;
    extraConfig = /* sshconfig */ ''
      Host github-secrets
        HostName github.com
        HostKeyAlias github.com
        User git
        IdentityFile /etc/ssh/ssh_host_ed25519_key
        IdentitiesOnly yes
    '';
  };
}

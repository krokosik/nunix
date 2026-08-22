{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe';

  sshKeys = import ./ssh-keys.nix;
in
{
  programs.ssh = {
    knownHosts = sshKeys.knownHosts;
    extraConfig = /* sshconfig */ ''
      # Keep the secrets repository separate from ordinary GitHub SSH traffic.
      Host github-secrets
        HostName github.com
        HostKeyAlias github.com
        User git
        IdentityFile /home/${config.username}/.ssh/id_ed25519
        IdentitiesOnly yes
    '';
  };

  # Flake fetching runs as the configured user, so every host needs its own
  # unencrypted user key. Existing identities are never rotated.
  systemd.services.generate-user-ssh-key = {
    description = "Generate SSH key for ${config.username}";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.username;
      Group = config.username;
      UMask = "0077";
    };
    script = /* bash */ ''
      keyFile="/home/${config.username}/.ssh/id_ed25519"

      ${getExe' pkgs.coreutils "install"} --directory --mode=700 "$(dirname "$keyFile")"

      if [ ! -f "$keyFile" ]; then
        ${getExe' pkgs.openssh "ssh-keygen"} -q -t ed25519 -N "" -f "$keyFile"
      fi

      if [ ! -f "$keyFile.pub" ]; then
        ${getExe' pkgs.openssh "ssh-keygen"} -y -f "$keyFile" > "$keyFile.pub"
        ${getExe' pkgs.coreutils "chmod"} 644 "$keyFile.pub"
      fi
    '';
  };
}

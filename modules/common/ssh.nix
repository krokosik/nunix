{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatStrings;

  # Only devices accepting SSH carry a pinned host key
  sshHosts = filterAttrs (_: { hostKey, ... }: hostKey != null) config.nunix.hosts;
  hostNamesOf = name: { tailscale, ... }: [
    name
    "${name}.${config.nunix.tailnetDomain}"
    tailscale.ipv4
    tailscale.ipv6
  ];
in
{
  programs.ssh = {
    knownHosts =
      mapAttrs (
        name: host: {
          hostNames = hostNamesOf name host;
          publicKey = host.hostKey;
        }
      ) sshHosts
      // {
        # Pin GitHub's published ED25519 host key for the github-secrets alias.
        github = {
          hostNames = singleton "github.com";
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
      };

    extraConfig =
      concatStrings (
        mapAttrsToList (
          name:
          { user, tailscale, ... }:
          /* sshconfig */ ''
            Host ${name} ${name}.${config.nunix.tailnetDomain}
              HostName ${tailscale.ipv4}
              User ${user}
              StrictHostKeyChecking yes
          ''
        ) sshHosts
      )
      + /* sshconfig */ ''
        # Keep the secrets repository separate from ordinary GitHub SSH traffic.
        Host github-secrets
          HostName github.com
          HostKeyAlias github.com
          User git
          IdentityFile /home/${config.nunix.self.user}/.ssh/id_ed25519
          IdentitiesOnly yes
      '';
  };

  # Flake fetching runs as the configured user, so every host needs its own
  # unencrypted user key. Existing identities are never rotated.
  systemd.services.generate-user-ssh-key = {
    description = "Generate SSH key for ${config.nunix.self.user}";
    wantedBy = singleton "multi-user.target";
    serviceConfig = {
      Type = "oneshot";
      User = config.nunix.self.user;
      Group = config.nunix.self.user;
      UMask = "0077";
    };
    script = /* bash */ ''
      keyFile="/home/${config.nunix.self.user}/.ssh/id_ed25519"

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

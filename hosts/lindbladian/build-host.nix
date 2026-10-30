{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
in
{
  systemd.timers.nunix-build-all = {
    description = "Build every nunix host daily";
    wantedBy = singleton "timers.target";
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };

  systemd.services.nunix-build-all = {
    description = "Fetch nunix and build every host without deploying";
    wants = singleton "network-online.target";
    after = [
      "network-online.target"
      "generate-user-ssh-key.service"
    ];
    path = [
      config.nix.package
      pkgs.git
      pkgs.jq
      pkgs.openssh
      pkgs.coreutils
    ];
    environment = {
      NUNIX_REPOSITORY = "https://github.com/krokosik/nunix";
      NUNIX_BRANCH = "main";
      GIT_TERMINAL_PROMPT = "0";
      GIT_SSH_COMMAND = "${getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o StrictHostKeyChecking=yes";
    };
    serviceConfig = {
      Type = "oneshot";
      User = config.username;
      StateDirectory = "nunix-build-all";
      StateDirectoryMode = "0700";
      CacheDirectory = "nunix-build-all";
      CacheDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = "infinity";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
    script = /* bash */ ''
      set -euo pipefail
      export XDG_CACHE_HOME="$CACHE_DIRECTORY"
      checkout="$STATE_DIRECTORY/checkout"
      mkdir --parents "$STATE_DIRECTORY/results"

      if [ ! -d "$checkout/.git" ]; then
        git init --quiet "$checkout"
        git -C "$checkout" remote add origin "$NUNIX_REPOSITORY"
      fi
      git -C "$checkout" remote set-url origin "$NUNIX_REPOSITORY"
      git -C "$checkout" fetch --no-tags --depth=1 origin "$NUNIX_BRANCH"
      git -C "$checkout" checkout --force --detach FETCH_HEAD
      printf 'Building nunix revision %s\n' "$(git -C "$checkout" rev-parse HEAD)"

      hostNames=$(nix eval --json --no-update-lock-file --accept-flake-config \
        "$checkout#nixosConfigurations" --apply 'hosts: builtins.attrNames hosts')
      hostLines=$(jq --exit-status --raw-output '.[]' <<< "$hostNames")
      mapfile -t hosts <<< "$hostLines"

      failed=()
      for host in "''${hosts[@]}"; do
        printf '\nBuilding host %s\n' "$host"
        if nix build --keep-going --no-update-lock-file --accept-flake-config \
          --out-link "$STATE_DIRECTORY/results/$host" \
          "$checkout#nixosConfigurations.$host.config.system.build.toplevel"; then
          printf 'Build succeeded: %s\n' "$host"
        else
          failed+=("$host")
          printf 'Build failed: %s\n' "$host" >&2
        fi
      done

      if [ "''${#failed[@]}" -ne 0 ]; then
        printf 'Failed hosts: %s\n' "''${failed[*]}" >&2
        exit 1
      fi
      printf '\nAll host builds succeeded.\n'
    '';
  };
}

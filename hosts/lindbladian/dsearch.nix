{ lib, ... }:
let
  inherit (lib.attrsets) attrNames filterAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkAfter;
  inherit (lib.strings) concatMapStringsSep escapeShellArg hasPrefix;

  cifsMountPaths =
    fileSystems:
    attrNames (
      filterAttrs (path: { fsType, ... }: fsType == "cifs" && hasPrefix "/mnt/" path) fileSystems
    );
in
{
  home-manager.sharedModules = singleton (
    {
      config,
      osConfig,
      pkgs,
      ...
    }:
    let
      sharePaths = cifsMountPaths osConfig.fileSystems;
    in
    {
      programs.dsearch.config.index_paths = mkAfter (
        map (path: {
          inherit path;
          max_depth = 0;
          exclude_hidden = true;
          extract_exif = false;
          watch = false;
          merge_default_exclude_dirs = true;
          exclude_dirs = [
            "secrets"
            "nunix-secrets"
          ];
        }) sharePaths
      );

      systemd.user = {
        services.dsearch-share-sync = {
          Unit = {
            Description = "Refresh Dux Search while all configured CIFS shares are mounted";
            Requires = singleton "dsearch.service";
            After = singleton "dsearch.service";
          };
          Service = {
            Type = "oneshot";
            # Inspect the mount table without accessing the automount paths.
            ExecCondition = getExe (
              pkgs.writeShellScriptBin "dsearch-shares-mounted" /* bash */ ''
                ${concatMapStringsSep "\n" (path: /* bash */ ''
                  ${getExe' pkgs.util-linux "findmnt"} --noheadings --types cifs --mountpoint ${escapeShellArg path} > /dev/null || exit 1
                '') sharePaths}
              ''
            );
            ExecStart = "${getExe config.programs.dsearch.package} index sync";
            UMask = "0077";
          };
        };

        timers.dsearch-share-sync = {
          Unit.Description = "Periodically refresh Dux Search for configured CIFS shares";
          Timer = {
            OnStartupSec = "15min";
            OnCalendar = "hourly";
          };
          Install.WantedBy = singleton "timers.target";
        };
      };
    }
  );
}

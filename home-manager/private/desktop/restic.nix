{
  config,
  lib,
  ...
}:
let
  vault = "${config.xdg.userDirs.documents}/vault";
  repository = "${config.xdg.stateHome}/restic/vault";
in
{
  sops.secrets.restic_vault_password.key = "restic/vault_password";

  services.restic = {
    enable = true;
    backups.vault = {
      paths = lib.lists.singleton vault;
      inherit repository;
      passwordFile = config.sops.secrets.restic_vault_password.path;
      initialize = true;
      extraBackupArgs = lib.lists.singleton "--skip-if-unchanged";
      pruneOpts = [
        "--keep-daily 30"
        "--keep-weekly 8"
        "--keep-monthly 6"
      ];
      runCheck = true;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      backupPrepareCommand = /* bash */ ''
        vault=${lib.escapeShellArg vault}
        if [[ ! -d "$vault/.obsidian" ]]; then
          echo "Vault is missing its .obsidian directory: $vault" >&2
          exit 1
        fi

        shopt -s globstar nullglob
        notes=("$vault"/**/*.md)
        if (( ''${#notes[@]} == 0 )); then
          echo "Vault has no Markdown notes: $vault" >&2
          exit 1
        fi
      '';
    };
  };
}

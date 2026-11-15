{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton inputs.dsearch.homeModules.default;

  programs.dsearch = {
    enable = true;
    config = {
      http_enabled = false;
      worker_count = 2;
      index_all_files = true;
      index_paths = singleton {
        path = config.home.homeDirectory;
        max_depth = 0;
        exclude_hidden = true;
        extract_exif = false;
        merge_default_exclude_dirs = true;
        exclude_dirs = [
          # Share aliases are indexed separately on hosts with permanent access.
          "data"
          "assets"
          "secrets"
          "nunix-secrets"
          "result"
          "results"
        ];
      };
    };
  };

  systemd.user.services.dsearch.Service.UMask = "0077";
}

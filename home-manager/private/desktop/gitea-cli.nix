{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;

  gitea-cli = pkgs.callPackage (
    {
      buildGo127Module,
      fetchzip,
      installShellFiles,
      lib,
      stdenv,
    }:
    buildGo127Module (finalAttrs: {
      pname = "gitea-cli";
      version = "1.2.0";

      # The upstream repository uses SHA-256 git objects, which fetchgit cannot clone.
      src = fetchzip {
        url = "https://gitea.com/gitea/cli/archive/v${finalAttrs.version}.tar.gz";
        hash = "sha256-ZW51bSQxm9LEksHpWt66HGg7jtu4iuz4+4a+R6ss9So=";
      };

      vendorHash = "sha256-xj93kLq4uEuMymf/sdmZOz/pjfWAXbxnu9K2Xpis8PU=";

      subPackages = singleton "cmd/gt";

      ldflags = [
        "-s"
        "-w"
        "-X gitea.dev/cli/internal/version.Version=${finalAttrs.version}"
      ];

      nativeBuildInputs = singleton installShellFiles;

      postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) /* bash */ ''
        installShellCompletion --cmd gt \
          --bash <($out/bin/gt completion bash) \
          --fish <($out/bin/gt completion fish) \
          --zsh <($out/bin/gt completion zsh)
      '';

      meta = {
        description = "Official Gitea CLI";
        homepage = "https://gitea.com/gitea/cli";
        license = lib.licenses.mit;
        mainProgram = "gt";
      };
    })
  ) { };

  # Env credentials are never persisted by gt, so the sops secret stays the only copy.
  gt = pkgs.symlinkJoin {
    name = "gt-${gitea-cli.version}";
    paths = singleton gitea-cli;
    postBuild = /* bash */ ''
      rm $out/bin/gt
      ln --symbolic ${
        getExe (
          pkgs.writeShellApplication {
            name = "gt";
            text = /* bash */ ''
              GITEA_TOKEN="$(< ${config.sops.secrets.gitea_cli_token.path})"
              export GITEA_TOKEN
              export GITEA_INSTANCE_URL="''${GITEA_INSTANCE_URL:-${config.home.sessionVariables.GITEA_INSTANCE_URL}}"
              exec ${getExe gitea-cli} "$@"
            '';
          }
        )
      } $out/bin/gt
    '';
  };
in
{
  sops.secrets.gitea_cli_token.sopsFile = "${inputs.my-secrets}/common/home.yaml";

  home = {
    packages = singleton gt;

    sessionVariables.GITEA_INSTANCE_URL = "https://git.qodl.eu/";
  };
}

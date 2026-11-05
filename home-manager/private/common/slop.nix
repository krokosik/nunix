{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.hm.dag) entryAfter;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce;
  inherit (lib.strings) escapeShellArg removePrefix;
  rtk = pkgs.unstable.rtk;
  skillsPath = "${../../../ai/skills}";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
  codexConfigPath = "${codexConfigDir}/config.toml";
  codexConfigTarget = removePrefix config.home.homeDirectory codexConfigPath;
  codexConfigSource = config.home.file.${codexConfigTarget}.source;
  codexConfigStateTarget = removePrefix config.home.homeDirectory "${config.xdg.stateHome}/nunix/codex-config.toml";
  macierzBaseUrl = "http://macierz.qot.internal:11789/v1";
in
{
  sops.secrets = {
    opencode_go_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
    openai_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
    strata_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
  };

  home = {
    packages = singleton rtk;

    # Codex records project trust in config.toml, so install a writable copy.
    file = {
      ${codexConfigTarget}.enable = mkForce false;
      ${codexConfigStateTarget} = {
        source = codexConfigSource;
        onChange = /* bash */ ''
          run ${getExe' pkgs.coreutils "mkdir"} --parents ${escapeShellArg codexConfigDir}
          run ${getExe' pkgs.coreutils "install"} --mode=0600 ${escapeShellArg codexConfigSource} ${escapeShellArg codexConfigPath}
        '';
      };
    };

    activation.rtkInit = entryAfter (singleton "writeBoundary") /* bash */ ''
      ${getExe rtk} init --global --opencode
      CODEX_HOME=${escapeShellArg codexConfigDir} ${getExe rtk} init --global --codex
    '';
  };

  programs = {
    ripgrep.enable = true;

    codex = {
      enable = true;
      package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      skills = skillsPath;
      enableMcpIntegration = config.programs.mcp.enable;
      settings = {
        approvals_reviewer = "auto_review";

        projects =
          genAttrs
            (map (name: "${config.home.homeDirectory}/work/${name}") [
              "nunix"
              "rydar-sim"
              "rustpill"
              "nunix-secrets"
              "split-pro"
              "combik"
              "mpmath"
              "spin1"
              "xmsr"
            ])
            (_: {
              trust_level = "trusted";
            });

        hooks.state."${codexConfigDir}/hooks.json:pre_tool_use:0:0".trusted_hash =
          "sha256:be6c6fcb2978ea348dd05101efed0afcf00efcbfb5d7e78949108142c875a77d";

        model_context_window = 131072;

        model_providers.macierz = {
          name = "Macierz";
          base_url = macierzBaseUrl;
          wire_api = "responses";
          # Command-backed bearer token: Codex runs this when it needs the key,
          # trims it, and caches it in memory. Keeps the key out of the
          # environment; mutually exclusive with env_key.
          auth = {
            command = "${getExe' pkgs.coreutils "cat"}";
            args = singleton config.sops.secrets.strata_api_key.path;
            timeout_ms = 5000;
            refresh_interval_ms = 0;
          };
          stream_idle_timeout_ms = 600000;
        };

        tui = {
          status_line = [
            "model-with-reasoning"
            "current-dir"
            "context-usage"
            "used-tokens"
            "weekly-limit"
          ];
          terminal_title = [
            "project"
            "git-branch"
            "status"
            "thread"
            "task-progress"
          ];
        };
      };
    };

    opencode = {
      enable = true;
      # Home Manager and shell aliases expect the unversioned executable.
      package =
        (inputs.opencode-flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode2-avx).overrideAttrs
          (old: {
            postInstall = (old.postInstall or "") + /* bash */ ''
              ln --symbolic opencode2 "$out/bin/opencode"
            '';
            meta = old.meta // {
              mainProgram = "opencode";
            };
          });
      extraPackages = with pkgs; [
        uv
        nixd
        nh
        nixpkgs-fmt
        ruff
      ];
      skills = skillsPath;
      enableMcpIntegration = config.programs.mcp.enable;
      settings = {
        update = "disable";

        # Preserve V1's prompt before accessing paths outside the project.
        permissions = singleton {
          action = "external_directory";
          resource = "*";
          effect = "ask";
        };

        # Provider allowlist, the V2 form of enabled_providers: deny all,
        # then allow. The opencode provider needs no credential here; it is
        # connected with /connect and its free models show up automatically.
        policies =
          singleton {
            action = "provider.use";
            resource = "*";
            effect = "deny";
          }
          ++
            map
              (resource: {
                action = "provider.use";
                inherit resource;
                effect = "allow";
              })
              [
                # "opencode-go"
                "opencode"
                "openai"
                "macierz"
              ];

        compaction = {
          auto = true;
          buffer = "20%";
        };

        share = "disabled";

        providers = {
          "opencode-go".settings.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";

          openai.settings.apiKey = "{file:${config.sops.secrets.openai_api_key.path}}";

          macierz = {
            name = "Macierz";
            package = "aisdk:@ai-sdk/openai-compatible";
            settings = {
              baseURL = macierzBaseUrl;
              apiKey = "{file:${config.sops.secrets.strata_api_key.path}}";
            };
            models."qwen3.8-flash-next" = {
              name = "Qwen3.8-Flash-Next";
              capabilities = {
                tools = true;
                reasoning = {
                  supported = true;
                };
              };
              limit = {
                context = 131072;
                input = 122880;
                output = 8192;
              };
            };
          };
        };
      };
    };
  };
}

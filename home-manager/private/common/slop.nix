{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  rtk = pkgs.unstable.rtk;
  skillsPath = "${../../../ai/skills}";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
  codexConfigPath = "${codexConfigDir}/config.toml";
  codexConfigTarget = lib.strings.removePrefix config.home.homeDirectory codexConfigPath;
  codexConfigSource = config.home.file.${codexConfigTarget}.source;
  codexConfigStateTarget = lib.strings.removePrefix config.home.homeDirectory "${config.xdg.stateHome}/nunix/codex-config.toml";
  macierzBaseUrl = "http://macierz.qot.internal:11789/v1";
in
{
  home.packages = [ rtk ];

  programs.ripgrep.enable = true;

  # Codex records project trust in config.toml, so install a writable copy.
  home.file.${codexConfigTarget}.enable = lib.mkForce false;
  home.file.${codexConfigStateTarget} = {
    source = codexConfigSource;
    onChange = /* bash */ ''
      run ${lib.getExe' pkgs.coreutils "mkdir"} --parents ${lib.escapeShellArg codexConfigDir}
      run ${lib.getExe' pkgs.coreutils "install"} --mode=0600 ${lib.escapeShellArg codexConfigSource} ${lib.escapeShellArg codexConfigPath}
    '';
  };

  home.activation.rtkInit = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
    ${lib.getExe rtk} init --global --opencode
    CODEX_HOME=${lib.escapeShellArg codexConfigDir} ${lib.getExe rtk} init --global --codex
  '';

  sops.secrets = {
    opencode_go_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
    openai_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
    strata_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
  };

  programs.codex = {
    enable = true;
    package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    skills = skillsPath;
    enableMcpIntegration = config.programs.mcp.enable;
    settings = {
      approvals_reviewer = "auto_review";

      projects =
        lib.attrsets.genAttrs
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
          command = "${lib.getExe' pkgs.coreutils "cat"}";
          args = lib.lists.singleton config.sops.secrets.strata_api_key.path;
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

  programs.opencode = {
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
      autoupdate = false;

      # Preserve V1's prompt before accessing paths outside the project.
      permissions = lib.lists.singleton {
        action = "external_directory";
        resource = "*";
        effect = "ask";
      };

      small_model = "openai/gpt-6-luna";
      enabled_providers = [
        # "opencode-go"
        "openai"
        "macierz"
      ];
      compaction = {
        auto = true;
        buffer = 13672;
      };
      share = "disabled";
      provider = {
        "opencode-go".options.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";
        openai.options.apiKey = "{file:${config.sops.secrets.openai_api_key.path}}";
        macierz = {
          npm = "@ai-sdk/openai-compatible";
          name = "Macierz";
          options = {
            baseURL = macierzBaseUrl;
            apiKey = "{file:${config.sops.secrets.strata_api_key.path}}";
          };
          models = {
            "qwen3.8-flash-next" = {
              name = "Qwen3.8-Flash-Next";
              "tool_call" = true;
              reasoning = true;
              limit = {
                context = 131072;
                input = 126976;
                output = 4096;
              };
            };
          };
        };
      };
    };
  };
}

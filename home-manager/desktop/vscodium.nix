{ pkgs, ... }:
let
  inherit (pkgs) vscode-extensions;

  commonExtensions = with vscode-extensions; [
    aaron-bond.better-comments
    christian-kohler.path-intellisense
    eamodio.gitlens
    enkia.tokyo-night
    jnoortheen.nix-ide
    mkhl.direnv
    ms-azuretools.vscode-docker
    ms-vscode-remote.remote-containers
    ms-vscode-remote.remote-ssh
    ms-vscode.remote-explorer
    redhat.vscode-yaml
    tamasfe.even-better-toml
    vscode-icons-team.vscode-icons
    vscodevim.vim
  ];

  baseSettings = {
    "update.mode" = "none";
    "workbench.iconTheme" = "vscode-icons";
    "git.enableSmartCommit" = true;
    "git.confirmSync" = false;
    "git.autofetch" = true;
    "git.mergeEditor" = true;

    "editor.fontLigatures" = true;
    "editor.suggestSelection" = "first";
    "editor.bracketPairColorization.enabled" = true;
    "editor.minimap.enabled" = false;
    "editor.unicodeHighlight.nonBasicASCII" = false;
    "editor.inlineSuggest.enabled" = true;
    "editor.accessibilitySupport" = "off";

    "explorer.confirmDragAndDrop" = false;
    "explorer.confirmDelete" = false;
    "security.workspace.trust.untrustedFiles" = "open";
    "extensions.ignoreRecommendations" = true;
    "vsicons.dontShowNewVersionMessage" = true;
    "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue";

    "window.titleBarStyle" = "native";
    "window.menuStyle" = "custom";
    "window.commandCenter" = false;
    "window.customTitleBarVisibility" = "never";
    "window.menuBarVisibility" = "toggle";
    "workbench.layoutControl.enabled" = false;
    "workbench.secondarySideBar.defaultVisibility" = "hidden";

    "remote.SSH.connectTimeout" = 1800;
    "remote.SSH.enableX11Forwarding" = false;
    "remote.SSH.useExecServer" = false;
    "remote.SSH.useLocalServer" = false;
    "remote.SSH.remotePlatform" = {
      "coder-vscode.coder.qodl.eu--wkrokosz--mpmath.main" = "linux";
      qotex = "linux";
      kwsd = "linux";
      kws = "linux";
      lindbladian = "linux";
      "kwsd.chimp-qilin.ts.net" = "linux";
      icm = "linux";
      osiris = "linux";
    };

    "[yaml]" = {
      "editor.defaultFormatter" = "redhat.vscode-yaml";
    };
    "[dockercompose]" = {
      "editor.insertSpaces" = true;
      "editor.tabSize" = 2;
      "editor.autoIndent" = "advanced";
      "editor.defaultFormatter" = "redhat.vscode-yaml";
    };
    "[github-actions-workflow]" = {
      "editor.defaultFormatter" = "redhat.vscode-yaml";
    };
    "[python]" = {
      "editor.defaultFormatter" = "charliermarsh.ruff";
      "editor.formatOnSave" = true;
    };
  };

  pythonExtensions = with vscode-extensions; [
    charliermarsh.ruff
    ms-python.python
    ms-python.vscode-pylance
    ms-toolsai.jupyter
  ];

  rustExtensions = with vscode-extensions; [
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
  ];

  latexExtensions = with vscode-extensions; [
    james-yu.latex-workshop
    tecosaur.latex-utilities
  ];
in
{
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;

    profiles = {
      default = {
        extensions = commonExtensions;
        userSettings = baseSettings;
      };

      Arduino = {
        extensions = commonExtensions ++ [ vscode-extensions.ms-vscode.cpptools ];
        userSettings = baseSettings // {
          "arduino.additionalUrls" = [
            "https://arduino.esp8266.com/stable/package_esp8266com_index.json"
          ];
          "arduino.useArduinoCli" = true;
          "cmake.configureOnOpen" = true;
        };
      };

      "C++" = {
        extensions = commonExtensions ++ [
          vscode-extensions.llvm-vs-code-extensions.vscode-clangd
          vscode-extensions.ms-vscode.cmake-tools
          vscode-extensions.ms-vscode.cpptools
        ];
        userSettings = baseSettings // {
          "C_Cpp.intelliSenseEngine" = "disabled";
          "cmake.pinnedCommands" = [
            "workbench.action.tasks.configureTaskRunner"
            "workbench.action.tasks.runTask"
          ];
        };
      };

      Python = {
        extensions = commonExtensions ++ pythonExtensions;
        userSettings = baseSettings // {
          "jupyter.runStartupCommands" = [
            "%load_ext autoreload"
            "%autoreload 2"
          ];
          "python.analysis.supportRestructuredText" = true;
        };
      };

      Rust = {
        extensions = commonExtensions ++ rustExtensions;
        userSettings = baseSettings;
      };

      "Rust Embedded" = {
        extensions = commonExtensions ++ rustExtensions;
        userSettings = baseSettings;
      };

      Web = {
        extensions = commonExtensions ++ [ vscode-extensions.esbenp.prettier-vscode ];
        userSettings = baseSettings // {
          "[css]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[html]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[javascript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "[json]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[jsonc]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[markdown]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
          };
          "[typescript]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "[typescriptreact]" = {
            "editor.defaultFormatter" = "esbenp.prettier-vscode";
            "editor.formatOnSave" = true;
          };
          "typescript.updateImportsOnFileMove.enabled" = "always";
          "javascript.updateImportsOnFileMove.enabled" = "always";
        };
      };

      Tizen = {
        extensions = commonExtensions;
        userSettings = baseSettings;
      };

      Latex = {
        extensions = commonExtensions ++ latexExtensions;
        userSettings = baseSettings // {
          "texpresso.syncTeXForwardOnSelection" = true;
          "todo-tree.general.tags" = [
            "BUG"
            "HACK"
            "FIXME"
            "TODO"
            "XXX"
            "[ ]"
            "[x]"
          ];
        };
      };
    };
  };
}

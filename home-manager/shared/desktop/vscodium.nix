{
  lib,
  pkgs,
  ...
}:
let
  vscode-extensions = pkgs.nix-vscode-extensions.vscode-marketplace;
  open-vsx = pkgs.nix-vscode-extensions.open-vsx;
  vscode-extensions-universal = pkgs.nix-vscode-extensions.vscode-marketplace-universal;

  # trick to not clutter $HOME
  vscodium = pkgs.vscodium.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + /* bash */ ''
      substituteInPlace resources/app/product.json \
        --replace-fail '"dataFolderName": ".vscode-oss"' \
        '"dataFolderName": ".local/share/codium"'

      substituteInPlace resources/app/out/cli.js \
        --replace-fail 'dataFolderName:".vscode-oss"' \
        'dataFolderName:".local/share/codium"'
    '';
  });

  commonExtensions =
    with vscode-extensions;
    with open-vsx;
    [
      aaron-bond.better-comments
      christian-kohler.path-intellisense
      eamodio.gitlens
      jnoortheen.nix-ide
      mkhl.direnv
      arrterian.nix-env-selector
      ms-azuretools.vscode-docker
      ms-vscode-remote.vscode-remote-extensionpack
      redhat.vscode-yaml
      tamasfe.even-better-toml
      vscode-icons-team.vscode-icons
      yellpika.latex-input
      sst-dev.opencode
      jeanp413.open-remote-ssh
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

    "interactiveWindow.executeWithShiftEnter" = true;

    "workbench.keybindings" = [
      {
        key = "alt+left";
        command = "workbench.action.navigatePreviousInEditLocations";
      }
      {
        key = "alt+right";
        command = "workbench.action.navigateForwardInEditLocations";
      }
    ];

    "remote.SSH.connectTimeout" = 1800;
    "remote.SSH.enableX11Forwarding" = false;
    "remote.SSH.useExecServer" = false;
    "remote.SSH.useLocalServer" = false;

    "remote.SSH.serverBinaryName" = "codium-server";
    "remote.SSH.serverDownloadUrlTemplate" =
      "https://github.com/VSCodium/vscodium/releases/download/\${version}\${release}/vscodium-reh-\${os}-\${arch}-\${version}\${release}.tar.gz";
    "remote.SSH.serverVersion" = "latest";
    "remote.SSH.serverValidation" = "force";

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
    "redhat.telemetry.enabled" = false;
    "gitlens.graph.details.location" = "auto";
  };

  pythonExtensions = with vscode-extensions; [
    charliermarsh.ruff
    ms-python.python
    ms-python.debugpy
    detachhead.basedpyright
    njpwerner.autodocstring
    ms-toolsai.jupyter
    ms-toolsai.vscode-jupyter-slideshow
    ms-toolsai.jupyter-renderers
    ms-toolsai.jupyter-keymap
    ms-toolsai.vscode-jupyter-cell-tags
  ];

  # these come from https://github.com/nix-community/nix-vscode-extensions/tree/master/extensions
  rustExtensions = with vscode-extensions-universal; [
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
  ];

  latexExtensions = with vscode-extensions; [
    james-yu.latex-workshop
    tecosaur.latex-utilities
  ];

  profiles = {
    default = {
      extensions = commonExtensions;
      userSettings = baseSettings;
    };

    Arduino = {
      extensions = commonExtensions;
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
        "jupyter.interactiveWindow.creationMode" = "perFile";
        "python.terminal.activateEnvironment" = true;
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
in
{
  programs.vscodium = {
    enable = true;
    package = vscodium;
    profiles = profiles;
  };

  home.file.".vscode-oss/extensions".target = ".local/share/codium/extensions";

  stylix.targets.vscodium.profileNames = lib.attrNames profiles;
}

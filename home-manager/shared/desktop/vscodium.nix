{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) singleton;
  inherit (lib.strings) hasPrefix removePrefix;
  vscode-extensions = pkgs.nix-vscode-extensions.vscode-marketplace-release;
  open-vsx = pkgs.nix-vscode-extensions.open-vsx-release;
  vscode-extensions-universal = pkgs.nix-vscode-extensions.vscode-marketplace-release-universal;

  # Keep first-install version tracking without opening Dependi's welcome tab.
  withoutDependiWelcome =
    extension:
    extension.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + /* bash */ ''
        substituteInPlace "$out/share/vscode/extensions/fill-labs.dependi/out/main.js" \
          --replace-fail 'S.appendLine("First install"),_n.render(r),await e.setShownVersion(f.version)' \
          'S.appendLine("First install"),await e.setShownVersion(f.version)'
      '';
    });

  # VSCodium joins these onto $HOME, so they must be relative to it.
  homePrefix = "${config.home.homeDirectory}/";
  dataDir =
    assert hasPrefix homePrefix config.xdg.dataHome;
    removePrefix homePrefix config.xdg.dataHome;
  dataFolder = "${dataDir}/codium";
  sharedDataFolder = "${dataDir}/codium-shared";

  # This trick avoids cluttering $HOME.
  vscodium = pkgs.unstable.vscodium.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];

    postPatch = (oldAttrs.postPatch or "") + /* bash */ ''
      substituteInPlace resources/app/product.json \
        --replace-fail '"dataFolderName": ".vscode-oss"' \
          '"dataFolderName": "${dataFolder}"' \
        --replace-fail '"sharedDataFolderName": ".vscode-oss-shared"' \
          '"sharedDataFolderName": "${sharedDataFolder}"'

      # Each bundle embeds its own copy of the product configuration, so patch
      # every one that mentions the folders instead of keeping a list in sync.
      bundles=$(grep -rlE 'dataFolderName:"\.vscode-oss(-shared)?"' resources/app/out)
      [ -n "$bundles" ] || { echo "no bundles embed dataFolderName" >&2; exit 1; }
      for bundle in $bundles; do
        sed -i \
          -e 's|sharedDataFolderName:"\.vscode-oss-shared"|sharedDataFolderName:"${sharedDataFolder}"|g' \
          -e 's|dataFolderName:"\.vscode-oss"|dataFolderName:"${dataFolder}"|g' \
          "$bundle"
      done
    '';

    postFixup = (oldAttrs.postFixup or "") + /* bash */ ''
      # The patched bundles no longer match product.json's checksums, which
      # makes the integrity check report the installation as corrupt.
      python3 - "$out/lib/vscode/resources/app" <<'EOF'
      import base64, hashlib, json, pathlib, sys
      app = pathlib.Path(sys.argv[1])
      product = app / "product.json"
      data = json.loads(product.read_text())
      for rel in data.get("checksums", {}):
          digest = hashlib.sha256((app / "out" / rel).read_bytes()).digest()
          data["checksums"][rel] = base64.b64encode(digest).decode().rstrip("=")
      product.write_text(json.dumps(data, indent="\t"))
      EOF

      # The Rust CLI has its own compiled-in default, independent of product.json.
      wrapProgram "$out/lib/vscode/bin/codium-tunnel" \
        --run 'export VSCODE_CLI_DATA_DIR="''${VSCODE_CLI_DATA_DIR:-${config.xdg.dataHome}/codium/cli}"'
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
      # arrterian.nix-env-selector
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
    "update.showReleaseNotes" = false;
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
    "gitlens.advanced.skipOnboarding" = true;
    "dependi.extras.silenceUpdateMessages" = true;
  };

  pythonExtensions = with vscode-extensions; [
    charliermarsh.ruff
    astral-sh.ty
    ms-python.python
    ms-python.debugpy
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
    (withoutDependiWelcome fill-labs.dependi)
  ];

  latexExtensions = with vscode-extensions; [
    james-yu.latex-workshop
    tecosaur.latex-utilities
    myriad-dreamin.tinymist
    dominikpeters.texpresso-basic
  ];

  profiles = {
    default = {
      extensions = commonExtensions;
      userSettings = baseSettings;
    };

    Arduino = {
      extensions = commonExtensions;
      userSettings = baseSettings // {
        "arduino.additionalUrls" =
          singleton "https://arduino.esp8266.com/stable/package_esp8266com_index.json";
        "arduino.useArduinoCli" = true;
        "cmake.configureOnOpen" = true;
      };
    };

    "C++" = {
      extensions =
        commonExtensions
        ++ (with vscode-extensions; [
          llvm-vs-code-extensions.vscode-clangd
          ms-vscode.cmake-tools
        ]);
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
        "jupyter.widgetScriptSources" = [
          "jsdelivr.com"
          "unpkg.com"
        ];
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
      extensions =
        commonExtensions
        ++ (with vscode-extensions; [
          bradlc.vscode-tailwindcss
          esbenp.prettier-vscode
          oxc.oxc-vscode
          orta.vscode-jest
          (withoutDependiWelcome fill-labs.dependi)
        ]);
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

  home.file.".vscode-oss/extensions".target = "${dataFolder}/extensions";

  stylix.targets.vscodium.profileNames = attrNames profiles;
}

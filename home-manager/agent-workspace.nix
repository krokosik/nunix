{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;

  agentWorkspace = pkgs.callPackage (
    {
      lib,
      stdenv,
      fetchurl,
      fetchzip,
      autoPatchelfHook,
      makeWrapper,
      writeShellScriptBin,
      bubblewrap,
      xvfb,
      openbox,
      xdotool,
      xauth,
      xdpyinfo,
      xprop,
      ffmpeg,
      xclip,
      util-linux,
      procps,
      coreutils,
      bash,
      chromium,
      xterm,
      tmux,
      xdg-utils,
      kdePackages,
      xwayland,
      dbus,
      wl-clipboard,
      libxcb,
      libxkbcommon,
      wayland,
      libGL,
      vulkan-loader,
      fontconfig,
      freetype,
    }:
    let
      runtimePath = lib.makeBinPath [
        xvfb
        openbox
        xdotool
        xauth
        xdpyinfo
        xprop
        ffmpeg
        xclip
        util-linux
        procps
        coreutils
        bash
        chromium
        xterm
        tmux
        xdg-utils
        kdePackages.kwin
        kdePackages.kservice
        kdePackages.libkscreen
        xwayland
        dbus
        wl-clipboard
      ];
      # Upstream's restricted mount namespace assumes an FHS system.
      workspaceBubblewrap = writeShellScriptBin "bwrap" /* bash */ ''
        exec ${getExe bubblewrap} \
          --ro-bind /nix/store /nix/store \
          --setenv PATH "${runtimePath}:$PATH" \
          "$@"
      '';
    in
    stdenv.mkDerivation (finalAttrs: {
      pname = "agent-workspace-linux";
      version = "0.4.0";

      src = fetchurl {
        url = "https://github.com/agent-sh/agent-workspace-linux/releases/download/v${finalAttrs.version}/agent-workspace-linux-x86_64-unknown-linux-gnu";
        hash = "sha256-o1EmfFOTgVdvngSqsnBVnDHiBUHZVVda6ThxaqidU4I=";
      };

      skillSrc = fetchzip {
        url = "https://codeload.github.com/agent-sh/agent-workspace-linux/tar.gz/refs/tags/v${finalAttrs.version}";
        extension = "tar.gz";
        hash = "sha256-ZuN+YDR5F2Vyg3hYRNV9/7zl1X3VM6xV6AeI8ucB7nI=";
      };

      nativeBuildInputs = [
        autoPatchelfHook
        makeWrapper
      ];
      buildInputs = [
        stdenv.cc.cc.lib
        libxcb
        libxkbcommon
      ];

      dontUnpack = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = /* bash */ ''
        runHook preInstall

        install -D --mode=755 "$src" "$out/bin/agent-workspace-linux"
        mkdir --parents "$out/share/agent-workspace-linux"
        cp --recursive "$skillSrc/skills/agent-workspace-linux" "$out/share/agent-workspace-linux/skill"
        wrapProgram "$out/bin/agent-workspace-linux" \
          --prefix PATH : "${lib.makeBinPath (singleton workspaceBubblewrap)}:${runtimePath}" \
          --prefix LD_LIBRARY_PATH : ${
            lib.makeLibraryPath [
              libxkbcommon
              wayland
              libGL
              vulkan-loader
              fontconfig
              freetype
            ]
          }

        runHook postInstall
      '';

      meta = {
        description = "Isolated Linux desktop workspaces for AI agents over MCP";
        homepage = "https://github.com/agent-sh/agent-workspace-linux";
        license = lib.licenses.mit;
        platforms = singleton "x86_64-linux";
        mainProgram = "agent-workspace-linux";
      };
    })
  ) { };
in
{
  home.packages = singleton agentWorkspace;

  programs.mcp.servers.agent-workspace = {
    enabled = false;
    command = getExe agentWorkspace;
    args = singleton "mcp";
    env_vars = [
      "DBUS_SESSION_BUS_ADDRESS"
      "DISPLAY"
      "WAYLAND_DISPLAY"
      "XAUTHORITY"
      "XDG_RUNTIME_DIR"
      "XDG_CURRENT_DESKTOP"
      "XDG_CONFIG_HOME"
      "XDG_DATA_HOME"
      "XDG_STATE_HOME"
      "AGENT_WORKSPACE_PERMISSIONS"
    ];
  };

  home.file."${config.home.sessionVariables.CODEX_HOME}/skills/agent-workspace-linux".source =
    "${agentWorkspace}/share/agent-workspace-linux/skill";
  xdg.configFile."opencode/skills/agent-workspace-linux".source =
    "${agentWorkspace}/share/agent-workspace-linux/skill";
}

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;

  computerUse = pkgs.callPackage (
    {
      lib,
      stdenv,
      fetchurl,
      autoPatchelfHook,
      makeWrapper,
      ydotool,
      wtype,
      hyprland,
      glib,
      libxkbcommon,
    }:
    stdenv.mkDerivation (finalAttrs: {
      pname = "computer-use-linux";
      version = "0.7.20";

      src = fetchurl {
        url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-x86_64-unknown-linux-gnu";
        hash = "sha256-V7+VhtzB0V8I/ky7WEPjT2bIBe3DsuwlQTzyeWK08z8=";
      };

      indicatorSrc = fetchurl {
        url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-indicator-x86_64-unknown-linux-gnu";
        hash = "sha256-ZWbbLSx0FLqBL9s8sOe80RbouRNYSVqxeLijoKBqse8=";
      };

      nativeBuildInputs = [
        autoPatchelfHook
        makeWrapper
      ];
      buildInputs = singleton stdenv.cc.cc.lib;

      dontUnpack = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = /* bash */ ''
        runHook preInstall

        install -D --mode=755 "$src" "$out/bin/computer-use-linux"
        install --mode=755 "$indicatorSrc" "$out/bin/computer-use-linux-indicator"
        wrapProgram "$out/bin/computer-use-linux" \
          --set-default COMPUTER_USE_LINUX_INDICATOR_BIN "$out/bin/computer-use-linux-indicator" \
          --prefix PATH : ${
            lib.makeBinPath [
              ydotool
              wtype
              hyprland
              glib
            ]
          } \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (singleton libxkbcommon)}

        runHook postInstall
      '';

      meta = {
        description = "Linux desktop control over MCP";
        homepage = "https://github.com/agent-sh/computer-use-linux";
        license = lib.licenses.mit;
        platforms = singleton "x86_64-linux";
        mainProgram = "computer-use-linux";
      };
    })
  ) { };
in
{
  home.packages = singleton computerUse;

  dconf.settings."org/gnome/desktop/interface".toolkit-accessibility = true;

  # A private user socket matches upstream's ydotool fallback setup.
  systemd.user.services.ydotoold = {
    Unit = {
      Description = "Computer Use input fallback";
      PartOf = singleton "graphical-session.target";
      After = singleton "graphical-session-pre.target";
    };

    Service = {
      ExecStart = "${getExe' pkgs.ydotool "ydotoold"} --socket-path=%t/.ydotool_socket --socket-perm=0600";
      Restart = "on-failure";
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictAddressFamilies = singleton "AF_UNIX";
    };

    Install.WantedBy = singleton "graphical-session.target";
  };

  programs.mcp.servers.computer-use = {
    command = getExe computerUse;
    args = singleton "mcp";
    env_vars = [
      "DBUS_SESSION_BUS_ADDRESS"
      "DESKTOP_SESSION"
      "DISPLAY"
      "HYPRLAND_INSTANCE_SIGNATURE"
      "I3SOCK"
      "NIRI_SOCKET"
      "SWAYSOCK"
      "WAYLAND_DISPLAY"
      "XAUTHORITY"
      "XDG_CACHE_HOME"
      "XDG_CURRENT_DESKTOP"
      "XDG_RUNTIME_DIR"
      "XDG_SESSION_DESKTOP"
      "XDG_SESSION_TYPE"
      "XDG_STATE_HOME"
      "YDOTOOL_SOCKET"
      "CU_DISABLE_ABS_POINTER"
      "COMPUTER_USE_LINUX_AGENT_NAME"
      "COMPUTER_USE_LINUX_BIN"
      "COMPUTER_USE_LINUX_COSMIC_HELPER"
      "COMPUTER_USE_LINUX_DOWNLOAD_BASE"
      "COMPUTER_USE_LINUX_ENABLE_SHELL"
      "COMPUTER_USE_LINUX_FORCE_PORTAL_KEYBOARD"
      "COMPUTER_USE_LINUX_FORCE_PORTAL_POINTER"
      "COMPUTER_USE_LINUX_FORCE_XDOTOOL_KEYBOARD"
      "COMPUTER_USE_LINUX_FORCE_YDOTOOL_KEYBOARD"
      "COMPUTER_USE_LINUX_FORCE_YDOTOOL_POINTER"
      "COMPUTER_USE_LINUX_INDICATOR"
      "COMPUTER_USE_LINUX_INDICATOR_BIN"
      "COMPUTER_USE_LINUX_INDICATOR_HIDE_TEXT"
      "COMPUTER_USE_LINUX_NOTIFY_ON_COMPLETE"
      "COMPUTER_USE_LINUX_PERSIST_REMOTE_DESKTOP"
      "COMPUTER_USE_LINUX_SCREENSHOT_BACKEND"
      "COMPUTER_USE_LINUX_XDOTOOL_TYPE_DELAY_MS"
    ];
  };
}

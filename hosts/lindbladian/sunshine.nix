# One Sunshine instance, two capture targets.
#
# Sunshine connects to $XDG_RUNTIME_DIR/sunshine-wayland on every stream. On
# the desktop that symlink points at Hyprland. Game apps start cage-tty1, which
# ends the Hyprland session (and with it DMS and voxtype), stops whisper-server
# and runs a headless cage that retargets the symlink. Games then join cage as
# plain Wayland clients. Stopping cage, for whatever reason, restores greetd
# with a one-shot autologin, so a locked Hyprland is back for the next launch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkBefore mkForce;
  inherit (lib.strings) escapeShellArg;

  user = config.nunix.self.user;
  home = config.users.users.${user}.home;

  waylandLink = "sunshine-wayland";
  desktopOutput = "DP-1";
  gameOutput = "HEADLESS-1";
  greetdRunfile = "/var/lib/greetd/runfile";

  coreutils = "${pkgs.coreutils}/bin";
  systemctl = getExe' config.systemd.package "systemctl";
  wlr-randr = getExe pkgs.wlr-randr;
  jq = getExe pkgs.jq;

  linkWaylandDisplay = pkgs.writeShellScript "sunshine-link-wayland" /* bash */ ''
    set -eu
    ${coreutils}/ln -sfn -- "''${WAYLAND_DISPLAY:?}" "''${XDG_RUNTIME_DIR:?}/${waylandLink}"
  '';

  cageHost = pkgs.writeShellScript "sunshine-cage-host" /* bash */ ''
    set -eu
    ${linkWaylandDisplay}
    exec ${coreutils}/sleep infinity
  '';

  blankConsole = pkgs.writeShellScript "sunshine-blank-console" /* bash */ ''
    ${getExe' pkgs.util-linux "setterm"} --term linux --blank force > /dev/tty1 || true
  '';

  restoreDesktop = pkgs.writeShellScript "sunshine-restore-desktop" /* bash */ ''
    set -u
    if [[ $(${systemctl} is-system-running || true) == stopping ]]; then
      exit 0
    fi
    # greetd runs initial_session only while its runfile is missing.
    ${coreutils}/rm -f -- ${greetdRunfile}
    ${systemctl} start --no-block greetd.service whisper-server.service
  '';

  # Runs from Sunshine prep-cmds, so WAYLAND_DISPLAY is the symlink.
  sunshineMode = pkgs.writeShellScript "sunshine-mode" /* bash */ ''
    set -eu

    wait_for_output() {
      local output=$1 tries=$2
      while (( tries-- > 0 )); do
        if ${wlr-randr} --json 2>/dev/null \
          | ${jq} --exit-status --arg o "$output" 'any(.[]; .name == $o)' >/dev/null; then
          return 0
        fi
        ${coreutils}/sleep 0.5
      done
      printf 'Timed out waiting for Wayland output %s\n' "$output" >&2
      return 1
    }

    case "$1" in
      game)
        trap '${systemctl} stop cage-tty1.service || true' ERR
        ${systemctl} start cage-tty1.service
        wait_for_output ${gameOutput} 60
        ${wlr-randr} --output ${gameOutput} --custom-mode \
          "''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}Hz"
        ;;
      desktop)
        if ${systemctl} is-active --quiet cage-tty1.service; then
          ${systemctl} stop cage-tty1.service
        fi
        wait_for_output ${desktopOutput} 180
        ;;
      *) exit 2 ;;
    esac
  '';

  hookshotDirectory = "${home}/media/games/Hookshot/bin";
  hookshot = escapeShellArg "${hookshotDirectory}/hookshot";
  launchHookshot = pkgs.writeShellScript "launch-hookshot" /* bash */ ''
    set -e
    cd -- ${escapeShellArg hookshotDirectory}
    exec ${hookshot}
  '';
in
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = false;
    openFirewall = true;

    settings = {
      capture = "wlr";
      encoder = "nvenc";
      # Hyprland's monitor. cage has only HEADLESS-1, which Sunshine falls back to.
      output_name = desktopOutput;
    };

    applications.apps = [
      {
        name = "Desktop";
        prep-cmd = singleton { do = "${sunshineMode} desktop"; };
      }
      {
        name = "Hookshot";
        cmd = "${launchHookshot}";
        auto-detach = false;
        prep-cmd = [
          { do = "${coreutils}/test -x ${hookshot}"; }
          {
            do = "${sunshineMode} game";
            undo = "${sunshineMode} desktop";
          }
        ];
      }
    ];
  };

  users.users.${user} = {
    extraGroups = singleton "uinput";
    # Sunshine must outlive the Hyprland session it tears down.
    linger = true;
  };

  systemd.user.services = {
    sunshine = {
      wantedBy = mkForce (singleton "default.target");
      partOf = mkForce [ ];
      wants = mkForce [ ];
      after = mkForce [ ];
      environment = {
        LD_LIBRARY_PATH = "/run/opengl-driver/lib";
        WAYLAND_DISPLAY = waylandLink;
      };
    };

    sunshine-wayland-link = {
      description = "Point Sunshine at the Hyprland session";
      after = singleton "graphical-session.target";
      partOf = singleton "graphical-session.target";
      wantedBy = singleton "graphical-session.target";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = linkWaylandDisplay;
      };
    };
  };

  # Headless game compositor on its own logind seat session.
  services.cage = {
    enable = true;
    inherit user;
    program = cageHost;
    environment.WLR_BACKENDS = "headless,libinput";
  };

  systemd.services.cage-tty1 = {
    wantedBy = mkForce [ ];
    conflicts = [
      "greetd.service"
      "whisper-server.service"
    ];
    after = [
      "greetd.service"
      "whisper-server.service"
    ];
    serviceConfig = {
      ExecStartPre = "+${blankConsole}";
      ExecStopPost = "+${restoreDesktop}";
    };
  };

  services.greetd.settings = {
    # Persistent, so boot keeps the password greeter. Removing it arms one autologin.
    general.runfile = greetdRunfile;
    initial_session = {
      inherit user;
      command = "${getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
    };
  };

  systemd.tmpfiles.settings.sunshine-greetd = {
    "/var/lib/greetd".d.mode = "0755";
    ${greetdRunfile}.f.mode = "0644";
  };

  # Run this exception before the general wheel authentication rule.
  security.polkit.extraConfig = mkBefore /* javascript */ ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "${user}" &&
          action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "cage-tty1.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop")) {
        return polkit.Result.YES;
      }
    });
  '';
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';

  hyprctl = getExe' config.programs.hyprland.package "hyprctl";
  jq = getExe pkgs.jq;
  systemctl = getExe' pkgs.systemd "systemctl";

  virtualDisplay = pkgs.writeShellScript "sunshine-virtual-display" /* bash */ ''
    set -eu
    if ! ${hyprctl} -j monitors | ${jq} --exit-status 'any(.[]; .name == "SUNSHINE")' >/dev/null; then
      [[ $(${hyprctl} output create headless SUNSHINE) == ok ]]
    fi
    [[ $(${hyprctl} eval 'hl.monitor({output="SUNSHINE", mode="1920x1080@60", position="9999x0", scale=1})') == ok ]]
    [[ $(${hyprctl} eval 'hl.workspace_rule({workspace="49", monitor="SUNSHINE", default=true, persistent=true})') == ok ]]
    ${hyprctl} -j monitors | ${jq} --exit-status 'any(.[]; .name == "SUNSHINE" and .width == 1920 and .height == 1080)' >/dev/null
  '';

  gamingSession = pkgs.writeShellScriptBin "sunshine-gaming-session" /* bash */ ''
    set -eu
    export PATH=${pkgs.coreutils}/bin
    stateDir="''${XDG_RUNTIME_DIR:?}/hookshot-gaming"
    umask 077

    dispatch() {
      [[ $(${hyprctl} dispatch "$1") == ok ]]
    }

    restore() {
      [[ -d "$stateDir" ]] || return 0
      local failed=0 monitor unit
      if [[ -f "$stateDir/monitors" ]]; then
        while IFS= read -r monitor; do
          dispatch "hl.dsp.dpms({action=\"on\", monitor=\"$monitor\"})" || failed=1
        done < "$stateDir/monitors"
      fi
      if [[ -s "$stateDir/focus" ]]; then
        monitor=$(<"$stateDir/focus")
        dispatch "hl.dsp.focus({monitor=\"$monitor\"})" || true
      fi
      for unit in dms.service voxtype.service; do
        if [[ -e "$stateDir/$unit" ]]; then
          if ${systemctl} --user start "$unit"; then
            rm -- "$stateDir/$unit"
          else
            failed=1
          fi
        fi
      done
      if (( failed == 0 )); then
        rm --recursive -- "$stateDir"
      fi
      return "$failed"
    }

    case "$1" in
      prepare)
        # Recover a previous session if Hyprland exited during cleanup.
        restore
        ${virtualDisplay}
        mkdir -- "$stateDir"
        trap 'restore || true' ERR
        monitors=$(${hyprctl} -j monitors)
        ${jq} --raw-output '.[] | select(.name != "SUNSHINE" and .dpmsStatus) | .name' <<< "$monitors" > "$stateDir/monitors"
        ${jq} --raw-output '.[] | select(.name != "SUNSHINE" and .focused) | .name' <<< "$monitors" > "$stateDir/focus"
        dispatch 'hl.dsp.dpms({action="on", monitor="SUNSHINE"})'
        dispatch 'hl.dsp.focus({monitor="SUNSHINE"})'
        dispatch 'hl.dsp.focus({workspace="49"})'
        for unit in voxtype.service dms.service; do
          if ${systemctl} --user is-active --quiet "$unit"; then
            : > "$stateDir/$unit"
            ${systemctl} --user stop "$unit"
          fi
        done
        while IFS= read -r monitor; do
          dispatch "hl.dsp.dpms({action=\"off\", monitor=\"$monitor\"})"
        done < "$stateDir/monitors"
        ;;
      restore) restore ;;
      *) exit 2 ;;
    esac
  '';
in
{
  services.sunshine.settings.output_name = "SUNSHINE";

  # Host application entries call this with prepare and restore.
  system.build.sunshineGamingSession = gamingSession;

  environment.systemPackages = singleton gamingSession;

  systemd.user.services.sunshine.serviceConfig = {
    ExecStartPre = virtualDisplay;
    ExecStopPost = "${getExe gamingSession} restore";
  };
}

{ lib, pkgs, ... }:
let
  launchOrFocus = pkgs.writeShellApplication {
    name = "launch-or-focus";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprland
      pkgs.jq
    ];
    text = /* bash */ ''
      if (( $# == 0 )); then
        printf 'Usage: launch-or-focus <window-pattern> [-- <command> [args...]]\n' >&2
        exit 1
      fi

      windowPattern=$1
      shift

      windowAddress=$(
        hyprctl clients -j |
          jq -r --arg pattern "$windowPattern" '
            .[]
            | select(
                (.class | test("\\b" + $pattern + "\\b"; "i"))
                or
                (.title | test("\\b" + $pattern + "\\b"; "i"))
              )
            | .address
          ' |
          head -n 1
      )

      if [[ -n "$windowAddress" ]]; then
        hyprctl dispatch focuswindow "address:$windowAddress"
        exit 0
      fi

      if (( $# > 0 )); then
        if [[ $1 != -- ]]; then
          printf 'launch-or-focus: expected -- before launch command\n' >&2
          exit 2
        fi
        shift
      else
        set -- uwsm-app -- "$windowPattern"
      fi

      if (( $# == 0 )); then
        printf 'launch-or-focus: launch command is empty\n' >&2
        exit 2
      fi

      setsid -- "$@" >/dev/null 2>&1 &
    '';
  };
in
{
  home.packages = [ launchOrFocus ];

}

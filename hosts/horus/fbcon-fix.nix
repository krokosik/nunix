{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  catExe = getExe' pkgs.coreutils "cat";
  fbsetExe = getExe pkgs.fbset;
  grepExe = getExe pkgs.gnugrep;
  seqExe = getExe' pkgs.coreutils "seq";
  sleepExe = getExe' pkgs.coreutils "sleep";
in
{
  systemd.services.fbcon-native-resolution = {
    description = "Set NVIDIA fbcon resolution after Plymouth";

    before = singleton "greetd.service";
    after = singleton "plymouth-quit.service";
    wantedBy = singleton "greetd.service";

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "5s";
    };

    script = /* bash */ ''
      # fb0 starts as simpledrm, then AMD, and eventually becomes NVIDIA.
      # Do not touch it until NVIDIA owns it.
      for _ in $(${seqExe} 1 100); do
        if [ "$(${catExe} /sys/class/graphics/fb0/name 2>/dev/null || true)" = \
             "nvidia-drmdrmfb" ]; then
          break
        fi
        ${sleepExe} 0.05
      done

      # If NVIDIA never became fb0, leave everything alone.
      if [ "$(${catExe} /sys/class/graphics/fb0/name 2>/dev/null || true)" != \
           "nvidia-drmdrmfb" ]; then
        exit 0
      fi

      # Only force 4K when a currently-connected DRM output actually exposes
      # a 3840x2160 mode. Laptop-only boot remains at the native 1080p mode.
      has_4k=false

      for connector in /sys/class/drm/card*-*; do
        [ -r "$connector/status" ] || continue
        [ -r "$connector/modes" ] || continue
        [ "$(${catExe} "$connector/status")" = "connected" ] || continue

        if ${grepExe} --quiet --line-regexp '3840x2160' "$connector/modes"; then
          has_4k=true
          break
        fi
      done

      if "$has_4k"; then
        ${fbsetExe} \
          -fb /dev/fb0 \
          -xres 3840 \
          -yres 2160 \
          -vxres 3840 \
          -vyres 2160
      fi
    '';
  };
}

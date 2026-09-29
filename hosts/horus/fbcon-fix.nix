{ pkgs, ... }:
{
  systemd.services.fbcon-native-resolution = {
    description = "Set NVIDIA fbcon resolution after Plymouth";

    before = [ "greetd.service" ];
    after = [ "plymouth-quit.service" ];
    wantedBy = [ "greetd.service" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "5s";
    };

    script = ''
      # fb0 starts as simpledrm, then AMD, and eventually becomes NVIDIA.
      # Do not touch it until NVIDIA owns it.
      for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
        if [ "$(${pkgs.coreutils}/bin/cat /sys/class/graphics/fb0/name 2>/dev/null || true)" = \
             "nvidia-drmdrmfb" ]; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 0.05
      done

      # If NVIDIA never became fb0, leave everything alone.
      if [ "$(${pkgs.coreutils}/bin/cat /sys/class/graphics/fb0/name 2>/dev/null || true)" != \
           "nvidia-drmdrmfb" ]; then
        exit 0
      fi

      # Only force 4K when a currently-connected DRM output actually exposes
      # a 3840x2160 mode. Laptop-only boot remains at the native 1080p mode.
      has_4k=false

      for connector in /sys/class/drm/card*-*; do
        [ -r "$connector/status" ] || continue
        [ -r "$connector/modes" ] || continue
        [ "$(${pkgs.coreutils}/bin/cat "$connector/status")" = "connected" ] || continue

        if ${pkgs.gnugrep}/bin/grep -qx '3840x2160' "$connector/modes"; then
          has_4k=true
          break
        fi
      done

      if "$has_4k"; then
        ${pkgs.fbset}/bin/fbset \
          -fb /dev/fb0 \
          -xres 3840 \
          -yres 2160 \
          -vxres 3840 \
          -vyres 2160
      fi
    '';
  };
}

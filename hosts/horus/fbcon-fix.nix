{ pkgs, ... }:

{
  systemd.services.fix-fbcon-resolution = {
    description = "Adjust fbcon resolution for connected displays";

    after = [ "dev-fb0.device" ];
    bindsTo = [ "dev-fb0.device" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fix-fbcon-resolution" ''
        set -eu

        # Only force 4K if some currently connected DRM output supports it.
        for connector in /sys/class/drm/card*-*/; do
          [ -r "$connector/status" ] || continue
          [ "$(cat "$connector/status")" = connected ] || continue

          if grep -qx '3840x2160' "$connector/modes" 2>/dev/null; then
            exec ${pkgs.fbset}/bin/fbset \
              -fb /dev/fb0 \
              -xres 3840 \
              -yres 2160 \
              -vxres 3840 \
              -vyres 2160
          fi
        done

        # No connected 4K output: keep NVIDIA's selected fbdev mode.
        exit 0
      '';
    };
  };
}
{ lib, ... }:
{
  imports = [
    ./bindings.nix
    ./input.nix
    ./looknfeel.nix
    ./shell-utils.nix
    ./window-rules.nix
    ./windows.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    configType = "lua";

    settings = {
      config = {
        animations.enabled = true;
        master.mfact = 0.5;
      };

      animation = [
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 3;
          bezier = "default";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 3;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 5;
          bezier = "default";
        }
        {
          leaf = "windowsMove";
          enabled = true;
          speed = 4;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3;
          bezier = "default";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 3;
          bezier = "default";
        }
      ];

      layer_rule = [
        {
          match.namespace = "^(quickshell)$";
          no_anim = true;
        }
        {
          match.namespace = "^dms:.*";
          no_anim = true;
        }
      ];
    };

    extraConfig = lib.modules.mkAfter /* lua */ ''
      -- DMS-generated files intentionally load last and remain dynamic.
      require("dms.colors")
      require("dms.outputs")
      require("dms.layout")
      require("dms.cursor")
      require("dms.binds")
      require("dms.binds-user")
      require("dms.windowrules")
    '';
  };
}

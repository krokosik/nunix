{
  wayland.windowManager.hyprland.settings = {
    config.animations.enabled = true;

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

    curve = [
      {
        _args = [
          "easeOutQuint"
          {
            type = "bezier";
            points = [
              [
                0.23
                1
              ]
              [
                0.32
                1
              ]
            ];
          }
        ];
      }
      {
        _args = [
          "easeInOutCubic"
          {
            type = "bezier";
            points = [
              [
                0.65
                0.05
              ]
              [
                0.36
                1
              ]
            ];
          }
        ];
      }
      {
        _args = [
          "linear"
          {
            type = "bezier";
            points = [
              [
                0
                0
              ]
              [
                1
                1
              ]
            ];
          }
        ];
      }
      {
        _args = [
          "almostLinear"
          {
            type = "bezier";
            points = [
              [
                0.5
                0.5
              ]
              [
                0.75
                1.0
              ]
            ];
          }
        ];
      }
      {
        _args = [
          "quick"
          {
            type = "bezier";
            points = [
              [
                0.15
                0
              ]
              [
                0.1
                1
              ]
            ];
          }
        ];
      }
    ];

    # Speeds are in tenths of a second, at 80% of the original durations.
    animation = [
      {
        leaf = "global";
        enabled = true;
        speed = 8;
        bezier = "default";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 4.31;
        bezier = "easeOutQuint";
      }
      {
        leaf = "windows";
        enabled = true;
        speed = 3.03;
        bezier = "easeOutQuint";
      }
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 3.28;
        bezier = "easeOutQuint";
        style = "popin 87%";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 1.19;
        bezier = "linear";
        style = "popin 87%";
      }
      {
        leaf = "fadeIn";
        enabled = true;
        speed = 1.38;
        bezier = "almostLinear";
      }
      {
        leaf = "fadeOut";
        enabled = true;
        speed = 1.17;
        bezier = "almostLinear";
      }
      {
        leaf = "fade";
        enabled = true;
        speed = 2.42;
        bezier = "quick";
      }
      {
        leaf = "fadeSwitch";
        enabled = false;
      }
      {
        leaf = "layers";
        enabled = true;
        speed = 3.05;
        bezier = "easeOutQuint";
      }
      {
        leaf = "layersIn";
        enabled = true;
        speed = 3.2;
        bezier = "easeOutQuint";
        style = "fade";
      }
      {
        leaf = "layersOut";
        enabled = true;
        speed = 1.2;
        bezier = "linear";
        style = "fade";
      }
      {
        leaf = "fadeLayersIn";
        enabled = true;
        speed = 1.43;
        bezier = "almostLinear";
      }
      {
        leaf = "fadeLayersOut";
        enabled = true;
        speed = 1.11;
        bezier = "almostLinear";
      }
      {
        leaf = "workspaces";
        enabled = false;
      }
      {
        leaf = "specialWorkspace";
        enabled = true;
        speed = 5;
        bezier = "default";
        style = "slidevert";
      }
    ];
  };
}

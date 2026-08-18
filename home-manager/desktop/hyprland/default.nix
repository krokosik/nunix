{
  imports = [
    ./bindings.nix
    ./input.nix
    ./looknfeel.nix
    ./windows.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    configType = "hyprlang";
  };
}

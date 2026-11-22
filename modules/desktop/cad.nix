{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkAfter;
in
{
  environment.systemPackages = with pkgs; [
    freecad
    # The repository's `stable` overlay otherwise shadows KiCad's boolean argument.
    (kicad.override { stable = true; })
  ];

  imports = singleton inputs.inventor.nixosModules.default;

  programs.autodesk-inventor = {
    enable = true;
    versions = [
      "2027"
    ];
  };

  home-manager.users.${config.nunix.self.user}.wayland.windowManager.hyprland.extraConfig =
    mkAfter
      /* lua */ ''
        -- Inventor tool windows can trigger a center warp during various operation like fillet edge selection.
        -- See if hyprland 0.56 and higher help with this
        do
          local previous_no_warps

          local function update_inventor_cursor(window)
            local class = window and window.class
            if type(class) == "string" and class:lower() == "inventor.exe" then
              if previous_no_warps == nil then
                previous_no_warps = hl.get_config("cursor.no_warps")
                hl.config({ cursor = { no_warps = true } })
              end
            elseif previous_no_warps ~= nil then
              hl.config({ cursor = { no_warps = previous_no_warps } })
              previous_no_warps = nil
            end
          end

          hl.on("window.active", update_inventor_cursor)
          update_inventor_cursor(hl.get_active_window())
        end
      '';

  services.flatpak = {
    packages = [
      "com.orcaslicer.OrcaSlicer"
      "com.prusa3d.PrusaSlicer"
    ];
  };
}

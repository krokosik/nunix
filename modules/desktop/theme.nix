{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  home-manager.sharedModules = lib.lists.singleton (
    { config, osConfig, ... }:
    {
      home.pointerCursor.dotIcons.enable = false;

      stylix.targets.gtk.flatpakSupport.enable = true;

      # Reuse Stylix's flattened theme without creating a symlink in the user's home.
      home.file.".themes/${config.gtk.theme.name}".enable = false;

      # Some Flatpaks persist their sandbox home; home-relative theme symlinks become stale
      # across Home Manager generations and collide with Flatpak's filesystem setup.
      xdg.dataFile."flatpak/overrides/global".text = lib.mkForce /* ini */ ''
        [Context]
        filesystems=${osConfig.environment.etc."stylix/${config.home.username}".source}:ro;

        [Environment]
        GTK_THEME=${config.gtk.theme.name}
        GTK_DATA_PREFIX=${osConfig.environment.etc."stylix/${config.home.username}".source}
      '';
    }
  );

  environment.etc = lib.attrsets.mapAttrs' (
    name: home:
    lib.attrsets.nameValuePair "stylix/${name}" {
      # Expose this store directory directly to Flatpak (/etc is reserved).
      # Keep it self-contained so no additional store permissions are needed.
      source = pkgs.callPackage (
        { runCommandLocal }:
        runCommandLocal "flatpak-gtk-theme-${name}" { } /* bash */ ''
          mkdir --parents "$out/share/themes"
          cp --recursive --dereference \
            ${home.home.file.".themes/${home.gtk.theme.name}".source} \
            "$out/share/themes/${home.gtk.theme.name}"
        ''
      ) { };
    }
  ) config.home-manager.users;

  fonts.packages = with pkgs; [
    inter
    liberation_ttf
    material-symbols
    nerd-fonts.caskaydia-mono
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    polarity = "dark";

    image = ../../wallpapers/fear.png;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    icons = {
      enable = true;
      package = pkgs.yaru-theme;
      light = "Yaru-magenta";
      dark = "Yaru-magenta-dark";
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
    };
  };
}

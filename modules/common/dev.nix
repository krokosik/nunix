{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    # put whatever libraries you think you might need
    # nix-ld includes a strong sane-default as well
    # in addition to these
    libraries = with pkgs; [
      # Some binary Python extensions / ctypes users
      libffi

      # --- Qt / PyQt runtime dependencies ---
      glib
      dbus

      fontconfig
      freetype

      libglvnd
      libxkbcommon

      # Wayland platform plugin
      wayland

      # X11 / XCB platform plugin and fallback
      libx11
      libxext
      libxi
      libxrender
      libxcb

      libxcb
      libxcb-util
      libxcb-cursor
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
    ];
  };

  environment = {
    systemPackages = with pkgs; [
      ruff # replace with uv managed in 26.11
      uv
      nodejs
      corepack
      rustup

      # generic tools that it's annoying to not have
      stdenv.cc
      gcc
      pkg-config
      gnumake
      cmake
      ninja
    ];
    # For uv tool installs to work
    localBinInPath = true;
  };
}

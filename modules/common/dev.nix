{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    # put whatever libraries you think you might need
    # nix-ld includes a strong sane-default as well
    # in addition to these
    libraries = with pkgs; [
      # SOME BINARY PYTHON EXTENSIONS / CTYPES USERS
      libffi

      # --- QT / PYQT RUNTIME DEPENDENCIES ---
      glib
      dbus

      fontconfig
      freetype

      libglvnd
      libxkbcommon

      # WAYLAND PLATFORM PLUGIN
      wayland

      # X11 / XCB PLATFORM PLUGIN AND FALLBACK
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

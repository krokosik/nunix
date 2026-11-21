{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  tvPkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  inherit (tvPkgs.kdePackages) callPackage;

  bigscreenUi = callPackage (
    {
      stdenv,
      fetchurl,
      cmake,
      extra-cmake-modules,
      qtdeclarative,
      kirigami,
      ki18n,
      kcolorscheme,
      kcoreaddons,
    }:
    stdenv.mkDerivation {
      pname = "bigscreen-ui";
      version = "0.1.0";
      src = fetchurl {
        url = "https://download.kde.org/unstable/bigscreen-ui/bigscreen-ui-0.1.0.tar.xz";
        sha256 = "c19186dd22c3c4e9fa7dcc76e87ef995d1a78f5d0d79f4788f85e221ce6a1ca3";
      };
      nativeBuildInputs = [
        cmake
        extra-cmake-modules
      ];
      buildInputs = [
        qtdeclarative
        kirigami
        ki18n
        kcolorscheme
        kcoreaddons
      ];
      cmakeFlags = singleton "-DBUILD_EXAMPLES=OFF";
      dontWrapQtApps = true;
    }
  ) { };

  auraBrowser = callPackage (
    {
      stdenv,
      fetchurl,
      cmake,
      extra-cmake-modules,
      wrapQtAppsHook,
      qtwebchannel,
      qtwebengine,
      qtwayland,
      kconfig,
      kcoreaddons,
      kcrash,
      kdbusaddons,
      ki18n,
      kirigami,
    }:
    stdenv.mkDerivation {
      pname = "aura-browser";
      version = "26.11.0";
      src = fetchurl {
        url = "https://download.kde.org/unstable/aura-browser/26.11.0/aura-browser-26.11.0.tar.xz";
        sha256 = "0f5007e4e665874020c3042a2c7a914898516e91a385be20144f437ea7ef77be";
      };
      nativeBuildInputs = [
        cmake
        extra-cmake-modules
        wrapQtAppsHook
      ];
      buildInputs = [
        bigscreenUi
        qtwebchannel
        qtwebengine
        qtwayland
        kconfig
        kcoreaddons
        kcrash
        kdbusaddons
        ki18n
        kirigami
      ];
    }
  ) { };
in
{
  services.flatpak.enable = true;

  home-manager.users.tv.systemd.user.services.flatpak-repo = {
    Unit.Description = "Add the per-user Flathub remote";
    Service = {
      Type = "oneshot";
      ExecStart = "${getExe config.services.flatpak.package} remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
    };
    Install.WantedBy = singleton "default.target";
  };

  environment.systemPackages = with tvPkgs; [
    auraBrowser
    moonlight-qt
    jellyfin-desktop
    vacuum-tube
  ];
}

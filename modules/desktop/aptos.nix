{ lib, pkgs, ... }:

let
  inherit (lib.lists) singleton;
  aptosFonts = pkgs.callPackage (
    {
      stdenvNoCC,
      fetchurl,
      installFonts,
      unzip,
    }:
    stdenvNoCC.mkDerivation {
      pname = "aptos-fonts";
      version = "4.40";

      src = fetchurl {
        url = "https://download.microsoft.com/download/8/6/0/860a94fa-7feb-44ef-ac79-c072d9113d69/Microsoft%20Aptos%20Fonts.zip";
        hash = "sha256-ZSj9Eg5xmp+YXpQhTspoh9FlO4hFaRankqYwsC6VsCU=";
      };

      nativeBuildInputs = [
        unzip
        installFonts
      ];

      sourceRoot = ".";

      dontInstallFonts = true;
      postInstall = /* bash */ ''
        installFont ttf "$out/share/fonts/truetype"
      '';
    }
  ) { };
in
{
  fonts.packages = singleton aptosFonts;
}

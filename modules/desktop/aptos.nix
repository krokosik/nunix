# 1. Download the ZIP: https://www.microsoft.com/en-us/download/details.aspx?id=106087&utm_source=chatgpt.com
# 2. Rename to remove illegal characters: mv ~/downloads/"Microsoft Aptos Fonts.zip" ~/downloads/aptos.zip
# 2. Get its hash: nix hash file ~/downloads/aptos.zip
# 3. Add the file to the store: nix-store --add-fixed sha256 ~/downloads/aptos.zip

{ lib, pkgs, ... }:

let
  inherit (lib.lists) singleton;
  aptosFonts = pkgs.callPackage (
    {
      lib,
      stdenvNoCC,
      fetchurl,
      unzip,
    }:
    stdenvNoCC.mkDerivation {
      pname = "aptos-fonts";
      version = "4.40";

      src = fetchurl {
        url = "https://download.microsoft.com/download/8/6/0/860a94fa-7feb-44ef-ac79-c072d9113d69/Microsoft%20Aptos%20Fonts.zip";
        hash = "sha256-ZSj9Eg5xmp+YXpQhTspoh9FlO4hFaRankqYwsC6VsCU=";
      };

      nativeBuildInputs = singleton unzip;

      dontUnpack = true;

      installPhase = /* bash */ ''
        mkdir --parents $out/share/fonts/truetype
        unzip "$src" -d unpacked

        find unpacked \
          -type f \
          -iname '*.ttf' \
          -exec install --directory --mode=444 {} --target-directory=$out/share/fonts/truetype \;
      '';
    }
  ) { };
in
{
  fonts.packages = singleton aptosFonts;
}

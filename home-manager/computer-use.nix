{ pkgs, lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;

  computerUse = pkgs.callPackage (
    {
      lib,
      stdenv,
      fetchurl,
      autoPatchelfHook,
      makeWrapper,
      ydotool,
      wtype,
      hyprland,
      glib,
      libxkbcommon,
    }:
    stdenv.mkDerivation (finalAttrs: {
      pname = "computer-use-linux";
      version = "0.7.20";

      src = fetchurl {
        url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${finalAttrs.version}/computer-use-linux-x86_64-unknown-linux-gnu";
        hash = "sha256-V7+VhtzB0V8I/ky7WEPjT2bIBe3DsuwlQTzyeWK08z8=";
      };

      nativeBuildInputs = [
        autoPatchelfHook
        makeWrapper
      ];
      buildInputs = singleton stdenv.cc.cc.lib;

      dontUnpack = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = /* bash */ ''
        runHook preInstall

        install -D --mode=755 "$src" "$out/bin/computer-use-linux"
        wrapProgram "$out/bin/computer-use-linux" \
          --prefix PATH : ${
            lib.makeBinPath [
              ydotool
              wtype
              hyprland
              glib
            ]
          } \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (singleton libxkbcommon)}

        runHook postInstall
      '';

      meta = {
        description = "Linux desktop control over MCP";
        homepage = "https://github.com/agent-sh/computer-use-linux";
        license = lib.licenses.mit;
        platforms = singleton "x86_64-linux";
        mainProgram = "computer-use-linux";
      };
    })
  ) { };
in
{
  home.packages = singleton computerUse;

  programs.mcp.servers.computer-use = {
    command = getExe computerUse;
    args = singleton "mcp";
  };
}

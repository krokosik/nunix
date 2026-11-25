{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.trivial) importJSON;
  zoteroMcp = inputs.zotero-mcp.packages.${pkgs.stdenv.hostPlatform.system}.zotero-mcp;
  # The Zotero Agent chat panel. Upstream builds it only at release time, so
  # the wheel built from git has no .xpi in it.
  zoteroAgent = pkgs.callPackage (
    { buildNpmPackage, zip }:
    buildNpmPackage {
      pname = "zotero-agent";
      inherit ((importJSON "${inputs.zotero-mcp}/plugin/addon.json")) version;
      src = "${inputs.zotero-mcp}/plugin";
      npmDepsHash = "sha256-wuGc465q4FZaFMS5gMdssWFtQrSw682/PGMtRfgpDNo=";
      nativeBuildInputs = singleton zip;
      installPhase = /* bash */ ''
        runHook preInstall
        install -D --mode=0644 dist/zotero-agent.xpi "$out/zotero-agent.xpi"
        runHook postInstall
      '';
    }
  ) { };
in
{
  # `zotero-cli plugin` prints where the bundled .xpi is. Zotero has no way to
  # install a plugin from outside, so that last step stays manual.
  home.packages = with pkgs; [
    zotero
    (zoteroMcp.overridePythonAttrs (old: {
      preBuild = (old.preBuild or "") + /* bash */ ''
        install -D --mode=0644 ${zoteroAgent}/zotero-agent.xpi src/zotero_mcp/chat_plugin/zotero-agent.xpi
      '';
    }))
  ];
}

{
  inputs,
  pkgs,
  ...
}:
let
  tvPkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = with tvPkgs; [
    (callPackage ./moonlight-tv.nix {
      moonlight-embedded = callPackage ./moonlight-embedded.nix { };
    })
    moonlight-qt
    jellyfin-desktop
  ];
}

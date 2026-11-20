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
    moonlight-qt
    jellyfin-desktop
  ];
}

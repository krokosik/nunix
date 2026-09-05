{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton ./tablet.nix;
}

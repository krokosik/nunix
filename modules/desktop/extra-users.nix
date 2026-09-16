{ config, lib, ... }:
let
  inherit (lib.attrsets) genAttrs;
in
{
  home-manager.users = genAttrs config.extraUsers (username: {
    imports = [ ../../home-manager/shared/desktop ];

    home.username = username;
    home.homeDirectory = "/home/${username}";
  });
}

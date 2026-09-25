{ inputs, ... }:
{
  imports = [ inputs.nix-index-database.nixosModules.default ];
  programs.nix-index.enable = true; # Enables command-not-found
  programs.nix-index-database.comma.enable = true; # Enables comma
}

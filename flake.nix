{
  description = "A simple NixOS flake with ZFS, Disko, and Home Manager";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/?shallow=1&ref=nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    my-secrets = {
      url = "/home/krokosik/Work/nunix-secrets";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Native NixOS module for authentik (server, worker, outposts).
    # Upstream warns against overriding nixpkgs via follows because
    # python deps in the lockfile are pinned together; let it use its
    # own locked nixpkgs.
    authentik-nix.url = "github:nix-community/authentik-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # Helper function to create a nixos system configuration
      mkSystem =
        {
          host,
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          modules = [
            {
              nixpkgs.hostPlatform = system;
              networking.hostName = host;
            }
            ./hosts/${host}/configuration.nix
          ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
    in
    {
      nixosConfigurations = {
        osiris = mkSystem { host = "osiris"; };
        anubis = mkSystem {
          host = "anubis";
          system = "aarch64-linux";
        };
      };

      formatter.x86_64-linux = pkgs.nixfmt-tree;

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-tree
          nixd
          nh
          sops
          age
          ssh-to-age
          nix-prefetch
          just
          git
        ];
      };
    };
}

{
  description = "A simple NixOS flake with ZFS, Disko, and Home Manager";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    opencode-flake.url = "github:noblepayne/opencode-flake";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    my-secrets = {
      url = "git+ssh://git@github-secrets/krokosik/nunix-secrets.git";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    voxtype.url = "github:peteonrails/voxtype/v0.7.1";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixflix = {
      url = "github:kiriwalawren/nixflix/v3.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niks3 = {
      url = "github:Mic92/niks3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    run0-sudo-shim = {
      url = "github:LordGrimmauld/run0-sudo-shim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim.url = "github:pfassina/lazyvim-nix";

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
      rescueIso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./iso/rescue.nix ];
      };
    in
    {
      nixosConfigurations = {
        osiris = mkSystem { host = "osiris"; };
        anubis = mkSystem {
          host = "anubis";
          system = "aarch64-linux";
        };
        horus = mkSystem { host = "horus"; };
        isis = mkSystem { host = "isis"; };
        lindbladian = mkSystem { host = "lindbladian"; };
      };

      formatter.x86_64-linux = pkgs.nixfmt-tree;

      packages.x86_64-linux.rescue-iso = rescueIso.config.system.build.isoImage;

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-tree
          nixd
          nh
          nix-prefetch
          just
          git
        ];
      };
    };
}

{
  inputs,
  nixosConfigurations,
}:
let
  inherit (inputs.nixpkgs.lib.attrsets) genAttrs;
  # Use the cached nixpkgs deploy-rs binary instead of compiling it, which
  # matters most for aarch64 activations built under emulation.
  deploymentPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.deploy-rs.overlays.default
        (_: previous: {
          deploy-rs = previous.deploy-rs // {
            deploy-rs = inputs.nixpkgs.legacyPackages.${system}.deploy-rs;
          };
        })
      ];
    };
  deploy = {
    magicRollback = true;
    autoRollback = true;
    remoteBuild = false;
    interactiveSudo = false;
    sudo = "run0 --user";
    confirmTimeout = 60;
    activationTimeout = 600;
    sshOpts = [
      "-o"
      "BatchMode=yes"
      "-o"
      "ConnectTimeout=15"
      "-o"
      "ServerAliveInterval=15"
    ];
    nodes = genAttrs [ "anubis" "osiris" ] (
      host:
      let
        system = nixosConfigurations.${host};
        inherit (system) config;
        targetPkgs = deploymentPkgs config.nixpkgs.hostPlatform.system;
      in
      {
        # Resolved through the generated ssh_config and pinned known_hosts
        hostname = config.networking.hostName;
        sshUser = config.nunix.self.user;
        profiles.system = {
          user = "root";
          path = targetPkgs.deploy-rs.lib.activate.nixos system;
        };
      }
    );
  };
in
{
  inherit deploy;
  checks = (deploymentPkgs "x86_64-linux").deploy-rs.lib.deployChecks deploy;
}

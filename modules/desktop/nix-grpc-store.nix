{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) elem singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;

  inherit (config.networking) hostName;
  etcPath = name: "/etc/${config.environment.etc.${name}.target}";

  # Nix uses the URL as the name of a file that tracks build slots, so the URL
  # must stay under 255 bytes. That is why it points at short /etc paths instead
  # of the long store paths of the secrets input. Each system gets its own URL,
  # so that Nix tracks build slots and features separately for each entry.
  builderUrl =
    system:
    "${config.nunix.grpcStore.url}?"
    + concatStringsSep "&" [
      "ca-cert=${etcPath "nix-grpc-store/ca.crt"}"
      "client-cert=${etcPath "nix-grpc-store/client.crt"}"
      "client-key=${config.sops.secrets.nix_grpc_store_tls_key.path}"
      # If the daemon is unreachable, give up quickly so that Nix builds locally instead
      "connect-timeout=2"
      "system=${system}"
    ];
in
{
  imports = singleton "${inputs.nix-grpc-store}/nixos/client.nix";

  # Imports cannot depend on config, so the whole module is gated on the trusted list instead
  config = mkIf (elem hostName config.nunix.grpcStore.trustedHosts) {
    programs.nix-grpc-store.enable = true;

    # The build hook runs as root. The user also reads the key, to run builds
    # directly with `--store grpc://…`.
    sops.secrets.nix_grpc_store_tls_key = {
      key = "nix-grpc-store/tls_key";
      owner = config.nunix.self.user;
    };

    environment.etc = {
      "nix-grpc-store/ca.crt".source = "${inputs.my-secrets}/nix-grpc-store/ca.crt";
      "nix-grpc-store/client.crt".source = "${inputs.my-secrets}/nix-grpc-store/${hostName}.crt";
    };

    nix = {
      distributedBuilds = true;

      buildMachines = [
        {
          hostName = builderUrl "x86_64-linux";
          protocol = null;
          system = "x86_64-linux";
          # The number of physical cores in the daemon host's facter report
          maxJobs = 14;
          supportedFeatures = [
            "nixos-test"
            "benchmark"
            "big-parallel"
            "kvm"
          ];
        }
        {
          hostName = builderUrl "aarch64-linux";
          protocol = null;
          system = "aarch64-linux";
          # Builds emulated through binfmt are slow and use a lot of memory, and they cannot use kvm
          maxJobs = 4;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
      ];

      settings.builders-use-substitutes = true;
    };
  };
}

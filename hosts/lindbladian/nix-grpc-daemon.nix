{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;

  inherit (config.nunix) grpcStore;
  certDir = "${inputs.my-secrets}/nix-grpc-store";
in
{
  imports = singleton "${inputs.nix-grpc-store}/nixos/server.nix";

  # Clients find the daemon through nunix.grpcStore.host, so it must name this host
  assertions = singleton {
    assertion = grpcStore.host == config.networking.hostName;
    message = "nunix.grpcStore.host must be ${config.networking.hostName}, which runs nix-grpc-daemon.";
  };

  sops.secrets = {
    nix_grpc_store_tls_key = {
      key = "nix-grpc-store/tls_key";
      owner = "nix-grpc-daemon";
      restartUnits = singleton "nix-grpc-daemon.service";
    };

    # Sign builds made on this host so that servers accept them as substitutes
    nix_grpc_store_signing_key = {
      key = "nix-grpc-store/signing_key";
      restartUnits = singleton "nix-daemon.service";
    };
  };

  services.nix-grpc-daemon = {
    enable = true;
    listen = "${config.nunix.self.tailscale.ipv4}:${toString grpcStore.port}";
    # Trusted clients upload unsigned paths that they built themselves
    trustClients = true;
    tls = {
      certFile = "${certDir}/${config.networking.hostName}.crt";
      keyFile = config.sops.secrets.nix_grpc_store_tls_key.path;
      clientCaFile = "${certDir}/ca.crt";
    };
    # The first matching rule wins. Listing the shared certificate first means that
    # it can never match a trusted rule. Certificates that match no rule are denied.
    accessRules =
      singleton {
        cn = "read-only";
        role = "read-only";
      }
      ++ map (cn: {
        inherit cn;
        role = "trusted";
      }) grpcStore.trustedHosts;
  };

  # Allow binding to the Tailscale address before tailscaled has assigned it
  systemd.sockets.nix-grpc-daemon.socketConfig.FreeBind = true;

  nix.settings.secret-key-files = singleton config.sops.secrets.nix_grpc_store_signing_key.path;
}

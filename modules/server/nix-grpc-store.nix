{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.strings) concatStringsSep fileContents;

  certDir = "${inputs.my-secrets}/nix-grpc-store";
  etcPath = name: "/etc/${config.environment.etc.${name}.target}";
in
{
  imports = singleton "${inputs.nix-grpc-store}/nixos/client.nix";

  # Servers only download store paths from the daemon, using one certificate that they share
  programs.nix-grpc-store.enable = true;

  sops.secrets.nix_grpc_store_read_only_key = {
    sopsFile = "${inputs.my-secrets}/server/secrets.yaml";
    key = "nix-grpc-store/read_only_key";
  };

  environment.etc = {
    "nix-grpc-store/ca.crt".source = "${certDir}/ca.crt";
    "nix-grpc-store/read-only.crt".source = "${certDir}/read-only.crt";
  };

  nix.settings = {
    substituters = singleton (
      "${config.nunix.grpcStore.url}?"
      + concatStringsSep "&" [
        "ca-cert=${etcPath "nix-grpc-store/ca.crt"}"
        "client-cert=${etcPath "nix-grpc-store/read-only.crt"}"
        "client-key=${config.sops.secrets.nix_grpc_store_read_only_key.path}"
        # If the daemon is unreachable, give up quickly and use the other caches
        "connect-timeout=2"
      ]
    );
    trusted-public-keys = singleton (fileContents "${certDir}/signing-key.pub");
  };
}

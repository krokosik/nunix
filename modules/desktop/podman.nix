# Rootless Podman for the primary user on dev hosts.
# Replaces the rootful Docker daemon: no root-equivalent `docker` group,
# containers run in the user's own user namespace. `docker` is a Podman
# shim (dockerCompat), and DOCKER_HOST points Docker-API clients
# (docker-compose, VS Code's container extension) at the user's rootless
# Podman socket, which the upstream module enables for every user.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (config.users.users.${config.nunix.self.user}) uid;
in
{
  options.desktop.podman.enable = mkEnableOption "rootless Podman with Docker CLI compatibility for the primary user";

  config = mkIf config.desktop.podman.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      autoPrune.enable = true;
      # Name resolution between containers on user-defined networks (compose).
      defaultNetwork.settings.dns_enabled = true;
    };

    # `podman compose` / `docker compose` delegate to docker-compose over the socket.
    environment = {
      systemPackages = singleton pkgs.docker-compose;
      sessionVariables.DOCKER_HOST = "unix:///run/user/${toString uid}/podman/podman.sock";
    };
  };
}

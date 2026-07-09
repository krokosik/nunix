# Docker
{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
      dns = [ "172.17.0.1" ];
      bip = "172.17.0.1/16";
    };
    enableOnBoot = config.role == "server";
  };
  # systemd.services.docker = {
  #   unitConfig = {
  #     DefaultDependencies = false;
  #   };
  #   wantedBy = lib.mkForce [];
  # };
  users.users.${config.username}.extraGroups = [ "docker" ];
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}

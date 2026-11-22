{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  name = "psitransfer";
  containerUnit = config.mkContainerServices.${name}.serviceUnit;
in
{
  # No NixOS module for psitransfer exists in nixpkgs yet, so it runs as a container.
  # Image runs as node (UID 1000); keep-id maps it onto the host `psitransfer` user.
  mkContainerServices.psitransfer = {
    uid = 2003;
    ctrUid = 1000;
    port = 3039;
    containerPort = 3000;
  };

  sops = {
    secrets.psitransfer_password.key = "psitransfer/password";

    templates."psitransfer.env" = {
      content = /* bash */ ''
        PSITRANSFER_ADMIN_PASS=${config.sops.placeholder.psitransfer_password}
      '';

      # Rootless podman reads --env-file as the svc user.
      owner = name;
      restartUnits = singleton containerUnit;
    };
  };

  virtualisation.oci-containers.containers.psitransfer = {
    image = "psitrax/psitransfer:v2.4.4";
    volumes = singleton "/var/lib/psitransfer:/data";
  };

  mkTraefikServices.psitransfer = {
    port = config.mkContainerServices.psitransfer.port;
    public = true;
  };

  mkAuthentik.forwardAuthApps.psitransfer = {
    displayName = "PsiTransfer";
    accessGroup = "friends";
    displayGroup = "Apps";
  };

  mkObservabilityServices.psitransfer = {
    units = singleton containerUnit;
    probes.public = {
      url = config.mkTraefikServices.psitransfer.fullHostname;
      module = "http_reachable";
    };
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.psitransfer.units;
}

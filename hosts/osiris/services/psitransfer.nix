{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib) stringAfter;
  name = "psitransfer";
  port = 3039;
  containerUser = config.username; # UID/GID 1000 on osiris
  containerUnit = "${config.virtualisation.oci-containers.backend}-${name}.service";
  dataPath = "/var/lib/psitransfer";
in
{
  mkContainerServices.psitransfer = {
    inherit port;
    manageUser = false;
    containerPort = 3000;
  };

  sops = {
    secrets.psitransfer_password.key = "psitransfer/password";

    templates."psitransfer.env" = {
      content = /* bash */ ''
        PSITRANSFER_ADMIN_PASS=${config.sops.placeholder.psitransfer_password}
      '';

      owner = containerUser;
      restartUnits = singleton containerUnit;
    };
  };

  virtualisation.oci-containers.containers.psitransfer = {
    image = "psitrax/psitransfer:v2.4.4";
    volumes = singleton "${dataPath}:/data";
  };

  system.activationScripts.makePsiTransferDir = stringAfter (singleton "var") /* bash */ ''
    mkdir --parents ${dataPath}
    chown --recursive 1000:1000 ${dataPath}
  '';

  mkTraefikServices.psitransfer = {
    inherit port;
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

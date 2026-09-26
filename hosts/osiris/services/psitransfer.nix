{ config, ... }:
let
  name = "psitransfer";
  port = 3039;
  containerUser = config.username; # UID/GID 1000 on osiris
  containerUnit = "${config.virtualisation.oci-containers.backend}-${name}.service";
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
      content = ''
        PSITRANSFER_ADMIN_PASS=${config.sops.placeholder.psitransfer_password}
      '';

      owner = containerUser;
      restartUnits = [ containerUnit ];
    };
  };

  virtualisation.oci-containers.containers.psitransfer = {
    image = "ghcr.io/psitrax/psitransfer:v2.4.4";
    volumes = [
      "/var/lib/psitransfer:/data"
    ];
  };

  mkTraefikServices.psitransfer = {
    inherit port;
    public = true;
  };

  mkAuthentik.forwardAuthApps.psitransfer = {
    displayName = "PsiTransfer";
    accessGroup = "friends";
    displayGroup = "Apps";
  };
}

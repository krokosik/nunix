{ config, inputs, ... }:
{
  sops.secrets = {
    syncthing_key = { };
    syncthing_cert = { };
    syncthing_password.sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
  };

  services.syncthing = {
    enable = true;
    key = config.sops.secrets.syncthing_key.path;
    cert = config.sops.secrets.syncthing_cert.path;
    guiCredentials = {
      username = config.home.username;
      passwordFile = config.sops.secrets.syncthing_password.path;
    };
    settings = {
      options = {
        relaysEnabled = false;
        urAccepted = 3;
      };
      devices = {
        khonsu = {
          id = "YLQZWQ7-DUKD2EP-CMXTWES-ZPFSP75-CYV7J3L-5OCMT6Q-ATCSN3Y-OJAUOAB";
        };
      };
      folders = {
        vault = {
          path = "${config.xdg.userDirs.documents}/vault";
          devices = [ "khonsu" ];
          id = "7nqdz-vurey";
        };
      };
    };
  };
}

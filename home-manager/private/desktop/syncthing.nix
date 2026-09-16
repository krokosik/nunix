{
  config,
  inputs,
  ...
}:
{
  sops.secrets = {
    # Device identity is host-specific; the GUI password is intentionally shared.
    syncthing_key = { };
    syncthing_cert = { };
    syncthing_password.sopsFile = "${inputs.my-secrets}/common/home.yaml";
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
        lindbladian = {
          id = "K5Y6JJO-IQD2LPY-IT3WGH5-HMEXXPB-MQHMEJK-YECAIZS-CCWLWA2-7X5U6A4";
        };
        horus = {
          id = "K3O7KTE-DNJI5ER-XVDOVZK-I5TSY5Z-P2WRORE-QK57BHA-RM55CIL-NVA6UAM";
        };
        isis = {
          id = "F4A6FSM-WHSWT36-PI7A4XW-IDR3FL3-7TORBUX-M5THI4Z-56Z3KIW-ZTSODQX";
        };
      };
      folders = {
        vault = {
          path = "${config.xdg.userDirs.documents}/vault";
          devices = [
            "lindbladian"
            "khonsu"
            "horus"
            "isis"
          ];
          id = "7nqdz-vurey";
        };
        dms-hypr = {
          path = "${config.xdg.configHome}/hypr/dms";
          devices = [
            "lindbladian"
            "khonsu"
            "horus"
            "isis"
          ];
          id = "a9heq-yzbov";
          ignorePatterns = [ "outputs.conf" ];
        };
        dms = {
          path = "${config.xdg.configHome}/DankMaterialShell";
          devices = [
            "lindbladian"
            "khonsu"
            "horus"
            "isis"
          ];
          id = "e3hvo-mqvsu";
        };
      };
    };
  };
}

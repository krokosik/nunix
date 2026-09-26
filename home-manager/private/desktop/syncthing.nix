{
  config,
  lib,
  inputs,
  ...
}:

let
  devices = [
    "lindbladian"
    "khonsu"
    "horus"
    "isis"
  ];

  folders = {
    vault = {
      path = "${config.xdg.userDirs.documents}/vault";
      inherit devices;
      id = "7nqdz-vurey";
    };

    dms-hypr = {
      path = "${config.xdg.configHome}/hypr/dms";
      inherit devices;
      id = "a9heq-yzbov";

      ignorePatterns = [
        "outputs.conf"
        "outputs.lua"
      ];
    };

    dms = {
      path = "${config.xdg.configHome}/DankMaterialShell";
      inherit devices;
      id = "e3hvo-mqvsu";
    };
  };

  # Stable 26.05 HM doesn't know about ignorePatterns, evaluate on 26.11+.
  syncthingFolders =
    lib.mapAttrs (_: folder: removeAttrs folder [ "ignorePatterns" ]) folders;

  # Generate .stignore for folders that define ignorePatterns.
  ignoreFiles = lib.mapAttrs' (
    _: folder:
    lib.nameValuePair
      "${lib.removePrefix "${config.home.homeDirectory}/" folder.path}/.stignore"
      {
        text = lib.concatLines folder.ignorePatterns;
      }
  ) (lib.filterAttrs (_: folder: folder ? ignorePatterns) folders);
in
{
  sops.secrets = {
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
        khonsu.id =
          "YLQZWQ7-DUKD2EP-CMXTWES-ZPFSP75-CYV7J3L-5OCMT6Q-ATCSN3Y-OJAUOAB";
        lindbladian.id =
          "JK6J5IF-GCC2C6T-3FG7G3Z-IKEH5FX-IXVDAEM-CD3RWC4-7EP2NVT-D3Y3FAT";
        horus.id =
          "K3O7KTE-DNJI5ER-XVDOVZK-I5TSY5Z-P2WRORE-QK57BHA-RM55CIL-NVA6UAM";
        isis.id =
          "F4A6FSM-WHSWT36-PI7A4XW-IDR3FL3-7TORBUX-M5THI4Z-56Z3KIW-ZTSODQX";
      };

      folders = syncthingFolders;
    };
  };

  home.file = ignoreFiles;
}
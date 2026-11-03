{ lib, name }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) nullOr str submodule;
in
submodule {
  options = {
    secretName = mkOption {
      type = str;
      default = name;
      description = "Name of the provisioned sops secret.";
    };

    key = mkOption {
      type = nullOr str;
      default = null;
      description = "Source key in the sops file; defaults to secretName.";
    };

    owner = mkOption {
      type = str;
      default = "root";
      description = "Owner of the decrypted secret file.";
    };

    group = mkOption {
      type = str;
      default = "root";
      description = "Group of the decrypted secret file.";
    };

    mode = mkOption {
      type = str;
      default = "0400";
      description = "Mode of the decrypted secret file.";
    };
  };
}

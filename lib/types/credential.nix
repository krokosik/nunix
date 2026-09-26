{ lib, name }:
lib.types.submodule {
  options = {
    secretName = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "Name of the provisioned sops secret.";
    };

    key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Source key in the sops file; defaults to secretName.";
    };

    owner = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Owner of the decrypted secret file.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group of the decrypted secret file.";
    };

    mode = lib.mkOption {
      type = lib.types.str;
      default = "0400";
      description = "Mode of the decrypted secret file.";
    };
  };
}

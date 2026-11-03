{
  config,
  lib,
  ...
}:
let
  inherit (lib.types)
    bool
    enum
    listOf
    str
    strMatching
    ;
  inherit (lib.options) mkOption;
in
{
  options = {
    isVirtual = mkOption {
      type = bool;
      default = false;
      description = "Whether the system is running in a virtual environment";
    };
    latestZFSKernel = mkOption {
      type = bool;
      default = false;
      description = "Use latest available ZFS compatible kernel";
    };
    username = mkOption {
      type = str;
      default = "krokosik";
      description = "Username for the main user account";
    };
    extraUsers = mkOption {
      type = listOf (strMatching "^[a-z_][a-z0-9_-]*$");
      default = [ ];
      description = ''
        Additional interactive users receiving the shared configuration.
        Each user requires a password hash under login_password_hashes/<username>
        in the host's encrypted secrets.yaml.
      '';
    };
    role = mkOption {
      type = enum [
        "desktop"
        "server"
      ];
      default = "server"; # least privileged by default
      description = "Role of the machine, used to conditionally enable/disable certain services and configurations";
    };
    systemEmail = mkOption {
      type = str;
      default = "krokosik@pm.me";
      description = "Destination address for system email reports (e.g. root mail)";
    };
    publicDomain = mkOption {
      type = str;
      default = "krokosik.com";
      description = "Public domain name for the system, used for email and other services";
    };
    privateDomain = mkOption {
      type = str;
      default = "ts.${config.publicDomain}";
      description = "Internal domain name, automatically derived from publicDomain";
    };
  };
}

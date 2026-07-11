{
  config,
  lib,
  ...
}:
{
  options = {
    isVirtual = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the system is running in a virtual environment";
    };
    latestZFSKernel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use latest available ZFS compatible kernel";
    };
    username = lib.mkOption {
      type = lib.types.str;
      default = "krokosik";
      description = "Username for the main user account";
    };
    role = lib.mkOption {
      type = lib.types.enum [
        "desktop"
        "shared"
        "server"
      ];
      default = "server"; # least privileged by default
      description = "Role of the machine, used to conditionally enable/disable certain services and configurations";
    };
    systemEmail = lib.mkOption {
      type = lib.types.str;
      default = "krokosik@pm.me";
      description = "Destination address for system email reports (e.g. root mail)";
    };
    publicDomain = lib.mkOption {
      type = lib.types.str;
      default = "krokosik.com";
      description = "Public domain name for the system, used for email and other services";
    };
    privateDomain = lib.mkOption {
      type = lib.types.str;
      default = "ts.${config.publicDomain}"; 
      description = "Internal domain name, automatically derived from publicDomain";
    };
    vpsPrivateIp = lib.mkOption {
      type = lib.types.str;
      default = "100.72.36.37";
      description = "Private IP address of the VPS";
    };
    homeserverPrivateIp = lib.mkOption {
      type = lib.types.str;
      default = "100.100.250.77";
      description = "Private IP address of the homeserver";
    };
  };
}

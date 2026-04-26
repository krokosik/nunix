{
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
      type = lib.types.enum [ "desktop" "shared" "server" ];
      default = "server"; # least privileged by default
      description = "Role of the machine, used to conditionally enable/disable certain services and configurations";
    };
  };
}
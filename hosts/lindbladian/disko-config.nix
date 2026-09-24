{
  # Only manage Linux partitions. The Windows and recovery partitions share
  # this drive and must not be included in a disko GPT layout, so we specify
  # exact partitions.
  disko.devices.disk = {
    ESP = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-eui.002538433141c938-part5";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
    };

    root = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-eui.002538433141c938-part6";
      content = {
        type = "btrfs";
        extraArgs = [ "--force" ];
        subvolumes = {
          "/root" = {
            mountpoint = "/";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/home" = {
            mountpoint = "/home";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/nix" = {
            mountpoint = "/nix";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/var/log" = {
            mountpoint = "/var/log";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
        };
      };
    };
  };
}

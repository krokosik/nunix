{
  disko.devices = {
    disk = {
      tank1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD40EFZZ-68CPAN0_WD-WX52D56KTHH8";
        content = {
          type = "gpt";
          partitions.zfs = {
            end = "-8M";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };
      tank2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD40EFZZ-68CPAN0_WD-WX52D56AST5R";
        content = {
          type = "gpt";
          partitions.zfs = {
            end = "-8M";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };
    };
    zpool.tank = {
      type = "zpool";
      mode = "mirror";
      options = {
        ashift = "12";
        autoexpand = "on";
        cachefile = "none";
        failmode = "continue";
      };
      rootFsOptions = {
        acltype = "posixacl";
        canmount = "off";
        compression = "lz4";
        devices = "off";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        relatime = "on";
        xattr = "sa";
      };
      datasets = {
        data = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };
        "data/media" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/srv/media";
        };
        "data/immich" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/var/lib/immich";
        };
        "data/postgresql-backups" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/var/backup/postgresql";
        };
        reserved = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            refreservation = "100G";
          };
        };
      };
    };
  };
}

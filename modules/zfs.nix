# ZFS configs/backups
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) attrValues filterAttrs;
  inherit (lib.lists) last singleton sort;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) match versionOlder;
  inherit (lib) tryEval;
  # Use unstable packages when latestZFSKernel is enabled for better kernel support
  zfsPkgs = if config.latestZFSKernel then pkgs.unstable else pkgs;
  zfsPackage = if config.latestZFSKernel then zfsPkgs.zfs_unstable else pkgs.zfs;

  # Find latest available NixOS kernel compatible with ZFS
  zfsCompatibleKernelPackages = filterAttrs (
    name: kernelPackages:
    (match "linux_[0-9]+_[0-9]+" name) != null
    && (tryEval kernelPackages).success
    && (!kernelPackages.${zfsPackage.kernelModuleAttribute}.meta.broken)
  ) zfsPkgs.linuxKernel.packages;
  latestKernelPackage = last (
    sort (a: b: (versionOlder a.kernel.version b.kernel.version)) (
      attrValues zfsCompatibleKernelPackages
    )
  );
in
{
  boot = {
    # Note this might jump back and forth as kernels are added or removed.
    kernelPackages = mkIf config.latestZFSKernel latestKernelPackage;

    supportedFilesystems = singleton "zfs";

    zfs = {
      # Use zfs_unstable when latestZFSKernel is enabled
      package = mkIf config.latestZFSKernel zfsPackage;

      requestEncryptionCredentials = true;
      forceImportRoot = false;
      devNodes = "/dev/disk/by-id/";
    };
  };

  environment.systemPackages = with pkgs; [
    lzop
    mbuffer
    pv
  ];

  systemd.services.zfs-mount.enable = false;
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
}

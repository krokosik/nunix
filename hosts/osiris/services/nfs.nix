{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.lists) singleton;
in
{
  services.nfs.server.enable = mkIf (config.role == "server") true;

  # Export the media dataset as the NFSv4 root (clients mount osiris:/).
  # mountpoint prevents exporting the underlying directory if ZFS is absent.
  services.nfs.server.exports.${config.nixflix.mediaDir}."192.168.1.0/24" = [
    "ro"
    "sync"
    "root_squash"
    "no_subtree_check"
    "fsid=0"
    "mountpoint"
    "sec=sys"
  ];

  services.nfs.settings = {
    nfsd = {
      vers3 = false;
      vers4 = true;
      udp = false;
      tcp = true;
    };

    # Use server-side group membership for the client's numeric UID.
    mountd.manage-gids = true;
  };

  systemd.services.nfs-server.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;

  networking.firewall.extraInputRules = mkIf config.services.nfs.server.enable /* nftables */ ''
    ip saddr 192.168.1.0/24 tcp dport 2049 accept comment "NFS media LAN"
  '';
}

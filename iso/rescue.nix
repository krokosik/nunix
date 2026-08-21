{
  modulesPath,
  pkgs,
  ...
}:
let
  rescueEnterNixos = pkgs.callPackage (
    {
      coreutils,
      cryptsetup,
      util-linux,
      writeShellApplication,
    }:
    writeShellApplication {
      name = "rescue-enter-nixos";
      runtimeInputs = [
        coreutils
        cryptsetup
        util-linux
      ];
      text = /* bash */ ''
        set -euo pipefail

        usage() {
          cat <<'EOF'
        Usage: rescue-enter-nixos --luks-device DEVICE --esp-device DEVICE [--mapper-name NAME]

        Unlock a LUKS volume containing Btrfs subvolumes named root, home, nix,
        and var/log; mount them at /mnt with the EFI system partition; then enter
        the installed NixOS system.
        EOF
        }

        luksDevice=""
        espDevice=""
        mapperName="cryptroot"

        while (( $# > 0 )); do
          case "$1" in
            --luks-device)
              luksDevice="$2"
              shift 2
              ;;
            --esp-device)
              espDevice="$2"
              shift 2
              ;;
            --mapper-name)
              mapperName="$2"
              shift 2
              ;;
            --help)
              usage
              exit 0
              ;;
            *)
              usage >&2
              exit 1
              ;;
          esac
        done

        if [[ -z "$luksDevice" || -z "$espDevice" ]]; then
          usage >&2
          exit 1
        fi

        if mountpoint --quiet /mnt; then
          printf '%s\n' '/mnt is already mounted; use rescue-unmount-nixos first.' >&2
          exit 1
        fi

        if cryptsetup status "$mapperName" >/dev/null 2>&1; then
          printf '%s\n' "The $mapperName mapping already exists; choose --mapper-name or close it first." >&2
          exit 1
        fi

        cleanup() {
          umount --recursive /mnt || true
          cryptsetup close "$mapperName" || true
        }
        trap cleanup ERR

        cryptsetup open "$luksDevice" "$mapperName"
        mount --options subvol=root "/dev/mapper/$mapperName" /mnt
        mkdir --parents /mnt/home /mnt/nix /mnt/var/log /mnt/boot
        mount --options subvol=home "/dev/mapper/$mapperName" /mnt/home
        mount --options subvol=nix "/dev/mapper/$mapperName" /mnt/nix
        mount --options subvol=var/log "/dev/mapper/$mapperName" /mnt/var/log
        mount "$espDevice" /mnt/boot

        exec /run/current-system/sw/bin/nixos-enter --root /mnt
      '';
    }
  ) { };

  rescueUnmountNixos = pkgs.callPackage (
    {
      cryptsetup,
      util-linux,
      writeShellApplication,
    }:
    writeShellApplication {
      name = "rescue-unmount-nixos";
      runtimeInputs = [
        cryptsetup
        util-linux
      ];
      text = /* bash */ ''
        set -euo pipefail

        mapperName="''${1:-cryptroot}"

        if mountpoint --quiet /mnt; then
          umount --recursive /mnt
        fi

        if cryptsetup status "$mapperName" >/dev/null 2>&1; then
          cryptsetup close "$mapperName"
        fi
      '';
    }
  ) { };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  networking = {
    hostName = "nixos-rescue";
    networkmanager.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # BOOT AND FIRMWARE
    efibootmgr
    limine
    mokutil
    sbctl
    sbsigntool
    tpm2-tools

    # STORAGE AND FILESYSTEMS
    btrfs-progs
    cryptsetup
    ddrescue
    dosfstools
    e2fsprogs
    exfatprogs
    gptfdisk
    hdparm
    lvm2
    mtools
    ntfs3g
    nvme-cli
    parted
    smartmontools
    testdisk
    xfsprogs

    # HARDWARE DIAGNOSTICS
    dmidecode
    fwupd
    hwinfo
    lshw
    pciutils
    usbutils

    # NETWORKING AND REMOTE ACCESS
    curl
    ethtool
    git
    inetutils
    iperf3
    iw
    mtr
    nmap
    openssh
    rsync
    wget

    # GENERAL UTILITIES
    btop
    file
    hexedit
    jq
    neovim
    ripgrep
    tmux
    tree

    rescueEnterNixos
    rescueUnmountNixos
  ];
}

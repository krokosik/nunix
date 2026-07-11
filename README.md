### Hosts

To add a host:

1. Add it to `flake.nix` (`mkSystem`).
<!-- 2. Set its wireguard address in the host's `configuration.nix` -->
   <!-- (`networks."wg0".address`). -->
<!-- 3. Add its LAN IPs to `networking.hosts` in -->
   <!-- `hosts/modules/desktops/networking.nix`. -->
4. Add sops keys (see the install/post-install sections below).
5. Install per [General Install Procedures](#general-install-procedures).

## General Install Procedures

### Tips

1. Generate hostId (for ZFS systems): `head -c4 /dev/urandom | od -A none -t x4`
2. Hetzner VMs apparently require grub instead of systemd-boot (as of 2025-08)
3. Available options:
    a. isVirtual (bool) - set for virtual hardware (VPS or VM). Default false.
    b. latestZFSKernel (bool) - set to use latest available ZFS compatible kernel. Default false.
    c. username (string) - set to override default username. Default krokosik.
    d. role (desktop|server|shared) - set host role. Shared stands for a workstation also used by others. Default server.

### Installing using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)

1. Create new (Ubuntu is fine) cloud server. Add one of the public keys. Adjust
   DNS 'A' records if needed.
2. SSH into the new box and update the disk device name(s) and partition layout
   (if needed) in disko-config.nix.
3. Make sure the hostname and username are set in the same way as for the target host, so that connecting via ssh keeps working.
4. Prepare ssh key and add it to the secrets config:
```bash
mkdir -p /tmp/nixos-anywhere-extra/etc/ssh
ssh-keygen -t ed25519 -N "" -f /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key
cat /tmp/nixos-anywhere-extra/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```
5. Add the public key to the secrets config and run `sops updatekeys` on relevant files.
6. Commit the changes in the secrets repo.
7. `just deploy-new <host>` to install NixOS and the configuration for the new host.
8. If problems arise, add `--no-reboot` to the above command so you can
   troubleshoot the new install.
        

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
3. `just deploy-new <host>` to install NixOS and the configuration for the new host.
4. If problems arise, add `--no-reboot` to the above command so you can
   troubleshoot the new install.
5. [[#post-install]]

### Post install

1. *new host* Generate SSH keys per [SSH key generation](#ssh-key-generation-new-or-rebuilt-host) above.
2. *existing host* Sync ~/nixos/ directory to new machine (including nixos configs and secrets)
3. *existing host* Update sops key after reinstall. Commit and sync then rebuild.
```bash
nix shell nixpkgs#ssh-to-age nixpkgs#sops
ssh-keyscan <hostname> | ssh-to-age
# Set `&<hostname> age.....` in nixos-secrets/.sops.yaml
sops updatekeys nixos-secrets/<hostname>/secrets.yml
sops updatekeys nixos-secrets/common/secrets.yml
git add .sops.yaml <homename>/ && git commit -m 'Update sops keys'
```
        
4. *existing host* `nix flake update` and rebuild flake on target machine after
   sops key is updated.
<!-- 5. *new host* `sudo nmcli connection import type wireguard file
   /etc/wireguard/wg0.conf`
   for networkmanager.
6. Update syncthing device ID's if necessary. Re-add servers on phones and
   wife's laptop if needed.
7. *existing host* `echo nixos/flake.lock > ~/nixos/.stignore` (keep flake.lock
   from syncing) -->
        

{
  ...
}:
{
  imports = [ ../common/tailscale.nix ];

  services.tailscale = {
    # Desktop nodes are authenticated interactively with `tailscale up`.
    # Deliberately leave authKeyFile unset so a reusable auth key is not
    # required in the desktop secrets.
    extraUpFlags = [
      "--ssh"
      "--advertise-tags=tag:desktop"
    ];
  };
}

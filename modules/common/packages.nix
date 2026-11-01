{
  pkgs,
  ...
}:
{
  # General systemwide packages
  environment.systemPackages = with pkgs; [
    curl
    dust
    exfatprogs
    ghostty.terminfo
    hwinfo
    jq
    libsecret
    nix-tree
    nixfmt
    nixd
    pciutils
    python3
    rsync
    wget
    usbutils
  ];
}

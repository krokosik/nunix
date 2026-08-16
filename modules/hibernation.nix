{
  # The encrypted swap mapping is created by disko. NixOS uses this target
  # when generating the initrd resume configuration for hibernation.
  boot.resumeDevice = "/dev/mapper/cryptswap";
}

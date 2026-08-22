{
  deployKeys = {
    anubis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUTKDQm7saPW6jNaNQUgrABtzK3M8vQssCCCXLRryrG krokosik@anubis";
    horus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw9/vuQetryM92flnnOazWpHJSfvK9am/JVmUiZLHsu krokosik@horus";
    osiris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7sOgLyyDNodmu4kHYGbFWfKhYIQYRIxBRCBaPTD2vU krokosik@osiris";
  };

  knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}

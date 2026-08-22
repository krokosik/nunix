{
  # Register these per-host user keys as read-only deploy keys on GitHub.
  # Remember to add them on the GitHub repo under deploy keys as well.
  deployKeys = {
    anubis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUTKDQm7saPW6jNaNQUgrABtzK3M8vQssCCCXLRryrG krokosik@anubis";
    horus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw9/vuQetryM92flnnOazWpHJSfvK9am/JVmUiZLHsu krokosik@horus";
    osiris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7sOgLyyDNodmu4kHYGbFWfKhYIQYRIxBRCBaPTD2vU krokosik@osiris";
  };

  # Pin GitHub's published ED25519 host key for the github-secrets alias.
  knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}

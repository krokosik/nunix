{
  deployKeys = {
    anubis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGV4rBomKDF6oD/H0gTHK7kcw2Id36RLQ5SLMy03qUer krokosik@legion";
    horus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvaPAP0/qNC9NpC3qz7RSHpgT9+OcvAEWz9Y8q4QmCJ krokosik@osiris";
    osiris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICe/ngBcMq4U617INsnKl/8aNqp+zqRe/QmE+cVrfuyL root@osiris";
  };

  knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}

{
  services.earlyoom = {
    enable = true;
    extraArgs = [
      "--prefer"
      "(^|/)(electron|beepertexts|zen-bin)$"
    ];
  };
}

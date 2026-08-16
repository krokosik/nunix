{
  services.earlyoom = {
    enable = true;
    extraArgs = [
      "--report-interval"
      "3600"
      "--prefer"
      "(^|/)(electron|beepertexts|zen-bin)$"
    ];
  };
}

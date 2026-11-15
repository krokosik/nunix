{
  services.locate.enable = true;

  systemd.services.update-locatedb.unitConfig.ConditionACPower = true;
}

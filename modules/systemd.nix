{
  settings = {
    Manager = {
      DefaultIOAccounting = true;
      DefaultIPAccounting = true;
      # Faster shutdowns
      DefaultTimeoutStopSec = "5s";
      # Raise soft file descriptor limit from systemd's default of 1024 to 65536
      # so dev tools (VS Code, Docker, dev servers, databases) get the headroom they need
      DefaultLimitNOFILE = "65536:524288";
    };
  };
  systemd.services."user@" = {
    serviceConfig = {
      TimeoutStopSec = "5s";
    };
  };
}

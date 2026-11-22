{
  imports = [
    ./apps.nix
    ./audio.nix
    ./nm-stub.nix
    ../../../modules/desktop/bluetooth.nix
    ../../../modules/desktop/kdeconnect.nix
    ./theme.nix
    ./power.nix
    ./session.nix
    ./user.nix
  ];
}

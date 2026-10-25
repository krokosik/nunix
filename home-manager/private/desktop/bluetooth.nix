{ lib, ... }:
let
  inherit (lib.hm.gvariant) mkTuple;
  inherit (lib.lists) singleton;
in
{
  # Blueman uses the zero UUID for device connections; audio UUIDs are unsupported.
  dconf.settings."org/blueman/plugins/autoconnect".services = singleton (mkTuple [
    "04:52:C7:C7:B4:63" # QC35
    "00000000-0000-0000-0000-000000000000"
  ]);
}

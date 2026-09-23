{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  bucket = config.mkGarageBucket.livesync.bucketName;
in
{
  mkGarageBucket.livesync = {
    credentialOwner = config.username;
    consumerService = singleton "livesync-garage-bucket.target";
  };

  systemd.targets.livesync-garage-bucket.wantedBy = singleton "multi-user.target";

  # Keep the existing Garage route private; only this bucket is exposed publicly.
  mkTraefikServices.livesync = {
    public = true;
    port = 3900;
    chain = singleton "chain-no-auth";
  };

  services.traefik.dynamicConfigOptions.http.routers.livesync.rule =
    lib.mkForce "Host(`livesync.${config.publicDomain}`) && (Path(`/${bucket}`) || PathPrefix(`/${bucket}/`))";
}

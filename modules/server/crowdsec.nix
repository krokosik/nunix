(
  { pkgs, inputs, ... }:
  let
    secretspath = builtins.toString inputs.my-secrets;
  in
  {
    services.crowdsec =
      let
        yaml = (pkgs.formats.yaml { }).generate;
        acquisitions_file = yaml "acquisitions.yaml" {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        };
      in
      {
        allowLocalJournalAccess = true;
        settings = {
          crowdsec_service.acquisition_path = acquisitions_file;
        };
      };

    # nixpkgs.overlays = [inputs.crowdsec.overlays.default];

    # services.crowdsec-firewall-bouncer = {
    #   enable = true;
    #   settings = {
    #     api_key = "<api-key>";
    #     api_url = "http://localhost:8080";
    #   };
    # };

    sops.secrets.crowdsec_enroll_key = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      owner = "root";
      mode = "0400";
    };
  }
)

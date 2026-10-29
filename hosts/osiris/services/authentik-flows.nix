{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;

  yaml = pkgs.formats.yaml { };

  # These bundled paths now delegate to the consolidated authentication blueprint.
  delegatedDefaults = {
    "flow-default-authenticator-static-setup.yaml" = "Default - Static MFA setup flow";
    "flow-default-authenticator-totp-setup.yaml" = "Default - TOTP MFA setup flow";
    "flow-default-authenticator-webauthn-setup.yaml" = "Default - WebAuthn MFA setup flow";
    "flow-default-source-authentication.yaml" = "Default - Source authentication flow";
    "flow-default-source-enrollment.yaml" = "Default - Source enrollment flow";
    "flow-default-invalidation-flow.yaml" = "Default - Invalidation flow";
    "flow-default-provider-authorization-explicit-consent.yaml" =
      "Default - Provider authorization flow (explicit consent)";
    "flow-default-provider-authorization-implicit-consent.yaml" =
      "Default - Provider authorization flow (implicit consent)";
    "flow-default-source-pre-authentication.yaml" = "Default - Source pre-authentication flow";
    "flow-default-provider-invalidation.yaml" = "Default - Provider invalidation flow";
    "flow-oobe.yaml" = "Default - Out-of-box-experience flow";
    "flow-password-change.yaml" = "Default - Password change flow";
    "flow-default-user-settings-flow.yaml" = "Default - User settings flow";
    "default-brand.yaml" = "Default - Brand";
  };

  delegateBlueprint =
    filename: name:
    yaml.generate filename {
      version = 1;
      metadata = { inherit name; };
      entries = [ ];
    };
in
{
  mkAuthentik.extraBlueprints = mkIf config.services.authentik.enable (
    singleton (
      pkgs.runCommandLocal "authentik-flows-blueprint" { } /* bash */ ''
        mkdir --parents "$out/default"
        cp ${./authentik-blueprints/flows.yaml} "$out/default/flow-default-authentication-flow.yaml"
        substituteInPlace "$out/default/flow-default-authentication-flow.yaml" \
          --replace-fail 'authentik.krokosik.com' 'authentik.${config.publicDomain}'
        ${concatStringsSep "\n" (
          mapAttrsToList (filename: name: /* bash */ ''
            cp ${delegateBlueprint filename name} "$out/default/${filename}"
          '') delegatedDefaults
        )}
      ''
    )
  );
}

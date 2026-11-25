# OCI containers - Simple Aspect
# Rootless Podman backend for virtualisation.oci-containers. Every container
# runs under its own unprivileged system user (one user namespace per svc,
# no root daemon). Backend-agnostic container declarations live in their own
# service modules.
#
# `mkContainerServices.<name>` is the container analogue of `traefik.services`
# (see traefik.nix): service modules declare the low-level plumbing that every
# containerized svc repeats as a one-attr declaration here: the dedicated host
# user, its uid mapping into the image, the state dirs, the 127.0.0.1 host-port
# bind and the TZ env. This module emits the corresponding `users.*`,
# `systemd.tmpfiles.rules` and `oci-containers.containers.*` fragments. svc
# modules keep only what's genuinely svc-specific (image, volumes, extra env).
# The `mk`-prefix marks an option owned by this flake (vs upstream
# `virtualisation.*`).
#
# Identity model: host user `<name>` (static `uid`) is mapped onto the uid
# the image runs as (`ctrUid`/`ctrGid`) with `--userns=keep-id`, so files
# that the container writes into bind-mounted state dirs are owned by
# `<name>` on the host. Podman's image/container storage lives in the user's
# home under /var/lib/podman/<name>. It is disposable, so keep it out of
# backups.

{
  config,
  lib,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs mapAttrsToList optionalAttrs;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.lists) concatMap;
  inherit (lib.lists)
    concatLists
    optional
    singleton
    unique
    length
    ;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.types)
    attrsOf
    bool
    int
    listOf
    nullOr
    port
    str
    submodule
    ;

  cfg = config.mkContainers;
  svcs = config.mkContainerServices;
  homeOf = name: "/var/lib/podman/${name}";
in
{
  options.mkContainers.enable = mkEnableOption ''
    rootless Podman as the oci-containers backend, plus the per-svc
    plumbing declared through `mkContainerServices`
  '';

  options.mkContainerServices = mkOption {
    type = attrsOf (
      submodule (
        { name, config, ... }:
        {
          options = {
            uid = mkOption {
              type = int;
              description = ''
                Static uid (and gid) of the host user `<name>` the container
                runs under. Must be static: the upstream rootless unit derives
                `RequiresMountsFor=/run/user/<uid>/containers` from it.
              '';
            };
            ctrUid = mkOption {
              type = int;
              default = 0;
              description = ''
                uid the image runs as. Mapped onto the host user via
                `--userns=keep-id`. 0 (container root) needs no mapping: rootless
                Podman already maps container root to the host user.
              '';
            };
            ctrGid = mkOption {
              type = int;
              default = config.ctrUid;
              defaultText = literalExpression "config.ctrUid";
              description = "gid the image runs as. Defaults to `ctrUid`.";
            };
            linuxServer = mkOption {
              type = bool;
              default = false;
              description = ''
                Image starts as root and drops privileges itself
                (linuxserver.io-style entrypoints): run as container root and
                emit PUID/PGID = ctrUid/ctrGid, which keep-id maps to the host user.
              '';
            };
            extraGroups = mkOption {
              type = listOf str;
              default = [ ];
              example = [
                "render"
                "video"
              ];
              description = ''
                Supplementary host groups for the svc user (e.g. for device
                access). When set, `--group-add=keep-groups` passes them into
                the container.
              '';
            };
            hostPorts = mkOption {
              type = listOf port;
              default = [ ];
              example = [ 5432 ];
              description = ''
                Host loopback TCP ports the container reaches as 127.0.0.1:<port>
                (pasta `-T`). Connections arrive on the host from 127.0.0.1, so
                host services (e.g. postgres) can keep their loopback-only rules.
                `host.containers.internal` instead arrives from the host's LAN
                address.
              '';
            };
            port = mkOption {
              type = nullOr port;
              default = null;
              description = ''
                Host port to publish on 127.0.0.1. Left null for svcs that
                don't publish a host port at all — no `ports` entry is emitted
                in that case. Rootless: must be >= 1024.
              '';
            };
            containerPort = mkOption {
              type = nullOr port;
              default = config.port;
              defaultText = literalExpression "config.port";
              description = "Port the svc listens on inside the container. Defaults to `port`.";
            };
            stateDirs = mkOption {
              type = listOf str;
              default = singleton "/var/lib/${name}";
              defaultText = literalExpression ''[ "/var/lib/''${name}" ]'';
              description = ''
                Host directories for this container's persistent state, created
                0750 and recursively owned by the svc user. Multi-subdir svcs
                list every subdir they bind-mount.
              '';
            };
            tzEnv = mkOption {
              type = bool;
              default = true;
              description = "Emit `TZ = config.time.timeZone` in the container environment.";
            };
            serviceUnit = mkOption {
              type = str;
              readOnly = true;
              default = "podman-${name}.service";
              description = "systemd unit running the container, for observability/ordering.";
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Containerized svcs' shared plumbing: dedicated rootless user, uid
      mapping, state dirs, the 127.0.0.1 host-port bind and TZ. Mirrors
      `mkTraefikServices` — one declaration per svc, emitted into `users`,
      `systemd.tmpfiles.rules` and `virtualisation.oci-containers.containers`.
    '';
  };

  config = mkMerge [
    {
      # Declaring svcs on a host without the aspect would emit nothing.
      assertions = singleton {
        assertion = svcs == { } || cfg.enable;
        message = "mkContainerServices is set but mkContainers.enable is false";
      };
    }

    (mkIf cfg.enable {
      assertions =
        mapAttrsToList (name: svc: {
          assertion = svc.port == null || (svc.containerPort != null && svc.port >= 1024);
          message = "mkContainerServices.${name}: rootless host port must be >= 1024 and containerPort non-null";
        }) svcs
        ++ singleton (
          let
            uids = mapAttrsToList (_: svc: svc.uid) svcs;
          in
          {
            assertion = length uids == length (unique uids);
            message = "mkContainerServices: every svc needs a distinct uid";
          }
        );

      users = {
        users = mapAttrs (name: svc: {
          isSystemUser = true;
          inherit (svc) uid extraGroups;
          group = name;
          home = homeOf name;
          createHome = true;
          autoSubUidGidRange = true;
          linger = true;
        }) svcs;
        groups = mapAttrs (_: svc: { gid = svc.uid; }) svcs;
      };

      virtualisation = {
        podman = {
          enable = true;
          autoPrune.enable = true;
        };
        oci-containers = {
          backend = "podman";

          # Per-svc container fragments contributed via `mkContainerServices.<name>`.
          # Each entry merges with the svc module's own container definition
          # (image, volumes, extra env), which stays in the svc module.
          containers = mapAttrs (
            name: svc:
            mkMerge [
              {
                podman.user = name;
                extraOptions = [
                  "--security-opt=no-new-privileges"
                ]
                ++ optional (
                  svc.ctrUid != 0
                ) "--userns=keep-id:uid=${toString svc.ctrUid},gid=${toString svc.ctrGid}"
                ++ optional (svc.extraGroups != [ ]) "--group-add=keep-groups"
                ++ optional (svc.hostPorts != [ ]) (
                  "--network=pasta:"
                  + concatStringsSep "," (
                    concatMap (p: [
                      "-T"
                      (toString p)
                    ]) svc.hostPorts
                  )
                );
              }
              (optionalAttrs (svc.port != null) {
                ports = singleton "127.0.0.1:${toString svc.port}:${toString svc.containerPort}";
              })
              (optionalAttrs svc.linuxServer {
                user = "0:0";
                environment = {
                  PUID = toString svc.ctrUid;
                  PGID = toString svc.ctrGid;
                };
              })
              (optionalAttrs svc.tzEnv {
                environment.TZ = config.time.timeZone;
              })
            ]
          ) svcs;
        };
      };

      # State dirs are owned by the svc user. `Z` re-chowns pre-existing data
      # (e.g. left behind by the former rootful Docker uids) on activation.
      systemd.tmpfiles.rules = concatLists (
        mapAttrsToList (
          name: svc:
          concatLists (
            map (dir: [
              "d ${dir} 0750 ${name} ${name} -"
              "Z ${dir} - ${name} ${name} -"
            ]) svc.stateDirs
          )
        ) svcs
      );
    })
  ];
}

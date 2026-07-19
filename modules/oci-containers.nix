# OCI containers - Simple Aspect
# Docker backend for virtualisation.oci-containers. Backend-agnostic
# container declarations live in their own service modules.
#
# `myContainerService.<name>` is the container analogue of `traefik.services`
# (see traefik.nix): service modules declare the low-level plumbing that every
# containerized svc repeats — the /var/lib/containers/<svc> tmpfiles
# rules, the 127.0.0.1 host-port bind, the runtime user identity, and
# the TZ env — as a one-attr declaration here, and this module emits the
# corresponding `systemd.tmpfiles.rules` + `oci-containers.containers.*`
# fragments. svc modules keep only what's genuinely svc-specific (image,
# volumes, extra env). The `my`-prefix marks an option owned by this
# flake (vs upstream `virtualisation.*`).

{
  config,
  lib,
  ...
}:
let
  serverUid = 1234;
  serverGid = 1234;
in
{
  options.myContainerServices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            port = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = ''
                Host port to publish on 127.0.0.1. Left null for svcs that
                don't publish a host port at all (e.g. valheim, which uses
                `--network=host` and opens UDP game ports on the firewall
                directly) — no `ports` entry is emitted in that case.
              '';
            };
            containerPort = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = config.port;
              defaultText = lib.literalExpression "config.port";
              description = "Port the svc listens on inside the container. Defaults to `port`.";
            };
            stateDirs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "/var/lib/containers/${name}" ];
              defaultText = lib.literalExpression ''[ "/var/lib/containers/''${name}" ]'';
              description = ''
                Host directories to create (0750, owned by stateDirOwner:stateDirGroup)
                for this container's persistent state. Multi-subdir svcs list every
                subdir they bind-mount.
              '';
            };
            stateDirOwner = lib.mkOption {
              type = lib.types.str;
              default = toString serverUid;
              defaultText = lib.literalExpression "toString serverUid";
              description = "Owner for the stateDirs tmpfiles rules. Defaults to the server user's uid.";
            };
            stateDirGroup = lib.mkOption {
              type = lib.types.str;
              default = toString serverGid;
              defaultText = lib.literalExpression "toString serverGid";
              description = "Group for the stateDirs tmpfiles rules. Defaults to the servers gid.";
            };
            tzEnv = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Emit `TZ = config.time.timeZone` in the container environment.";
            };
            manageUser = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether this module sets the container's runtime user identity.
                Set false for images that take their uid/gid via svc-specific env
                vars the module doesn't model (e.g. grimmory's USER_ID/GROUP_ID) —
                the svc module then sets those itself.
              '';
            };
            linuxServer = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Emit PUID/PGID env (server uid/gid) instead of a container
                `user =` override, for images that start as root and drop
                privileges themselves (linuxserver.io-style entrypoints).
                Only meaningful when `manageUser` is true.
              '';
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Containerized svcs' shared plumbing: per-svc state dirs, the
      127.0.0.1 host-port bind, runtime user identity, and TZ. Mirrors
      `myTraefik.svcs` — one declaration per svc, emitted into
      `systemd.tmpfiles.rules` and `virtualisation.oci-containers.containers`.
    '';
  };

  config = {
    # Guard the port-bind emitter above: it builds
    # "127.0.0.1:${port}:${containerPort}" whenever `port` is set, so a
    # null `containerPort` would emit a malformed bind ending in a bare
    # colon. `containerPort` defaults to `config.port`, so nothing trips
    # this today — it's a latent guard against a future svc decoupling
    # the two.
    assertions = lib.mapAttrsToList (name: svc: {
      assertion = svc.port == null || svc.containerPort != null;
      message = "myContainerServices.${name}: containerPort must not be null when port is set";
    }) config.myContainerServices;

    # Backend specific configuration for the container runtime.
    users.users.${config.username}.extraGroups = [ "docker" ];

    # Containers on the default docker bridge reach host services
    # (postgres, etc.) via host.containers.internal -> 10.88.0.1.
    # Trust the bridge so the firewall doesn't drop those packets.
    networking.firewall.trustedInterfaces = [ "docker0" ];

    virtualisation = {
      docker = {
        enable = true;
        autoPrune.enable = true;
        daemon.settings = {
          log-driver = "json-file";
          log-opts = {
            max-size = "10m";
            max-file = "3";
          };
          dns = [ "172.17.0.1" ];
          bip = "172.17.0.1/16";
        };
        enableOnBoot = config.role == "server";
      };
      oci-containers.backend = "docker";

      # Per-svc container fragments contributed via `myContainerServices.<name>`.
      # Each entry merges with the svc module's own container definition
      # (image, volumes, extra env), which stays in the svc module.
      oci-containers.containers = lib.mapAttrs (
        _: svc:
        lib.mkMerge [
          (lib.optionalAttrs (svc.port != null) {
            ports = [ "127.0.0.1:${toString svc.port}:${toString svc.containerPort}" ];
          })
          (lib.optionalAttrs (svc.manageUser && svc.linuxServer) {
            environment = {
              PUID = toString serverUid;
              PGID = toString serverGid;
            };
          })
          (lib.optionalAttrs (svc.manageUser && !svc.linuxServer) {
            user = "${toString serverUid}:${toString serverGid}";
          })
          (lib.optionalAttrs svc.tzEnv {
            environment.TZ = config.time.timeZone;
          })
          {
            extraOptions = [ "--security-opt=no-new-privileges" ];
          }
        ]
      ) config.myContainerServices;
    };

    # docker isn't allowed to forward packets from docker0 to the actual NIC by default
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

    # Parent directory for all containerized svc state. svcs create their
    # own subdirs (/var/lib/containers/<svc>) owned by the server user,
    # which lets a single backup path cover every svc automatically.
    # Per-svc subdirs come from `myContainerServices.<name>.stateDirs`.
    systemd.tmpfiles.rules = [
      "d /var/lib/containers 0755 root root -"
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (
        _: svc: map (dir: "d ${dir} 0750 ${svc.stateDirOwner} ${svc.stateDirGroup} -") svc.stateDirs
      ) config.myContainerServices
    );
  };
}

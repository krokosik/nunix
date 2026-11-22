# Read-only NetworkManager stand-in for the TV session.
#
# osiris uses systemd-networkd. Plasma's network applet (NetworkManagerQt) and
# Qt's QNetworkInformation (Discover's "no network" banner) only understand the
# NetworkManager D-Bus API, so without it they report "disconnected" even though
# networking works. This service owns org.freedesktop.NetworkManager and always
# reports global connectivity with no devices or connections. It cannot change
# anything: it has no writable properties and no mutating methods.
#
# GLib's GNetworkMonitor (Flatpak, GTK apps) also prefers NetworkManager when it
# is present, so those apps see "online" from this stub too.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;

  busName = "org.freedesktop.NetworkManager";
  user = "nm-stub";

  nmStub = pkgs.writers.writePython3Bin "nm-stub" {
    libraries = singleton pkgs.python3Packages.dbus-next;
    # dbus-next uses D-Bus signatures ("ao") as annotations; flake8 reads them as names.
    flakeIgnore = [
      "E501"
      "F722"
      "F821"
    ];
  } /* python */ ''
    import asyncio

    from dbus_next import BusType, PropertyAccess
    from dbus_next.aio import MessageBus
    from dbus_next.service import ServiceInterface, dbus_property, method

    NM_STATE_CONNECTED_GLOBAL = 70
    NM_CONNECTIVITY_FULL = 4
    NM_METERED_NO = 2

    READ = PropertyAccess.READ


    class NetworkManager(ServiceInterface):
        def __init__(self):
            super().__init__("${busName}")

        @method()
        def GetDevices(self) -> "ao":
            return []

        @method()
        def GetAllDevices(self) -> "ao":
            return []

        @method()
        def GetPermissions(self) -> "a{ss}":
            return {}

        @method(name="state")
        def state_(self) -> "u":
            return NM_STATE_CONNECTED_GLOBAL

        @method()
        def CheckConnectivity(self) -> "u":
            return NM_CONNECTIVITY_FULL

        @dbus_property(access=READ)
        def Devices(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def AllDevices(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def Checkpoints(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def ActiveConnections(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def PrimaryConnection(self) -> "o":
            return "/"

        @dbus_property(access=READ)
        def PrimaryConnectionType(self) -> "s":
            return "802-3-ethernet"

        @dbus_property(access=READ)
        def ActivatingConnection(self) -> "o":
            return "/"

        @dbus_property(access=READ)
        def NetworkingEnabled(self) -> "b":
            return True

        @dbus_property(access=READ)
        def WirelessEnabled(self) -> "b":
            return False

        @dbus_property(access=READ)
        def WirelessHardwareEnabled(self) -> "b":
            return False

        @dbus_property(access=READ)
        def WwanEnabled(self) -> "b":
            return False

        @dbus_property(access=READ)
        def WwanHardwareEnabled(self) -> "b":
            return False

        @dbus_property(access=READ)
        def Startup(self) -> "b":
            return False

        @dbus_property(access=READ)
        def Version(self) -> "s":
            return "1.50.0"

        @dbus_property(access=READ)
        def Capabilities(self) -> "au":
            return []

        @dbus_property(access=READ)
        def State(self) -> "u":
            return NM_STATE_CONNECTED_GLOBAL

        @dbus_property(access=READ)
        def Connectivity(self) -> "u":
            return NM_CONNECTIVITY_FULL

        @dbus_property(access=READ)
        def ConnectivityCheckAvailable(self) -> "b":
            return False

        @dbus_property(access=READ)
        def ConnectivityCheckEnabled(self) -> "b":
            return False

        @dbus_property(access=READ)
        def Metered(self) -> "u":
            return NM_METERED_NO

        @dbus_property(access=READ)
        def GlobalDnsConfiguration(self) -> "a{sv}":
            return {}


    class Settings(ServiceInterface):
        def __init__(self):
            super().__init__("${busName}.Settings")

        @method()
        def ListConnections(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def Connections(self) -> "ao":
            return []

        @dbus_property(access=READ)
        def Hostname(self) -> "s":
            return "${config.networking.hostName}"

        @dbus_property(access=READ)
        def CanModify(self) -> "b":
            return False


    async def main():
        bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
        bus.export("/org/freedesktop/NetworkManager", NetworkManager())
        bus.export("/org/freedesktop/NetworkManager/Settings", Settings())
        await bus.request_name("${busName}")
        await bus.wait_for_disconnect()


    asyncio.run(main())
  '';

  # Only the stub user may own the name; anyone may read from it.
  dbusPolicy = pkgs.writeTextDir "share/dbus-1/system.d/nm-stub.conf" /* xml */ ''
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <policy user="${user}">
        <allow own="${busName}"/>
      </policy>
      <policy context="default">
        <allow send_destination="${busName}"/>
      </policy>
    </busconfig>
  '';
in
{
  assertions = singleton {
    assertion = !config.networking.networkmanager.enable;
    message = "nm-stub would conflict with the real NetworkManager.";
  };

  users = {
    users.${user} = {
      isSystemUser = true;
      group = user;
    };
    groups.${user} = { };
  };

  services.dbus.packages = singleton dbusPolicy;

  systemd.services.nm-stub = {
    description = "Read-only NetworkManager D-Bus stand-in";
    wantedBy = singleton "multi-user.target";
    after = singleton "dbus.service";
    serviceConfig = {
      Type = "dbus";
      BusName = busName;
      ExecStart = lib.meta.getExe nmStub;
      User = user;
      Group = user;
      Restart = "on-failure";

      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = singleton "AF_UNIX";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = singleton "@system-service";
      UMask = "0077";
    };
  };
}

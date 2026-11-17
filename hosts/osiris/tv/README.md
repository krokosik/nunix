# OSIRIS TV

The server role and existing server services remain enabled independently of SDDM.
The dedicated `tv` account automatically starts Plasma Bigscreen. Its password is
locked and it has no administrative groups. KDE packages come from the existing
unstable input; other system packages retain the stable base.

From an administrative SSH session, stop or restart the TV interface:

```sh
sudo systemctl stop display-manager.service
sudo systemctl restart display-manager.service
```

To keep it off across boots, mask it; unmask before restarting:

```sh
sudo systemctl mask display-manager.service
sudo systemctl unmask display-manager.service
```

When the hardware arrives, use Blueman to pair and trust the remote, select HDMI
output in the audio settings, and verify unplug/replug and TV power cycling.
Open Jellyfin Desktop, select TV layout/fullscreen, and log in with a media user.
Open Moonlight and add Horus at its Tailscale address, then complete PIN pairing
in Sunshine. Reach Sunshine management through an SSH tunnel to localhost:47990.
Horus must be awake with a graphical session for capture.

Before deployment, build on lindbladian and confirm deployment separately.
After deployment test server health with the display manager stopped and HDMI
unplugged. Test hardware decoding, audio, navigation and client exit behavior.
Immich, HDR, surround passthrough and unattended headless Horus capture are deferred.

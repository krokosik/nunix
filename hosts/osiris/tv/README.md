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

Moonlight TV is packaged from a pinned upstream revision, including submodules.
Its Linux frontend launches the bundled Moonlight Embedded backend. Moonlight Qt
remains installed as a fallback; verify decoding performance and remote controls
in a real streaming session before choosing a preferred client.

The TV uses its own Stylix module with Tokyo Night Dark, the desktop wallpaper,
Bibata cursor, and Inter font. Only the TV user's KDE and GTK targets are enabled;
the desktop Flatpak overrides and additional font collections are not imported.
Moonlight TV's SDL/LVGL interface has its own theme rather than using KDE colours.

The experimental backend explicitly enables X11/EGL/VA-API dependencies and uses
FFmpeg's default VA-API device selection instead of hardcoding X display `:0`.
Hardware decoding runs through XWayland, not native Wayland. Confirm that the
streaming session selects VA-API and monitor Intel video-engine activity before
relying on it; successful compilation does not establish runtime support.

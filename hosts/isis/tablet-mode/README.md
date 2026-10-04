# Surface tablet mode

`../tablet-mode.nix` is imported only by `isis`. The primary user's graphical
session runs `surface-tablet-mode.service`; it discovers the Surface KIP switch
by its evdev name and `EV_SW/SW_TABLET_MODE` capability. It reads `EVIOCGSW` at
startup and after input wakeups, with periodic reconciliation for dropped events,
resume, Hyprland reloads and DMS restarts. Keyboard presence is never consulted.

The watcher changes the running Lua-configured compositor using `hyprctl eval`.
Scrolling defaults are part of Home Manager's existing `hl.config` output, not
the synchronized `hypr/dms` directory. The normal layout is captured from the
running configuration; the declarative layout (or `dwindle`) is the fallback if
the watcher starts while a previous scrolling override is still active.

## DMS RUNTIME OVERRIDE

`patch-dms.py` strictly patches the pinned DMS QML at package-build time. The
upstream Go binary and Qt dependencies are reused. The patch introduces:

```sh
dms ipc call surfaceTablet set true
dms ipc call surfaceTablet set false
dms ipc call surfaceTablet status
```

Tablet mode forces dock visibility, disables dock auto-hide and sets bar inner
padding to at least 20 (roughly a 62-pixel bar with the current theme). For the
current DankIsland bar, compact/reserved thickness is at least 56/64 pixels. Saved
preferences remain the underlying laptop-mode values. Runtime properties are
absent from `SettingsSpec`, so neither an unrelated settings save nor settings
reload serializes them. No tablet-specific state or plugin is installed in the
Syncthing folders. An upstream QML change that invalidates the patch fails the
build rather than silently omitting an override.

## KEYBOARD AND FUTURE GESTURES

`surface-tablet-osk.service` has no login enablement. The watcher starts it only
in tablet mode, with wvkbd 0.20 from the already-pinned unstable input, using
`--auto --hidden`. Visibility follows Wayland text-input requests; applications
that do not issue those requests will not summon the keyboard. Laptop mode
removes its runtime activation marker and stops the service.

The package includes upstream PR 126's `--auto` re-entrancy fix: Wayland
round-trips during `show()` can otherwise create multiple orphaned keyboard
surfaces when moving between text-input clients. A second patch commits
input-method activation on `done` and applies visibility outside the Wayland
callbacks, so focus handoff cannot leave a stale hide request. Heights are
300 logical pixels in landscape and 360 in portrait, configured through the
service environment.

Hardware discovery and `Session.apply` are separate. Future touchscreen gesture
services can follow that session policy without adding hardware detection to
Hyprland Lua. No gestures are configured yet.

Inspect operation with:

```sh
systemctl --user status surface-tablet-mode.service surface-tablet-osk.service
journalctl --user --unit=surface-tablet-mode.service --follow
```

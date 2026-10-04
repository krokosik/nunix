"""Host-local, strict QML patch: never mutate serialized DMS preferences."""

import pathlib
import sys


root = pathlib.Path(sys.argv[1])


def replace(path, old, new, count=1):
    file = root / path
    source = file.read_text()
    actual = source.count(old)
    if actual != count:
        raise RuntimeError(f"DMS patch drift: {path}: {old!r}: {actual} != {count}")
    file.write_text(source.replace(old, new))


# SettingsStore serializes only SettingsSpec keys. These runtime properties
# are intentionally absent from that spec, and are not reset on settings reload.
replace("Common/SettingsData.qml", "    property bool showDock: false", """    property bool tabletModeEnabled: false
    readonly property bool effectiveShowDock: tabletModeEnabled || showDock
    readonly property bool effectiveDockAutoHide: !tabletModeEnabled && dockAutoHide
    readonly property bool effectiveDockSmartAutoHide: !tabletModeEnabled && dockSmartAutoHide
    readonly property real effectiveFrameBarSize: tabletModeEnabled ? Math.max(64, frameBarSize) : frameBarSize

    function effectiveBarPadding(padding) {
        return tabletModeEnabled ? Math.max(20, padding ?? 4) : (padding ?? 4);
    }

    property bool showDock: false""")

replace("DMSShellIPC.qml", '        target: "dock"\n    }', '''        target: "dock"
    }

    IpcHandler {
        target: "surfaceTablet"

        function set(enabled: string): string {
            if (enabled !== "true" && enabled !== "false")
                return "TABLET_INVALID_VALUE";
            SettingsData.tabletModeEnabled = enabled === "true";
            return "TABLET_SET_SUCCESS";
        }

        function status(): string {
            return SettingsData.tabletModeEnabled ? "true" : "false";
        }
    }''')

# Patch render/geometry consumers, not settings editors or persistent IPC.
for path, count in {
    "Modules/Dock/Dock.qml": 2,
    "Modules/Dock/DockBody.qml": 2,
    "Widgets/DankOSD.qml": 2,
    "Modals/Common/DankModalConnected.qml": 1,
    "Modals/DankLauncherV2/DankLauncherV2ModalConnected.qml": 2,
    "Modules/Frame/FrameWindow.qml": 1,
}.items():
    replace(path, "SettingsData.showDock", "SettingsData.effectiveShowDock", count)

for path, auto, smart in [
    ("Modules/Dock/DockBody.qml", 1, 3),
    ("Widgets/DankOSD.qml", 1, 1),
]:
    replace(path, "SettingsData.dockAutoHide", "SettingsData.effectiveDockAutoHide", auto)
    replace(path, "SettingsData.dockSmartAutoHide", "SettingsData.effectiveDockSmartAutoHide", smart)

# Shared sizing helpers cover bar windows, popups and edge reservations.
replace("Common/Theme.qml", "    function barWidgetThickness(innerPadding, dpr) {", """    function barWidgetThickness(innerPadding, dpr) {
        innerPadding = SettingsData.effectiveBarPadding(innerPadding);""")
replace("Common/Theme.qml", "    function barThickness(innerPadding, dpr) {", """    function barThickness(innerPadding, dpr) {
        innerPadding = SettingsData.effectiveBarPadding(innerPadding);""")
replace("Modules/DankBar/DankBarContent.qml", "barConfig?.innerPadding ?? 4", "SettingsData.effectiveBarPadding(barConfig?.innerPadding)")

# The synchronized configuration currently renders its bar as a DankIsland.
# Override its compact and reserved thickness too, without changing barConfigs.
replace("Common/SettingsData.qml", """        const value = bc?.[key];
        return value === undefined || value === null ? islandDefaults[key] : value;""", """        const value = bc?.[key] ?? islandDefaults[key];
        if (tabletModeEnabled && key === "islandCompactThickness")
            return Math.max(32, value);
        if (tabletModeEnabled && key === "islandReserveThickness")
            return Math.max(40, value);
        return value;""")

for path, count in {
    "Modules/DankBar/DankBarBody.qml": 1,
}.items():
    replace(path, "SettingsData.frameBarSize", "SettingsData.effectiveFrameBarSize", count)

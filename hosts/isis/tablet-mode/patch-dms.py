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


# SettingsStore serializes only SettingsSpec keys. Keep runtime overrides out
# of dockConfigs and barConfigs so saving or syncing settings cannot persist them.
replace("Common/SettingsData.qml", "    property var dockConfigs: Spec.SPEC.dockConfigs.def", """    property bool tabletModeEnabled: false
    readonly property real effectiveFrameBarSize: tabletModeEnabled ? Math.max(64, frameBarSize) : frameBarSize
    readonly property var effectiveDockConfigs: dockConfigs.map(config => effectiveDockConfig(config))

    function effectiveDockConfig(config) {
        if (!tabletModeEnabled || !config)
            return config;
        return Object.assign({}, config, {enabled: true, autoHide: false, smartAutoHide: false});
    }

    function effectiveBarPadding(padding) {
        return tabletModeEnabled ? Math.max(20, padding ?? 2) : (padding ?? 2);
    }

    function effectiveIslandSettings(bc) {
        const settings = islandSettings(bc);
        if (!tabletModeEnabled)
            return settings;
        const defaults = islandDefaultsFor(bc);
        return Object.assign({}, settings, {
            islandCompactThickness: Math.max(32, settings.islandCompactThickness ?? defaults.islandCompactThickness),
            islandReserveThickness: Math.max(40, settings.islandReserveThickness ?? defaults.islandReserveThickness)
        });
    }

    property var dockConfigs: Spec.SPEC.dockConfigs.def""")

replace("DMSShellIPC.qml", '    IpcHandler {\n        target: "dock"', '''    IpcHandler {
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
    }

    IpcHandler {
        target: "dock"''')

# Resolve screen assignments and space reservations from runtime dock copies.
# Persistent getters/setters and the settings editors still use the saved values.
replace("Common/SettingsData.qml", "DockConfig.resolveAll(dockConfigs, screen,", "DockConfig.resolveAll(effectiveDockConfigs, screen,")
replace("Modules/Dock/Dock.qml", "SettingsData.getDockConfig(identity[1])", "SettingsData.effectiveDockConfig(SettingsData.getDockConfig(identity[1]))")

# Shared sizing helpers cover bar windows, popups and edge reservations.
for function in ["barWidgetThickness", "barThickness"]:
    old = f"    function {function}(innerPadding, dpr) {{"
    replace("Common/Theme.qml", old, old + "\n        innerPadding = SettingsData.effectiveBarPadding(innerPadding);")
replace("Modules/DBar/DBarContent.qml", "readonly property real innerPadding: barConfig?.innerPadding ?? 2", "readonly property real innerPadding: SettingsData.effectiveBarPadding(barConfig?.innerPadding)")
for path, count in {
    "Common/ShellLayout.qml": 1,
    "Modules/DBar/DBarBody.qml": 1,
    "Modules/DBar/DBarContent.qml": 1,
}.items():
    replace(path, "SettingsData.frameBarSize", "SettingsData.effectiveFrameBarSize", count)

# Island rendering and the layout resolver must agree about reserved thickness.
replace("Common/SettingsData.qml", "const value = islandSettings(bc)[key];", "const value = effectiveIslandSettings(bc)[key];")
for function in ["islandThickness", "islandReserve"]:
    replace("Common/SettingsData.qml", f"LayoutResolver.{function}(islandSettings(bc),", f"LayoutResolver.{function}(effectiveIslandSettings(bc),")
    replace("Common/ShellLayout.qml", f"Resolver.{function}(SettingsData.islandSettings(config),", f"Resolver.{function}(SettingsData.effectiveIslandSettings(config),")
replace("Modules/DIsland/IslandBarHost.qml", "Resolver.islandMetrics(SettingsData.islandSettings(root.barConfig),", "Resolver.islandMetrics(SettingsData.effectiveIslandSettings(root.barConfig),")

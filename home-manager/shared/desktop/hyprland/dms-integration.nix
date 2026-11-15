{ config, lib, ... }:
let
  inherit (lib.generators) toLua;
  inherit (lib.lists) head unique;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatMapStrings concatMapStringsSep;
  inherit (lib.types) attrs listOf;

  luaValue = toLua { multiline = false; };
  renderBinding = { _args, ... }: "hl.bind(${concatMapStringsSep ", " luaValue _args})\n";
in
{
  options.desktop.hyprland = {
    bindings = mkOption {
      type = listOf attrs;
      default = [ ];
      description = "Declarative Lua bindings applied after DMS bindings and user overrides.";
    };
    windowRules = mkOption {
      type = listOf attrs;
      default = [ ];
      description = "Declarative window rules applied after DMS window rules.";
    };
  };

  config.xdg.configFile = {
    "hypr/nunix/binds.lua".text =
      # Clear each key once so paired press/release actions stay registered.
      concatMapStrings (key: "hl.unbind(${luaValue key})\n") (
        unique (map ({ _args, ... }: head _args) config.desktop.hyprland.bindings)
      )
      + concatMapStrings renderBinding config.desktop.hyprland.bindings;

    "hypr/nunix/windowrules.lua".text = concatMapStrings (
      rule: "hl.window_rule(${luaValue rule})\n"
    ) config.desktop.hyprland.windowRules;
  };
}

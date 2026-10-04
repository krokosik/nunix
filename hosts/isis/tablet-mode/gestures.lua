-- SURFACE TOUCHSCREEN GESTURES
-- The evdev watcher supplies mode; Lua does not detect hardware.
surfaceTabletGestures = { enabled = nil, registered = false }
local state = surfaceTabletGestures
local normalGrabArea = hl.get_config("general.extend_border_grab_area")

local function tabletAction(action)
    return function()
        if state.enabled then
            action()
        end
    end
end

local function fullscreen()
    local window = hl.get_active_window()
    if window then
        hl.dispatch(hl.dsp.window.fullscreen({
            window = window,
            mode = "fullscreen",
            action = "toggle",
            layout_aware = true,
        }))
    end
end

local continuous = {
    { pattern = { kind = "swipe", fingers = 3, direction = "horizontal" }, action = "scroll_move" },
    { pattern = { kind = "swipe", fingers = 4, direction = "horizontal" }, action = "workspace" },
    { pattern = { kind = "swipe", fingers = 3, direction = "up" }, action = tabletAction(fullscreen) },
    { pattern = { kind = "swipe", fingers = 4, direction = "down" }, action = "close" },
}

local function registerBinds(hg)
    hg.bind({
        pattern = { kind = "tap", fingers = 3 },
        action = tabletAction(function()
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        end),
    })
    hg.bind({
        pattern = { kind = "tap", fingers = 4 },
        action = tabletAction(function()
            hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
        end),
    })
    hg.bind({
        pattern = { kind = "longpress", fingers = 3 },
        action = tabletAction(function()
            if hl.get_config("general.layout") == "scrolling" then
                hl.dispatch(hl.dsp.layout("center"))
            end
        end),
    })
    hg.bind({
        pattern = { kind = "longpress", fingers = 2 },
        mouse = true,
        action = tabletAction(function()
            local window = hl.get_active_window()
            if window and window.floating and window.fullscreen == 0 then
                -- Hyprgrass supplies press/release state to this mouse dispatcher.
                hl.dispatch(hl.dsp.window.drag())
            end
        end),
    })
end

function state.set_enabled(enabled)
    local hg = hl.plugin.hyprgrass
    if not hg then
        return
    end
    if not state.registered then
        registerBinds(hg)
        state.registered = true
    end
    if state.enabled == enabled then
        return
    end

    local wasEnabled = state.enabled
    hl.config({
        general = { extend_border_grab_area = enabled and 24 or normalGrabArea },
        gestures = {
            scrolling = { move_snap_to_grid = true, move_snap_cursor = false },
        },
        plugin = {
            hyprgrass = {
                sensitivity = 4.0,
                long_press_delay = 500,
                resize_on_border_long_press = enabled,
            },
        },
    })

    -- Native live actions are installed only in tablet mode. Completed binds
    -- stay registered and consult state.enabled; reload clears both registries.
    for _, gesture in ipairs(continuous) do
        if enabled then
            hg.gesture(gesture)
        elseif wasEnabled then
            hg.gesture({ pattern = gesture.pattern, action = "unset" })
        end
    end
    state.enabled = enabled
end

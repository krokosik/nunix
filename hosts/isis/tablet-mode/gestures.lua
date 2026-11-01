-- SURFACE TOUCHSCREEN GESTURES
-- All touch gestures stay available regardless of the hardware tablet switch.
surfaceTabletGestures = { registered = false }
local state = surfaceTabletGestures

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

function state.ensure_registered()
    local hg = hl.plugin.hyprgrass
    if not hg or state.registered then
        return
    end

    hl.config({
        general = { extend_border_grab_area = 24 },
        gestures = {
            workspace_swipe_touch = true,
            workspace_swipe_cancel_ratio = 0.05,
        },
        plugin = {
            hyprgrass = {
                -- Sensitivity also divides the allowed finger drift.
                sensitivity = 2.0,
                long_press_delay = 500,
                resize_on_border_long_press = true,
            },
        },
    })

    hg.gesture({
        pattern = { kind = "swipe", fingers = 4, direction = "horizontal" },
        scale = 2.0,
        action = "workspace",
    })
    hg.gesture({
        pattern = { kind = "swipe", fingers = 3, direction = "up" },
        action = fullscreen,
    })
    hg.bind({
        pattern = { kind = "longpress", fingers = 4 },
        action = function()
            hl.dispatch(hl.dsp.window.close())
        end,
    })
    hg.bind({
        pattern = { kind = "tap", fingers = 3 },
        action = function()
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        end,
    })
    hg.bind({
        pattern = { kind = "tap", fingers = 4 },
        action = function()
            hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
        end,
    })
    hg.bind({
        pattern = { kind = "longpress", fingers = 3 },
        action = function()
            if hl.get_config("general.layout") == "scrolling" then
                hl.dispatch(hl.dsp.layout("center"))
            end
        end,
    })
    hg.bind({
        pattern = { kind = "longpress", fingers = 2 },
        mouse = true,
        action = function()
            local window = hl.get_active_window()
            if window and window.floating and window.fullscreen == 0 then
                -- Hyprgrass supplies press/release state to this mouse dispatcher.
                hl.dispatch(hl.dsp.window.drag())
            end
        end,
    })
    state.registered = true
end

-- The watcher retries if the plugin has not loaded yet or config is reloaded.
state.ensure_registered()

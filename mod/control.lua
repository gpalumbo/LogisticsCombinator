-- Mission Control Mod - Control Phase
-- Main control script that coordinates all runtime behavior

-- Import utility libraries (stateless)
local signal_utils = require("lib.signal_utils")
local circuit_utils = require("lib.circuit_utils")
local platform_utils = require("lib.platform_utils")
local logistics_utils = require("lib.logistics_utils")
local gui_utils = require("lib.gui_utils")
-- Note: validation.lua is deprecated in favor of tile_buildability_rules

-- Import script modules (stateful)
local globals = require("scripts.globals")

-- Import logistics combinator modules
local logistics_combinator = require("scripts.logistics_combinator.logistics_combinator")
local logistics_combinator_control = require("scripts.logistics_combinator.control")
local logistics_combinator_gui = require("scripts.logistics_combinator.gui")

-- Import logistics chooser combinator modules
local logistics_chooser_control = require("scripts.logistics_chooser_combinator.control")
local logistics_chooser_gui = require("scripts.logistics_chooser_combinator.gui")

-- TODO: Import when implemented
-- local mission_control = require("scripts.mission_control.mission_control")
-- local mission_control_control = require("scripts.mission_control.control")
-- local mission_control_gui = require("scripts.mission_control.gui")
-- local receiver_combinator = require("scripts.receiver_combinator.receiver_combinator")
-- local receiver_combinator_control = require("scripts.receiver_combinator.control")
-- local receiver_combinator_gui = require("scripts.receiver_combinator.gui")
-- local network_manager = require("scripts.network_manager")

-- Initialize global state
script.on_init(function()
    globals.init_globals()
    logistics_combinator_control.on_init()
    logistics_chooser_control.on_init()
    -- TODO: Initialize other modules
    -- mission_control_control.on_init()
    -- receiver_combinator_control.on_init()
    -- network_manager.on_init()
end)

-- Handle configuration changes (mod updates, etc.)
script.on_configuration_changed(function(event)
    globals.init_globals()  -- Ensure globals are properly structured
    logistics_combinator_control.on_configuration_changed()
    logistics_chooser_control.on_configuration_changed()
    -- TODO: Handle configuration changes for other modules
    -- mission_control_control.on_configuration_changed()
    -- receiver_combinator_control.on_configuration_changed()
    -- network_manager.on_configuration_changed()
end)

-- Register all event handlers
-- Note: Entity lifecycle events are registered per-module (they filter by entity name internally)
logistics_combinator_control.register_events()
logistics_chooser_control.register_events()

-- Helper function to determine which GUI module to route to based on context
local function get_gui_module_for_event(event)
    -- For on_gui_opened, check the entity type
    if event.entity and event.entity.valid then
        if event.entity.name == "logistics-combinator" then
            return logistics_combinator_gui
        elseif event.entity.name == "logistics-chooser-combinator" then
            return logistics_chooser_gui
        end
    end

    -- For other events, check player's GUI state
    if event.player_index then
        local gui_state = globals.get_player_gui_state(event.player_index)
        if gui_state and gui_state.gui_type then
            if gui_state.gui_type == "logistics_combinator" then
                return logistics_combinator_gui
            elseif gui_state.gui_type == "logistics_chooser" then
                return logistics_chooser_gui
            end
        end
    end

    return nil
end

-- Override GUI event handlers with dispatchers that route based on entity type or GUI state
-- This is necessary because multiple script.on_event calls for the same event will overwrite each other
script.on_event(defines.events.on_gui_opened, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_opened then
        gui_module.on_gui_opened(event)
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_closed then
        gui_module.on_gui_closed(event)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_click then
        gui_module.on_gui_click(event)
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_elem_changed then
        gui_module.on_gui_elem_changed(event)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_text_changed then
        gui_module.on_gui_text_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_selection_state_changed then
        gui_module.on_gui_selection_state_changed(event)
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_checked_state_changed then
        gui_module.on_gui_checked_state_changed(event)
    end
end)

script.on_event(defines.events.on_gui_switch_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_switch_state_changed then
        gui_module.on_gui_switch_state_changed(event)
    end
end)

-- TODO: Register events for other modules
-- mission_control_control.register_events()
-- receiver_combinator_control.register_events()
-- network_manager.register_events()

-- Register custom input handler for pipette tool on GUI signal buttons
log("Attempting to register custom input handler: logistics-combinator-pipette-signal")

-- Try-catch to see if the event registration fails
local success, err = pcall(function()
  script.on_event("logistics-combinator-pipette-signal", function(event)
    log("Custom input triggered! Element: " .. tostring(event.element))

    -- Check if hovering over a signal sprite-button with signal data
    if event.element and event.element.tags and event.element.tags.signal_sel then
      local signal_id = event.element.tags.signal_sel
      local player = game.get_player(event.player_index)

      if not player then
        log("No player found")
        return
      end

      log("Signal type: " .. tostring(signal_id.type) .. ", name: " .. tostring(signal_id.name))
      local signal_type = signal_id.type or "item"

      -- Convert signal_id to PipetteID format
      local pipette_id = signal_utils.signal_to_pipette_prototype(signal_id)

      if pipette_id then
        log("Attempting pipette for: " .. signal_id.name .. " (type: " .. signal_type .. ", quality: " .. tostring(signal_id.quality) .. ")")

        -- Try pipette with error handling
        local pipette_success, pipette_err = pcall(function()
          local result = player.pipette(pipette_id, signal_id.quality, true);
          log("Pipette result: " .. tostring(result))
          return result
        end)

        if not pipette_success then
          log("ERROR during pipette: " .. tostring(pipette_err))
        end
      else
        log("Skipping non-pipettable signal: " .. tostring(signal_type))
      end
    else
      log("No element or no signal_sel tag found")
    end
  end)
end)

if success then
  log("Custom input handler registered successfully")
else
  log("ERROR registering custom input handler: " .. tostring(err))
end

-- Main update cycles
-- These are registered within their respective control modules
-- - 15-tick update for signal transmission (network_manager)
-- - 15-tick update for logistics combinator processing
-- - 60-tick update for platform connection status (network_manager)

-- Remote interface for debugging and mod integration (optional)
remote.add_interface("mission_control", {
    -- Get mod version
    get_version = function()
        return "0.1.0"
    end,

    -- Get logistics combinator status
    get_logistics_combinator_status = function(unit_number)
        return logistics_combinator.get_status(unit_number)
    end,

    -- TODO: Add more remote interface functions as needed
    -- get_mc_network_status = function(surface_index) ... end,
    -- get_receiver_status = function(unit_number) ... end,
})
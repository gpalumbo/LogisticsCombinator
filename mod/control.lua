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
    -- TODO: Initialize other modules
    -- mission_control_control.on_init()
    -- receiver_combinator_control.on_init()
    -- network_manager.on_init()
end)

-- Handle configuration changes (mod updates, etc.)
script.on_configuration_changed(function(event)
    globals.init_globals()  -- Ensure globals are properly structured
    logistics_combinator_control.on_configuration_changed()
    -- TODO: Handle configuration changes for other modules
    -- mission_control_control.on_configuration_changed()
    -- receiver_combinator_control.on_configuration_changed()
    -- network_manager.on_configuration_changed()
end)

-- Register all event handlers
logistics_combinator_control.register_events()
-- TODO: Register events for other modules
-- mission_control_control.register_events()
-- receiver_combinator_control.register_events()
-- network_manager.register_events()

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
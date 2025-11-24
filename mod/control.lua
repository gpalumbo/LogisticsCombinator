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
local migrations = require("scripts.migrations")

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
    -- Get version information
    local mod_changes = event.mod_changes and event.mod_changes["logistics-combinator"]
    local old_version = mod_changes and mod_changes.old_version
    local new_version = script.active_mods["logistics-combinator"]

    log("[Control] Configuration changed: " .. tostring(old_version) .. " -> " .. tostring(new_version))

    -- Run data migrations FIRST (before init_globals to preserve data)
    migrations.run_migrations(old_version, new_version)

    -- Then ensure globals are properly structured (adds missing tables, doesn't overwrite)
    globals.init_globals()

    -- Then run module-specific migrations
    logistics_combinator_control.on_configuration_changed()
    logistics_chooser_control.on_configuration_changed()
    -- TODO: Handle configuration changes for other modules
    -- mission_control_control.on_configuration_changed()
    -- receiver_combinator_control.on_configuration_changed()
    -- network_manager.on_configuration_changed()

    log("[Control] Configuration change complete")
end)

-- Helper function to route entity lifecycle events based on entity name
local function get_control_module_for_entity(entity)
    if not entity or not entity.valid then
        return nil
    end

    local entity_name = entity.name
    -- Handle ghosts - check ghost_name
    if entity.type == "entity-ghost" then
        entity_name = entity.ghost_name
    end

    if entity_name == "logistics-combinator" then
        return logistics_combinator_control
    elseif entity_name == "logistics-chooser-combinator" then
        return logistics_chooser_control
    end

    return nil
end

-- Helper function to determine which GUI module to route to based on context
local function get_gui_module_for_event(event)
    -- For on_gui_opened, check the entity type
    if event.entity and event.entity.valid then
        if event.entity.name == "logistics-combinator" or (event.entity.type == "entity-ghost" and event.entity.ghost_name == "logistics-combinator") then
            return logistics_combinator_gui
        elseif event.entity.name == "logistics-chooser-combinator" or (event.entity.type == "entity-ghost" and event.entity.ghost_name == "logistics-chooser-combinator") then
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

--------------------------------------------------------------------------------
-- CENTRALIZED ENTITY LIFECYCLE EVENT REGISTRATION
-- All entity lifecycle events are registered here and routed to appropriate modules
-- This prevents the last-registration-wins problem when multiple modules register the same event
--------------------------------------------------------------------------------

-- Entity built events
script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity or event.entity
    if not entity or not entity.valid then return end

    local control_module = get_control_module_for_entity(entity)
    if control_module and control_module.on_built then
        control_module.on_built(entity, game.players[event.player_index], event.tags)
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    local control_module = get_control_module_for_entity(entity)
    if control_module and control_module.on_built then
        control_module.on_built(entity, nil, event.tags)
    end
end)

script.on_event(defines.events.on_space_platform_built_entity, function(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    local control_module = get_control_module_for_entity(entity)
    if control_module and control_module.on_built then
        control_module.on_built(entity, nil, event.tags)
    end
end)

script.on_event(defines.events.script_raised_built, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_built then
        control_module.on_built(event.entity, nil, event.tags)
    end
end)

script.on_event(defines.events.script_raised_revive, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_built then
        control_module.on_built(event.entity, nil, event.tags)
    end
end)

-- Entity removed events
script.on_event(defines.events.on_player_mined_entity, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_removed then
        control_module.on_removed(event.entity)
    end
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_removed then
        control_module.on_removed(event.entity)
    end
end)

script.on_event(defines.events.on_space_platform_mined_entity, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_removed then
        control_module.on_removed(event.entity)
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_removed then
        control_module.on_removed(event.entity)
    end
end)

script.on_event(defines.events.script_raised_destroy, function(event)
    if not event.entity or not event.entity.valid then return end

    local control_module = get_control_module_for_entity(event.entity)
    if control_module and control_module.on_removed then
        control_module.on_removed(event.entity)
    end
end)

-- Register module-specific event handlers (periodic ticks, etc.)
-- Entity lifecycle events are handled above to avoid last-registration-wins problem
logistics_combinator_control.register_events()
logistics_chooser_control.register_events()

--------------------------------------------------------------------------------
-- GUI EVENT REGISTRATION
-- Override GUI event handlers with dispatchers that route based on entity type or GUI state
-- This is necessary because multiple script.on_event calls for the same event will overwrite each other
--------------------------------------------------------------------------------

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

-- Blueprint support: Store configuration in blueprint tags
script.on_event(defines.events.on_player_setup_blueprint, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    log("[Blueprint] on_player_setup_blueprint triggered for player " .. player.name)

    -- Get blueprint (prefer blueprint_to_setup for this event)
    local blueprint = player.blueprint_to_setup
    if not blueprint or not blueprint.valid_for_read then
        blueprint = player.cursor_stack
        if not blueprint or not blueprint.valid_for_read or not blueprint.is_blueprint then
            log("[Blueprint] No valid blueprint found")
            return
        end
    end

    -- Get the mapping (CRITICAL: provides blueprint_index -> real_entity mapping)
    local mapping = event.mapping.get()
    if not mapping then
        log("[Blueprint] Warning: mapping is nil")
        return
    end

    -- Count entities
    local entity_count = 0
    for _ in pairs(mapping) do entity_count = entity_count + 1 end
    log("[Blueprint] Processing " .. entity_count .. " entities")

    -- Iterate through mapped entities
    local chooser_count = 0
    for blueprint_index, real_entity in pairs(mapping) do
        if not real_entity.valid then
            goto continue
        end

        -- Handle logistics chooser combinator
        if real_entity.name == "logistics-chooser-combinator" then
            local config = globals.serialize_chooser_config(real_entity.unit_number)
            if config then
                blueprint.set_blueprint_entity_tag(blueprint_index, "chooser_config", config)
                chooser_count = chooser_count + 1
                log("[Blueprint] Saved config for chooser #" .. blueprint_index .. " with " .. #(config.groups or {}) .. " groups")
            else
                log("[Blueprint] Warning: No config found for chooser unit_number " .. real_entity.unit_number)
            end
        end

        -- Handle logistics combinator
        if real_entity.name == "logistics-combinator" then
            local config = globals.serialize_combinator_config(real_entity.unit_number)
            if config then
                blueprint.set_blueprint_entity_tag(blueprint_index, "combinator_config", config)
                log("[Blueprint] Saved config for logistics combinator #" .. blueprint_index .. " with " .. #(config.conditions or {}) .. " conditions")
            else
                log("[Blueprint] Warning: No config found for logistics combinator unit_number " .. real_entity.unit_number)
            end
        end

        ::continue::
    end

    log("[Blueprint] Saved configuration for " .. chooser_count .. " chooser combinators")
end)

-- Copy-paste support: Copy configuration from source to target
script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid or not destination or not destination.valid then return end

    -- Handle logistics chooser combinator copy-paste
    if source.name == "logistics-chooser-combinator" and destination.name == "logistics-chooser-combinator" then
        log("[Copy-Paste] Copying configuration from source unit_number " .. source.unit_number .. " to destination unit_number " .. destination.unit_number)

        local source_config = globals.serialize_chooser_config(source.unit_number)
        if source_config then
            log("[Copy-Paste] Source has " .. #(source_config.groups or {}) .. " groups, mode: " .. (source_config.mode or "each"))
            globals.restore_chooser_config(destination, source_config)
            log("[Copy-Paste] Configuration copied successfully")
        else
            log("[Copy-Paste] Warning: No configuration found in source entity")
        end
    end

    -- Handle logistics combinator copy-paste
    if source.name == "logistics-combinator" and destination.name == "logistics-combinator" then
        log("[Copy-Paste] Copying configuration from source unit_number " .. source.unit_number .. " to destination unit_number " .. destination.unit_number)

        local source_config = globals.serialize_combinator_config(source.unit_number)
        if source_config then
            log("[Copy-Paste] Source has " .. #(source_config.conditions or {}) .. " conditions, " .. #(source_config.logistics_sections or {}) .. " sections")
            globals.restore_combinator_config(destination, source_config)
            log("[Copy-Paste] Configuration copied successfully")
        else
            log("[Copy-Paste] Warning: No configuration found in source entity")
        end
    end
end)

-- Entity cloning support: Copy configuration when entity is cloned (editor, mods, etc.)
script.on_event(defines.events.on_entity_cloned, function(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid or not destination or not destination.valid then return end

    -- Handle logistics chooser combinator cloning
    if source.name == "logistics-chooser-combinator" and destination.name == "logistics-chooser-combinator" then
        log("[Clone] Cloning configuration from source unit_number " .. source.unit_number .. " to destination unit_number " .. destination.unit_number)

        -- Serialize source configuration
        local source_config = globals.serialize_chooser_config(source.unit_number)

        if source_config then
            log("[Clone] Source has " .. #(source_config.groups or {}) .. " groups, mode: " .. (source_config.mode or "each"))

            -- Register destination entity first (cloning creates new entity)
            globals.register_logistics_chooser(destination)

            -- Restore configuration to destination
            globals.restore_chooser_config(destination, source_config)
            log("[Clone] Configuration cloned successfully")
        else
            log("[Clone] Warning: No configuration found in source entity, registering empty destination")
            -- Still register the entity even if source has no config
            globals.register_logistics_chooser(destination)
        end
    end

    -- Handle logistics combinator cloning
    if source.name == "logistics-combinator" and destination.name == "logistics-combinator" then
        log("[Clone] Cloning configuration from source unit_number " .. source.unit_number .. " to destination unit_number " .. destination.unit_number)

        -- Serialize source configuration
        local source_config = globals.serialize_combinator_config(source.unit_number)

        if source_config then
            log("[Clone] Source has " .. #(source_config.conditions or {}) .. " conditions, " .. #(source_config.logistics_sections or {}) .. " sections")

            -- Register destination entity first (cloning creates new entity)
            globals.register_logistics_combinator(destination)

            -- Restore configuration to destination
            globals.restore_combinator_config(destination, source_config)
            log("[Clone] Configuration cloned successfully")
        else
            log("[Clone] Warning: No configuration found in source entity, registering empty destination")
            -- Still register the entity even if source has no config
            globals.register_logistics_combinator(destination)
        end
    end
end)

-- TODO: Register events for other modules
-- mission_control_control.register_events()
-- receiver_combinator_control.register_events()
-- network_manager.register_events()

-- Register custom input handler for pipette tool on GUI signal buttons
log("Attempting to register custom input handler: logistics-combinator-pipette-signal")

-- -- Try-catch to see if the event registration fails
-- local success, err = pcall(function()
--   script.on_event("logistics-combinator-pipette-signal", function(event)
--     log("Custom input triggered! Element: " .. tostring(event.element))

--     -- Check if hovering over a signal sprite-button with signal data
--     if event.element and event.element.tags and event.element.tags.signal_sel then
--       local signal_id = event.element.tags.signal_sel
--       local player = game.get_player(event.player_index)

--       if not player then
--         log("No player found")
--         return
--       end

--       log("Signal type: " .. tostring(signal_id.type) .. ", name: " .. tostring(signal_id.name))
--       local signal_type = signal_id.type or "item"

--       -- Convert signal_id to PipetteID format
--       local pipette_id = signal_utils.signal_to_pipette_prototype(signal_id)

--       if pipette_id then
--         log("Attempting pipette for: " .. signal_id.name .. " (type: " .. signal_type .. ", quality: " .. tostring(signal_id.quality) .. ")")

--         -- Try pipette with error handling
--         local pipette_success, pipette_err = pcall(function()
--           local result = player.pipette(pipette_id, signal_id.quality, true);
--           log("Pipette result: " .. tostring(result))
--           return result
--         end)

--         if not pipette_success then
--           log("ERROR during pipette: " .. tostring(pipette_err))
--         end
--       else
--         log("Skipping non-pipettable signal: " .. tostring(signal_type))
--       end
--     else
--       log("No element or no signal_sel tag found")
--     end
--   end)
-- end)

-- if success then
--   log("Custom input handler registered successfully")
-- else
--   log("ERROR registering custom input handler: " .. tostring(err))
-- end

-- Main update cycles
-- These are registered within their respective control modules
-- - 15-tick update for signal transmission (network_manager)
-- - 15-tick update for logistics combinator processing
-- - 60-tick update for platform connection status (network_manager)

-- Remote interface for debugging and mod integration (optional)
remote.add_interface("mission_control", {
    -- Get mod version
    get_version = function()
        return "0.2.0"
    end,

    -- Get logistics combinator status
    get_logistics_combinator_status = function(unit_number)
        return logistics_combinator.get_status(unit_number)
    end,

    -- TODO: Add more remote interface functions as needed
    -- get_mc_network_status = function(surface_index) ... end,
    -- get_receiver_status = function(unit_number) ... end,
})
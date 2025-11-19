-- Mission Control Mod - Logistics Combinator Control
-- This module handles events for logistics combinators

local logistics_combinator = require("scripts.logistics_combinator.logistics_combinator")
local logistics_combinator_gui = require("scripts.logistics_combinator.gui")
local globals = require("scripts.globals")

local logistics_combinator_control = {}

--- Handle when a logistics combinator is built
--- @param entity LuaEntity The built entity
--- @param player LuaPlayer|nil The player who built it (nil for robots)
function logistics_combinator_control.on_built(entity, player)
    if not entity or not entity.valid or entity.name ~= "logistics-combinator" then
        return
    end

    -- TODO: Implement build handler
    -- 1. Register the combinator in globals
    -- 2. Initialize rule storage
    -- 3. Cache initial connected entities
    -- 4. Open GUI if built by player

    -- Register in globals
    globals.register_logistics_combinator(entity)

    -- Update connected entities
    logistics_combinator.update_connected_entities(entity.unit_number)

    -- Open GUI if built by player
    if player and player.valid then
        logistics_combinator_gui.create_gui(player, entity)
    end
end

--- Handle when a logistics combinator is removed
--- @param entity LuaEntity The removed entity
function logistics_combinator_control.on_removed(entity)
    if not entity or not entity.valid or entity.name ~= "logistics-combinator" then
        return
    end

    -- TODO: Implement removal handler
    -- 1. Clean up all injected groups
    -- 2. Remove from globals
    -- 3. Close any open GUIs

    local unit_number = entity.unit_number

    -- Cleanup injected groups
    logistics_combinator.cleanup_injected_groups(unit_number)

    -- Unregister from globals
    globals.unregister_logistics_combinator(unit_number)

    -- Close any open GUIs
    for _, player in pairs(game.players) do
        -- TODO: Check if player has this combinator's GUI open
        -- logistics_combinator_gui.close_if_entity(player, entity)
    end
end

--- Handle wire connection added
--- @param event EventData Wire added event
function logistics_combinator_control.on_wire_added(event)
    -- TODO: Implement wire connection handler
    -- Check if wire connected to a logistics combinator
    -- Update connected entities cache

    local entity = event.entity
    if entity and entity.valid and entity.name == "logistics-combinator" then
        logistics_combinator.update_connected_entities(entity.unit_number)
    end
end

--- Handle wire connection removed
--- @param event EventData Wire removed event
function logistics_combinator_control.on_wire_removed(event)
    -- TODO: Implement wire disconnection handler
    -- Check if wire disconnected from a logistics combinator
    -- Update connected entities cache
    -- May need to remove injected groups if entity no longer connected

    local entity = event.entity
    if entity and entity.valid and entity.name == "logistics-combinator" then
        logistics_combinator.update_connected_entities(entity.unit_number)
        -- TODO: Check if any entities lost connection and cleanup their injected groups
    end
end

--- Register all event handlers
function logistics_combinator_control.register_events()
    -- Entity lifecycle events
    script.on_event(defines.events.on_built_entity, function(event)
        logistics_combinator_control.on_built(event.created_entity, game.players[event.player_index])
    end)

    script.on_event(defines.events.on_robot_built_entity, function(event)
        logistics_combinator_control.on_built(event.created_entity, nil)
    end)

    script.on_event(defines.events.script_raised_built, function(event)
        logistics_combinator_control.on_built(event.entity, nil)
    end)

    script.on_event(defines.events.on_player_mined_entity, function(event)
        logistics_combinator_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.on_robot_mined_entity, function(event)
        logistics_combinator_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.on_entity_died, function(event)
        logistics_combinator_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.script_raised_destroy, function(event)
        logistics_combinator_control.on_removed(event.entity)
    end)

    -- Wire events don't exist in Factorio API - use polling instead
    -- Connection changes are detected by periodic polling in on_nth_tick(90)

    -- GUI events
    script.on_event(defines.events.on_gui_opened, logistics_combinator_gui.on_gui_opened)
    script.on_event(defines.events.on_gui_closed, logistics_combinator_gui.on_gui_closed)
    script.on_event(defines.events.on_gui_click, logistics_combinator_gui.on_gui_click)
    script.on_event(defines.events.on_gui_elem_changed, logistics_combinator_gui.on_gui_elem_changed)
    script.on_event(defines.events.on_gui_text_changed, logistics_combinator_gui.on_gui_text_changed)
    script.on_event(defines.events.on_gui_selection_state_changed, logistics_combinator_gui.on_gui_selection_state_changed)
    script.on_event(defines.events.on_gui_checked_state_changed, logistics_combinator_gui.on_gui_checked_state_changed)

    -- Periodic connection update (every 90 ticks = 1.5 seconds)
    -- Detects wire changes via polling (no native wire events available)
    script.on_nth_tick(90, function()
        if not storage.logistics_combinators then
            return
        end

        for unit_number, combinator_data in pairs(storage.logistics_combinators) do
            if combinator_data.entity and combinator_data.entity.valid then
                logistics_combinator.update_connected_entities(unit_number)
            end
        end
    end)

    -- Periodic condition processing (every 15 ticks = 250ms)
    -- Evaluates conditions and injects/removes logistics sections
    script.on_nth_tick(15, function()
        if not storage.logistics_combinators then
            return
        end

        logistics_combinator.process_all_combinators()
    end)
end

--- Initialize on mod load
function logistics_combinator_control.on_init()
    -- TODO: Any initialization needed
    -- Called from main control.lua on_init
end

--- Handle configuration changes
function logistics_combinator_control.on_configuration_changed()
    -- TODO: Handle mod version changes
    -- Called from main control.lua on_configuration_changed
end

return logistics_combinator_control
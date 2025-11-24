-- Mission Control Mod - Logistics Combinator Control
-- This module handles events for logistics combinators

local logistics_combinator = require("scripts.logistics_combinator.logistics_combinator")
local logistics_combinator_gui = require("scripts.logistics_combinator.gui")
local globals = require("scripts.globals")

local logistics_combinator_control = {}

--- Handle when a logistics combinator is built
--- @param entity LuaEntity The built entity
--- @param player LuaPlayer|nil The player who built it (nil for robots)
--- @param tags table|nil Blueprint tags (if built from blueprint)
function logistics_combinator_control.on_built(entity, player, tags)
    if not entity or not entity.valid then
        return
    end


    log("[Logistics Combinator Control] on_built triggered for unit_number " .. entity.unit_number .. " by " .. (player and player.name or "robot/script"))

    if not (entity.name == "logistics-combinator") then
        return
    end

    -- Register in globals
    globals.register_logistics_combinator(entity)

    -- Restore configuration from blueprint tags if available
    if tags and tags.combinator_config then
        log("[Logistics Combinator Control] Restoring configuration from tags: " .. #(tags.combinator_config.conditions or {}) .. " conditions, " .. #(tags.combinator_config.logistics_sections or {}) .. " sections")
        globals.restore_combinator_config(entity, tags.combinator_config)
    else
        log("[Logistics Combinator Control] No tags found, creating empty combinator")
    end

    -- Update connected entities for immediate feedback
    logistics_combinator.update_connected_entities(entity.unit_number)

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

--- Register module-specific event handlers (periodic ticks only)
--- Entity lifecycle events are registered centrally in control.lua to avoid last-registration-wins problem
function logistics_combinator_control.register_events()
    -- NOTE: Entity lifecycle events (on_built_entity, on_robot_built_entity, etc.)
    -- are registered centrally in control.lua and routed to on_built/on_removed
    -- This function only registers periodic tick events specific to this module

    -- Wire events don't exist in Factorio API - use polling instead
    -- Connection changes are detected by periodic polling in on_nth_tick(90)

    -- NOTE: GUI events are registered centrally in control.lua to avoid conflicts
    -- The central dispatcher routes events based on entity type and player GUI state

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
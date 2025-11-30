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

    if not (entity.name == "logistics-combinator") then
        return
    end

    -- Register in globals
    globals.register_logistics_combinator(entity)

    -- Restore configuration from blueprint tags if available
    if tags and tags.combinator_config then
        globals.restore_combinator_config(entity, tags.combinator_config)
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

--- Called every 90 ticks (1.5 seconds) to update wire connections
--- Wire events don't exist in Factorio API - use polling instead
function logistics_combinator_control.on_tick_90()
    if not storage.logistics_combinators then
        return
    end
    for unit_number, combinator_data in pairs(storage.logistics_combinators) do
        if combinator_data.entity and combinator_data.entity.valid then
            logistics_combinator.update_connected_entities(unit_number)
        end
    end
end

--- Called every 15 ticks (250ms) to process conditions and inject/remove logistics sections
function logistics_combinator_control.on_tick_15()
    if not storage.logistics_combinators then
        return
    end

    logistics_combinator.process_all_combinators()
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
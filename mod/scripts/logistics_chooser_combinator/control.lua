-- Mission Control Mod - Logistics Chooser Combinator Control
-- This module handles events for logistics chooser combinators

local logistics_chooser = require("scripts.logistics_chooser_combinator.logistics_chooser_combinator")
local logistics_chooser_gui = require("scripts.logistics_chooser_combinator.gui")
local globals = require("scripts.globals")

local logistics_chooser_control = {}

--- Handle when a logistics chooser combinator is built
--- @param entity LuaEntity The built entity
--- @param player LuaPlayer|nil The player who built it (nil for robots)
function logistics_chooser_control.on_built(entity, player)
    if not entity or not entity.valid or entity.name ~= "logistics-chooser-combinator" then
        return
    end

    -- Register in globals
    globals.register_logistics_chooser(entity)

    -- Update connected entities
    logistics_chooser.update_connected_entities(entity.unit_number)

    -- Open GUI if built by player
    if player and player.valid then
        logistics_chooser_gui.create_gui(player, entity)
    end
end

--- Handle when a logistics chooser combinator is removed
--- @param entity LuaEntity The removed entity
function logistics_chooser_control.on_removed(entity)
    if not entity or not entity.valid or entity.name ~= "logistics-chooser-combinator" then
        return
    end

    local unit_number = entity.unit_number

    -- Cleanup injected groups
    logistics_chooser.cleanup_injected_groups(unit_number)

    -- Unregister from globals
    globals.unregister_logistics_chooser(unit_number)

    -- Close any open GUIs
    for _, player in pairs(game.players) do
        local gui_state = globals.get_player_gui_state(player.index)
        if gui_state and gui_state.gui_type == "logistics_chooser" and gui_state.open_entity == unit_number then
            logistics_chooser_gui.close_gui(player)
        end
    end
end

--- Register all event handlers
function logistics_chooser_control.register_events()
    -- Entity lifecycle events
    script.on_event(defines.events.on_built_entity, function(event)
        logistics_chooser_control.on_built(event.created_entity, game.players[event.player_index])
    end)

    script.on_event(defines.events.on_robot_built_entity, function(event)
        logistics_chooser_control.on_built(event.created_entity, nil)
    end)

    script.on_event(defines.events.script_raised_built, function(event)
        logistics_chooser_control.on_built(event.entity, nil)
    end)

    script.on_event(defines.events.on_player_mined_entity, function(event)
        logistics_chooser_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.on_robot_mined_entity, function(event)
        logistics_chooser_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.on_entity_died, function(event)
        logistics_chooser_control.on_removed(event.entity)
    end)

    script.on_event(defines.events.script_raised_destroy, function(event)
        logistics_chooser_control.on_removed(event.entity)
    end)

    -- NOTE: GUI events are registered centrally in control.lua to avoid conflicts
    -- The central dispatcher routes events based on entity type and player GUI state

    -- Periodic connection update (every 90 ticks = 1.5 seconds)
    -- Detects wire changes via polling (no native wire events available)
    script.on_nth_tick(90, function()
        if not storage.logistics_choosers then
            return
        end

        for unit_number, chooser_data in pairs(storage.logistics_choosers) do
            if chooser_data.entity and chooser_data.entity.valid then
                logistics_chooser.update_connected_entities(unit_number)
            end
        end
    end)

    -- Periodic group processing (every 15 ticks = 250ms)
    -- Evaluates conditions and injects/removes logistics sections
    script.on_nth_tick(15, function()
        if not storage.logistics_choosers then
            return
        end

        logistics_chooser.process_all_choosers()
    end)
end

--- Initialize on mod load
function logistics_chooser_control.on_init()
    -- Any initialization needed
end

--- Handle configuration changes
function logistics_chooser_control.on_configuration_changed()
    -- Handle mod version changes
    -- Migrate old group format to new format with condition structure
    if storage.logistics_choosers then
        for unit_number, chooser_data in pairs(storage.logistics_choosers) do
            if chooser_data.groups then
                for i, group in ipairs(chooser_data.groups) do
                    -- Check if this is an old format group (no condition field)
                    if not group.condition then
                        -- Migrate from old format {group, signal, value} to new format
                        local old_signal = group.signal
                        local old_value = group.value or 0

                        -- Create new condition structure
                        group.condition = {
                            left_wire_filter = "both",
                            left_signal = old_signal,
                            operator = "=",
                            right_type = "constant",
                            right_value = old_value,
                            right_signal = nil,
                            right_wire_filter = "both"
                        }

                        -- Remove old fields if they exist
                        group.signal = nil
                        group.value = nil

                        -- Add new fields if missing
                        if group.multiplier == nil then
                            group.multiplier = 1.0
                        end
                        if group.is_active == nil then
                            group.is_active = false
                        end
                    else
                        -- Condition exists, but ensure wire_filter fields exist (added in later version)
                        if not group.condition.left_wire_filter then
                            group.condition.left_wire_filter = "both"
                        end
                        if not group.condition.right_wire_filter then
                            group.condition.right_wire_filter = "both"
                        end

                        -- Ensure multiplier and is_active exist
                        if group.multiplier == nil then
                            group.multiplier = 1.0
                        end
                        if group.is_active == nil then
                            group.is_active = false
                        end
                    end
                end
            end
        end
    end
end

return logistics_chooser_control

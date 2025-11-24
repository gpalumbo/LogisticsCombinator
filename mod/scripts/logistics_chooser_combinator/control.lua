-- Mission Control Mod - Logistics Chooser Combinator Control
-- This module handles events for logistics chooser combinators

local logistics_chooser = require("scripts.logistics_chooser_combinator.logistics_chooser_combinator")
local logistics_chooser_gui = require("scripts.logistics_chooser_combinator.gui")
local globals = require("scripts.globals")

local logistics_chooser_control = {}

--- Handle when a logistics chooser combinator is built
--- @param entity LuaEntity The built entity
--- @param player LuaPlayer|nil The player who built it (nil for robots)
--- @param tags table|nil Blueprint tags (if built from blueprint)
function logistics_chooser_control.on_built(entity, player, tags)
    if not entity or not entity.valid then
        return 
    end 
    if  not (entity.name == "logistics-chooser-combinator") then
        return
    end

    log("[Chooser Control] on_built triggered for unit_number " .. entity.unit_number .. " by " .. (player and player.name or "robot/script"))

    -- Register in globals
    globals.register_logistics_chooser(entity)

    -- Restore configuration from blueprint tags if available
    if tags and tags.chooser_config then
        log("[Chooser Control] Restoring configuration from tags: " .. #(tags.chooser_config.groups or {}) .. " groups, mode: " .. (tags.chooser_config.mode or "each"))
        globals.restore_chooser_config(entity, tags.chooser_config)
    else
        log("[Chooser Control] No tags found, creating empty chooser")
    end

    -- Update connected entities
    logistics_chooser.update_connected_entities(entity.unit_number)

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

--- Register module-specific event handlers (periodic ticks only)
--- Entity lifecycle events are registered centrally in control.lua to avoid last-registration-wins problem
function logistics_chooser_control.register_events()
    -- NOTE: Entity lifecycle events (on_built_entity, on_robot_built_entity, etc.)
    -- are registered centrally in control.lua and routed to on_built/on_removed
    -- This function only registers periodic tick events specific to this module

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
    -- Nothing to initialize for chooser control
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

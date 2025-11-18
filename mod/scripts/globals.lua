-- Mission Control Mod - Global State Management
-- This module manages all global state for the mod

local globals_module = {}

--- Initialize all storage tables (Factorio 2.0 API)
function globals_module.init_globals()
    -- Ensure storage table exists (Factorio 2.0: global renamed to storage)
    storage = storage or {}

    -- Mission Control networks indexed by surface
    storage.mc_networks = storage.mc_networks or {}
    --[[
    Structure:
    [surface_index] = {
        red_signals = {},
        green_signals = {},
        mc_entities = {}, -- unit_numbers
        last_update = game.tick
    }
    ]]

    -- Platform receivers
    storage.platform_receivers = storage.platform_receivers or {}
    --[[
    Structure:
    [platform_unit_number] = {
        configured_surfaces = {}, -- surface indices
        entity_unit_number = unit_number,
        last_connection = nil -- surface_index or nil
    }
    ]]

    -- Logistics combinator state
    storage.logistics_combinators = storage.logistics_combinators or {}
    --[[
    Structure:
    [combinator_unit_number] = {
        entity = entity_reference,  -- Note: Store unit_number only in production
        conditions = {  -- Array of complex conditions
            {
                logical_op = "AND"|"OR",  -- Combines with PREVIOUS condition
                left_signal = {type="item", name="iron-plate"},
                left_wire_filter = "red"|"green"|"both",
                operator = "<"|">"|"="|"≠"|"≤"|"≥",
                right_type = "constant"|"signal",
                right_value = 100,  -- If constant
                right_signal = {...},  -- If signal
                right_wire_filter = "red"|"green"|"both"
            }
        },
        condition_result = false,  -- Last evaluated boolean result
        last_condition_state = false,  -- Previous condition result for edge triggering
        logistics_sections = {  -- Sections to inject when condition is TRUE
            {
                group = "Space Platform Fuel",  -- Logistics group name
                multiplier = 1.0  -- Optional multiplier for group quantities
            }
        },
        connected_entities = {}, -- cached unit_numbers
        injected_tracking = {  -- Track what we injected per entity
            [entity_unit_number] = {
                section_indices = {}  -- Array of section indices we added
            }
        }
    }
    ]]

    -- Player GUI states
    storage.player_gui_states = storage.player_gui_states or {}
    --[[
    Structure:
    [player_index] = {
        open_entity = unit_number,
        gui_type = "logistics_combinator" | "receiver" | "mission_control"
    }
    ]]
end

--- Register a logistics combinator
--- @param entity LuaEntity The combinator entity
function globals_module.register_logistics_combinator(entity)
    if not entity or not entity.valid then return end

    -- Ensure storage is initialized
    if not storage.logistics_combinators then
        storage.logistics_combinators = {}
    end

    storage.logistics_combinators[entity.unit_number] = {
        entity = entity,  -- TODO: In production, store unit_number only
        conditions = {},  -- Complex condition array
        condition_result = false,  -- Last evaluated result
        last_condition_state = false,  -- Previous result for edge triggering
        logistics_sections = {},  -- Array of {group, multiplier} sections
        connected_entities = {},
        injected_tracking = {}  -- Track what we injected per entity
    }
end

--- Unregister a logistics combinator
--- @param unit_number number The combinator's unit number
function globals_module.unregister_logistics_combinator(unit_number)
    if not storage.logistics_combinators then
        return
    end

    storage.logistics_combinators[unit_number] = nil
end

--- Get logistics combinator data
--- @param unit_number number The combinator's unit number
--- @return table|nil Combinator data or nil if not found
function globals_module.get_logistics_combinator_data(unit_number)
    if not storage.logistics_combinators then
        return nil
    end

    return storage.logistics_combinators[unit_number]
end

--- Add a logistics section to a combinator
--- @param unit_number number The combinator's unit number
--- @param section table The section to add {group = "name", multiplier = 1.0}
function globals_module.add_logistics_section(unit_number, section)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        if not data.logistics_sections then
            data.logistics_sections = {}
        end
        table.insert(data.logistics_sections, section)
    end
end

--- Remove a logistics section from a combinator
--- @param unit_number number The combinator's unit number
--- @param section_index number Index of the section to remove
function globals_module.remove_logistics_section(unit_number, section_index)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.logistics_sections and data.logistics_sections[section_index] then
        table.remove(data.logistics_sections, section_index)
    end
end

--- Update a logistics section in a combinator
--- @param unit_number number The combinator's unit number
--- @param section_index number Index of the section to update
--- @param section table The new section data {group = "name", multiplier = 1.0}
function globals_module.update_logistics_section(unit_number, section_index, section)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.logistics_sections then
        data.logistics_sections[section_index] = section
    end
end

--- Get all logistics sections for a combinator
--- @param unit_number number The combinator's unit number
--- @return table Array of logistics sections
function globals_module.get_logistics_sections(unit_number)
    if not storage.logistics_combinators then
        return {}
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.logistics_sections then
        return data.logistics_sections
    end

    return {}
end

--- Track an injected section index
--- @param combinator_unit_number number The combinator that injected
--- @param entity_unit_number number The entity that received
--- @param section_index number The section index that was injected
function globals_module.track_injected_section(combinator_unit_number, entity_unit_number, section_index)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[combinator_unit_number]
    if data then
        if not data.injected_tracking then
            data.injected_tracking = {}
        end
        if not data.injected_tracking[entity_unit_number] then
            data.injected_tracking[entity_unit_number] = {section_indices = {}}
        end
        table.insert(data.injected_tracking[entity_unit_number].section_indices, section_index)
    end
end

--- Clear all injection tracking for a combinator
--- @param combinator_unit_number number The combinator
function globals_module.clear_injected_tracking(combinator_unit_number)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[combinator_unit_number]
    if data then
        data.injected_tracking = {}
    end
end

--- Get injection tracking for a combinator
--- @param combinator_unit_number number The combinator
--- @return table Tracking data
function globals_module.get_injected_tracking(combinator_unit_number)
    if not storage.logistics_combinators then
        return {}
    end

    local data = storage.logistics_combinators[combinator_unit_number]
    if data and data.injected_tracking then
        return data.injected_tracking
    end

    return {}
end

--- Set player GUI entity reference
--- @param player_index number
--- @param entity LuaEntity
--- @param gui_type string Type of GUI
function globals_module.set_player_gui_entity(player_index, entity, gui_type)
    -- Ensure storage is initialized
    if not storage.player_gui_states then
        storage.player_gui_states = {}
    end

    storage.player_gui_states[player_index] = {
        open_entity = entity.unit_number,
        gui_type = gui_type
    }
end

--- Clear player GUI entity reference
--- @param player_index number
function globals_module.clear_player_gui_entity(player_index)
    -- Ensure storage is initialized
    if not storage.player_gui_states then
        storage.player_gui_states = {}
        return
    end

    storage.player_gui_states[player_index] = nil
end

--- Get player GUI state
--- @param player_index number
--- @return table|nil GUI state or nil
function globals_module.get_player_gui_state(player_index)
    -- Ensure storage is initialized
    if not storage.player_gui_states then
        return nil
    end

    return storage.player_gui_states[player_index]
end

--- Add a condition to a logistics combinator
--- @param unit_number number The combinator's unit number
--- @param condition table The condition to add
function globals_module.add_logistics_condition(unit_number, condition)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        if not data.conditions then
            data.conditions = {}
        end
        table.insert(data.conditions, condition)
    end
end

--- Remove a condition from a logistics combinator
--- @param unit_number number The combinator's unit number
--- @param condition_index number Index of the condition to remove
function globals_module.remove_logistics_condition(unit_number, condition_index)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.conditions and data.conditions[condition_index] then
        table.remove(data.conditions, condition_index)
    end
end

--- Update a condition in a logistics combinator
--- @param unit_number number The combinator's unit number
--- @param condition_index number Index of the condition to update
--- @param condition table The new condition data
function globals_module.update_logistics_condition(unit_number, condition_index, condition)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.conditions then
        data.conditions[condition_index] = condition
        storage.logistics_combinators[unit_number] = data
    end
end

--- Get all conditions for a logistics combinator
--- @param unit_number number The combinator's unit number
--- @return table Array of conditions
function globals_module.get_logistics_conditions(unit_number)
    if not storage.logistics_combinators then
        return {}
    end

    local data = storage.logistics_combinators[unit_number]
    if data and data.conditions then
        return data.conditions
    end

    return {}
end

--- Set the condition evaluation result
--- @param unit_number number The combinator's unit number
--- @param result boolean The evaluation result
function globals_module.set_condition_result(unit_number, result)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        data.condition_result = result
    end
end

--- Get the condition evaluation result
--- @param unit_number number The combinator's unit number
--- @return boolean The last evaluation result
function globals_module.get_condition_result(unit_number)
    if not storage.logistics_combinators then
        return false
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        return data.condition_result or false
    end

    return false
end

--- Set the last condition state
--- @param unit_number number The combinator's unit number
--- @param state boolean The last condition state
function globals_module.set_last_condition_state(unit_number, state)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        data.last_condition_state = state
    end
end

--- Get the last condition state
--- @param unit_number number The combinator's unit number
--- @return boolean The last condition state
function globals_module.get_last_condition_state(unit_number)
    if not storage.logistics_combinators then
        return false
    end

    local data = storage.logistics_combinators[unit_number]
    if data then
        return data.last_condition_state or false
    end

    return false
end

-- TODO: Add Mission Control network functions
-- function globals_module.register_mc_building(entity) ... end
-- function globals_module.unregister_mc_building(unit_number) ... end
-- function globals_module.get_mc_network(surface_index) ... end
-- function globals_module.update_mc_network_signals(surface_index, red_signals, green_signals) ... end

-- TODO: Add Receiver Combinator functions
-- function globals_module.register_receiver(entity) ... end
-- function globals_module.unregister_receiver(unit_number) ... end
-- function globals_module.get_receiver_data(unit_number) ... end
-- function globals_module.set_receiver_configured_surfaces(unit_number, surfaces) ... end

return globals_module
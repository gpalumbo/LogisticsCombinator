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
                sections = {  -- Array of {group="name", multiplier=1.0} tuples we injected
                    {group = "group-name", multiplier = 1.0}
                }
            }
        }
    }
    ]]

    -- Logistics chooser combinator state
    storage.logistics_choosers = storage.logistics_choosers or {}
    --[[
    Structure:
    [chooser_unit_number] = {
        entity = entity_reference,
        groups = {  -- Array of group selections
            {
                group = "group-name",  -- Logistics group name
                signal = {type="item", name="iron-plate"},  -- Signal to check
                operator = "=",  -- Comparison operator (<, >, =, ≠, ≤, ≥)
                value = 100,  -- Value to match
                multiplier = 1.0,  -- Quantity multiplier for group
                is_active = false  -- Condition evaluation result (updated during processing)
            }
        },
        active_group = nil,  -- Currently active group name
        connected_entities = {}  -- cached unit_numbers
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

--- Track an injected section by {group, multiplier} tuple
--- @param combinator_unit_number number The combinator that injected
--- @param entity_unit_number number The entity that received
--- @param group_name string The group name that was injected
--- @param multiplier number The multiplier value
function globals_module.track_injected_section(combinator_unit_number, entity_unit_number, group_name, multiplier)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[combinator_unit_number]
    if data then
        if not data.injected_tracking then
            data.injected_tracking = {}
        end
        if not data.injected_tracking[entity_unit_number] then
            data.injected_tracking[entity_unit_number] = {sections = {}}
        end

        -- Get reference to entity tracking
        local entity_tracking = data.injected_tracking[entity_unit_number]

        -- Migrate old format (section_indices) to new format (sections) if needed
        if entity_tracking.section_indices and not entity_tracking.sections then
            entity_tracking.sections = {}
            entity_tracking.section_indices = nil
        end

        -- Ensure sections table exists (defensive)
        if not entity_tracking.sections then
            entity_tracking.sections = {}
        end

        -- Check if we already track this tuple (avoid duplicates)
        local already_tracked = false
        for _, tracked_section in ipairs(entity_tracking.sections) do
            if tracked_section.group == group_name and tracked_section.multiplier == multiplier then
                already_tracked = true
                break
            end
        end

        if not already_tracked then
            table.insert(entity_tracking.sections, {
                group = group_name,
                multiplier = multiplier
            })
        end
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

--- Remove a tracked section tuple for a specific entity
--- @param combinator_unit_number number The combinator
--- @param entity_unit_number number The entity
--- @param group_name string The group name
--- @param multiplier number The multiplier
function globals_module.remove_tracked_section(combinator_unit_number, entity_unit_number, group_name, multiplier)
    if not storage.logistics_combinators then
        return
    end

    local data = storage.logistics_combinators[combinator_unit_number]
    if not data or not data.injected_tracking then
        return
    end

    local entity_tracking = data.injected_tracking[entity_unit_number]
    if not entity_tracking or not entity_tracking.sections then
        return
    end

    -- Find and remove the matching tuple
    for i = #entity_tracking.sections, 1, -1 do
        local section = entity_tracking.sections[i]
        if section.group == group_name and section.multiplier == multiplier then
            table.remove(entity_tracking.sections, i)
            break  -- Only remove first match (working backwards, so it's the last match)
        end
    end

    -- Clean up empty entity tracking
    if #entity_tracking.sections == 0 then
        data.injected_tracking[entity_unit_number] = nil
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

    -- Always store the entity reference directly (for both ghost and real entities)
    storage.player_gui_states[player_index] = {
        open_entity = entity,  -- Store entity reference, not unit_number
        gui_type = gui_type,
        is_ghost = entity.type == "entity-ghost"
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

-- ============================================================================
-- LOGISTICS CHOOSER COMBINATOR FUNCTIONS
-- ============================================================================

--- Register a logistics chooser combinator
--- @param entity LuaEntity The chooser combinator entity
function globals_module.register_logistics_chooser(entity)
    if not entity or not entity.valid then return end

    if not storage.logistics_choosers then
        storage.logistics_choosers = {}
    end

    storage.logistics_choosers[entity.unit_number] = {
        entity = entity,
        groups = {},  -- Array of {group, condition, multiplier, is_active}
        active_group = nil,  -- Currently active group name
        connected_entities = {}
    }
end

--- Unregister a logistics chooser combinator
--- @param unit_number number The chooser's unit number
function globals_module.unregister_logistics_chooser(unit_number)
    if not storage.logistics_choosers then
        return
    end

    storage.logistics_choosers[unit_number] = nil
end

--- Get logistics chooser data (universal - works for both ghost and real entities)
--- @param entity_or_unit_number LuaEntity|number The chooser entity or unit_number
--- @return table|nil Chooser data or nil if not found
function globals_module.get_logistics_chooser_data(entity_or_unit_number)
    -- Handle nil input
    if not entity_or_unit_number then
        return nil
    end

    -- If passed a unit_number (number), read directly from storage
    if type(entity_or_unit_number) == "number" then
        if not storage.logistics_choosers then
            return nil
        end
        return storage.logistics_choosers[entity_or_unit_number]
    end

    -- Otherwise, it's an entity
    local entity = entity_or_unit_number

    -- Validate entity
    if not entity.valid then
        return nil
    end

    -- Handle ghost entities - read from tags
    if entity.type == "entity-ghost" then
        return globals_module.get_ghost_chooser_config(entity)
    end

    -- Handle real entities - read from storage using unit_number
    if not storage.logistics_choosers then
        return nil
    end
    return storage.logistics_choosers[entity.unit_number]
end

--- Add a group to a chooser
--- @param unit_number number The chooser's unit number
--- @param group table The group to add {group = "name", signal = {...}, value = 0}
function globals_module.add_chooser_group(unit_number, group)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[unit_number]
    if data then
        if not data.groups then
            data.groups = {}
        end
        table.insert(data.groups, group)
    end
end

--- Remove a group from a chooser
--- @param unit_number number The chooser's unit number
--- @param group_index number Index of the group to remove
function globals_module.remove_chooser_group(unit_number, group_index)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[unit_number]
    if data and data.groups and data.groups[group_index] then
        table.remove(data.groups, group_index)
    end
end

--- Update a group in a chooser
--- @param unit_number number The chooser's unit number
--- @param group_index number Index of the group to update
--- @param group table The updated group data
function globals_module.update_chooser_group(unit_number, group_index, group)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[unit_number]
    if data and data.groups and data.groups[group_index] then
        data.groups[group_index] = group
    end
end

--- Get all groups from a chooser
--- @param unit_number number The chooser's unit number
--- @return table Array of groups
function globals_module.get_chooser_groups(unit_number)
    if not storage.logistics_choosers then
        return {}
    end

    local data = storage.logistics_choosers[unit_number]
    if data and data.groups then
        return data.groups
    end

    return {}
end

--- Set the active group for a chooser
--- @param unit_number number The chooser's unit number
--- @param group_name string|nil The active group name (nil for none)
function globals_module.set_active_chooser_group(unit_number, group_name)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[unit_number]
    if data then
        data.active_group = group_name
    end
end

--- Get the active group for a chooser
--- @param unit_number number The chooser's unit number
--- @return string|nil The active group name
function globals_module.get_active_chooser_group(unit_number)
    if not storage.logistics_choosers then
        return nil
    end

    local data = storage.logistics_choosers[unit_number]
    if data then
        return data.active_group
    end

    return nil
end

--- Serialize chooser configuration for blueprints/copy-paste
--- @param unit_number number The chooser's unit number
--- @return table|nil Serialized configuration
function globals_module.serialize_chooser_config(unit_number)
    local data = globals_module.get_logistics_chooser_data(unit_number)
    if not data then return nil end

    return {
        groups = data.groups or {},
        mode = data.mode or "each"
    }
end

--- Restore chooser configuration from blueprint/copy-paste tags
--- @param entity LuaEntity The chooser entity
--- @param config table The serialized configuration
function globals_module.restore_chooser_config(entity, config)
    if not entity or not entity.valid or not config then return end

    -- Handle ghost entities differently - store in entity tags
    if entity.type == "entity-ghost" then
        -- Use the save function which handles tags correctly
        globals_module.save_ghost_chooser_config(entity, config)
        return
    end

    local unit_number = entity.unit_number
    local data = storage.logistics_choosers[unit_number]

    if not data then
        -- Register the entity first if not already registered
        globals_module.register_logistics_chooser(entity)
        data = storage.logistics_choosers[unit_number]
    end

    if data then
        data.groups = config.groups or {}
        data.mode = config.mode or "each"
    end
end

--- Save chooser configuration to ghost entity tags
--- @param ghost_entity LuaEntity The ghost entity
--- @param config table The configuration to save
function globals_module.save_ghost_chooser_config(ghost_entity, config)
    if not ghost_entity or not ghost_entity.valid or ghost_entity.type ~= "entity-ghost" then
        return
    end

    -- Create a new table with existing tags (if any) plus the new config
    -- This is necessary because entity.tags might be read-only in certain states
    local tags = ghost_entity.tags or {}
    local new_tags = {}

    -- Copy existing tags
    for key, value in pairs(tags) do
        new_tags[key] = value
    end

    -- Add/update chooser config
    new_tags.chooser_config = config

    -- Assign the new table
    ghost_entity.tags = new_tags
end

--- Get chooser configuration from ghost entity tags
--- @param ghost_entity LuaEntity The ghost entity
--- @return table|nil Configuration from tags
function globals_module.get_ghost_chooser_config(ghost_entity)
    if not ghost_entity or not ghost_entity.valid or ghost_entity.type ~= "entity-ghost" then
        return nil
    end

    if ghost_entity.tags and ghost_entity.tags.chooser_config then
        return ghost_entity.tags.chooser_config
    else 
        globals_module.save_ghost_chooser_config(ghost_entity, {
            groups = {},
            mode = "each"
        })
        return ghost_entity.tags.chooser_config
    end

end

--- Add a group to chooser (works for both real and ghost entities)
--- @param entity LuaEntity The chooser entity
--- @param group table The group to add
function globals_module.add_chooser_group_universal(entity, group)
    if not entity or not entity.valid then return end

    if entity.type == "entity-ghost" then
        local config = globals_module.get_ghost_chooser_config(entity)
        if not config.groups then config.groups = {} end
        table.insert(config.groups, group)
        globals_module.save_ghost_chooser_config(entity, config)
    else
        globals_module.add_chooser_group(entity.unit_number, group)
    end
end

--- Remove a group from chooser (works for both real and ghost entities)
--- @param entity LuaEntity The chooser entity
--- @param group_index number Index of the group to remove
function globals_module.remove_chooser_group_universal(entity, group_index)
    if not entity or not entity.valid then return end

    if entity.type == "entity-ghost" then
        local config = globals_module.get_ghost_chooser_config(entity)
        if config.groups and config.groups[group_index] then
            table.remove(config.groups, group_index)
            globals_module.save_ghost_chooser_config(entity, config)
        end
    else
        globals_module.remove_chooser_group(entity.unit_number, group_index)
    end
end

--- Update a group in chooser (works for both real and ghost entities)
--- @param entity LuaEntity The chooser entity
--- @param group_index number Index of the group to update
--- @param group table The updated group data
function globals_module.update_chooser_group_universal(entity, group_index, group)
    if not entity or not entity.valid then return end

    if entity.type == "entity-ghost" then
        local config = globals_module.get_ghost_chooser_config(entity)
        if config.groups and config.groups[group_index] then
            config.groups[group_index] = group
            globals_module.save_ghost_chooser_config(entity, config)
        end
    else
        globals_module.update_chooser_group(entity.unit_number, group_index, group)
    end
end

--------------------------------------------------------------------------------
-- CHOOSER INJECTION TRACKING
--------------------------------------------------------------------------------

--- Track an injected logistics section for a chooser
--- @param chooser_unit_number number The chooser's unit number
--- @param entity_unit_number number The target entity's unit number
--- @param group_name string The group name
--- @param multiplier number The multiplier
function globals_module.track_chooser_injection(chooser_unit_number, entity_unit_number, group_name, multiplier)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[chooser_unit_number]
    if data then
        if not data.injected_tracking then
            data.injected_tracking = {}
        end
        if not data.injected_tracking[entity_unit_number] then
            data.injected_tracking[entity_unit_number] = {sections = {}}
        end

        -- Get reference to entity tracking
        local entity_tracking = data.injected_tracking[entity_unit_number]

        -- Check if this tuple already exists
        local exists = false
        for _, section in ipairs(entity_tracking.sections) do
            if section.group == group_name and section.multiplier == multiplier then
                exists = true
                break
            end
        end

        -- Only add if not already tracked
        if not exists then
            table.insert(entity_tracking.sections, {
                group = group_name,
                multiplier = multiplier
            })
        end
    end
end

--- Clear all injected tracking for a chooser
--- @param chooser_unit_number number The chooser's unit number
function globals_module.clear_chooser_tracking(chooser_unit_number)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[chooser_unit_number]
    if data then
        data.injected_tracking = {}
    end
end

--- Remove a tracked section tuple for a specific entity
--- @param chooser_unit_number number The chooser
--- @param entity_unit_number number The entity
--- @param group_name string The group name
--- @param multiplier number The multiplier
function globals_module.remove_chooser_tracking(chooser_unit_number, entity_unit_number, group_name, multiplier)
    if not storage.logistics_choosers then
        return
    end

    local data = storage.logistics_choosers[chooser_unit_number]
    if not data or not data.injected_tracking then
        return
    end

    local entity_tracking = data.injected_tracking[entity_unit_number]
    if not entity_tracking or not entity_tracking.sections then
        return
    end

    -- Find and remove the matching tuple
    for i = #entity_tracking.sections, 1, -1 do
        local section = entity_tracking.sections[i]
        if section.group == group_name and section.multiplier == multiplier then
            table.remove(entity_tracking.sections, i)
            break  -- Only remove first match
        end
    end

    -- Clean up empty tracking
    if #entity_tracking.sections == 0 then
        data.injected_tracking[entity_unit_number] = nil
    end
end

--- Get injection tracking for a chooser
--- @param chooser_unit_number number The chooser's unit number
--- @return table Tracking data {[entity_id] = {sections = {{group, multiplier}, ...}}}
function globals_module.get_chooser_tracking(chooser_unit_number)
    if not storage.logistics_choosers then
        return {}
    end

    local data = storage.logistics_choosers[chooser_unit_number]
    if data and data.injected_tracking then
        return data.injected_tracking
    end

    return {}
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
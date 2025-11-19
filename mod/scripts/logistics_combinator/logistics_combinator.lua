-- Mission Control Mod - Logistics Combinator Logic
-- This module handles the core functionality of logistics combinators

local signal_utils = require("lib.signal_utils")
local circuit_utils = require("lib.circuit_utils")
local logistics_utils = require("lib.logistics_utils")
local gui_utils = require("lib.gui_utils")
local globals = require("scripts.globals")

local logistics_combinator = {}

--------------------------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------------------------

--- Process all logistics combinators on the given tick
--- Called every 15 ticks from the main control script
function logistics_combinator.process_all_combinators()
    if not storage.logistics_combinators then
        return
    end

    -- Process each active combinator
    for unit_number, combinator_data in pairs(storage.logistics_combinators) do
        if combinator_data.entity and combinator_data.entity.valid then
            logistics_combinator.process_rules(unit_number)
        else
            -- Entity destroyed, cleanup
            globals.unregister_logistics_combinator(unit_number)
        end
    end
end

--------------------------------------------------------------------------------
-- RULE PROCESSING
--------------------------------------------------------------------------------

--- Process rules for a specific logistics combinator
--- @param unit_number number The combinator's unit number
--- @param force_update boolean|nil If true, update even if condition state hasn't changed (for GUI changes)
function logistics_combinator.process_rules(unit_number, force_update)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data or not combinator_data.entity or not combinator_data.entity.valid then
        return
    end

    local entity = combinator_data.entity

    -- Check if powered (entity must be active)
    if entity.status ~= defines.entity_status.working and
       entity.status ~= defines.entity_status.normal and
       entity.status ~= defines.entity_status.low_power then
        -- Not powered, do nothing
        return
    end

    -- 1. Read input signals from both red and green wires
    local input_signals = circuit_utils.get_input_signals(entity, "combinator_input")
    if not input_signals then
        return
    end

    -- 2. Convert to signal tables for condition evaluation
    local red_signals = {}
    local green_signals = {}

    for _, sig_data in ipairs(input_signals.red or {}) do
        if sig_data.signal_id then
            local key = gui_utils.get_signal_key(sig_data.signal_id)
            red_signals[key] = sig_data.count
        end
    end

    for _, sig_data in ipairs(input_signals.green or {}) do
        if sig_data.signal_id then
            local key = gui_utils.get_signal_key(sig_data.signal_id)
            green_signals[key] = sig_data.count
        end
    end

    -- 3. Evaluate conditions
    local current_result = false
    if combinator_data.conditions and #combinator_data.conditions > 0 then
        current_result = gui_utils.evaluate_complex_conditions(
            combinator_data.conditions,
            red_signals,
            green_signals
        )
    end

    -- 4. Edge detection - only act on state changes (unless forced)
    local previous_state = globals.get_last_condition_state(unit_number)
    local state_changed = (current_result ~= previous_state)

    if not state_changed and not force_update then
        return  -- No state change and not forced, do nothing
    end

    -- 5. Update state in globals
    globals.set_last_condition_state(unit_number, current_result)
    globals.set_condition_result(unit_number, current_result)

    -- 6. Reconcile logistics sections based on condition result
    logistics_combinator.reconcile_sections(unit_number, current_result)
end

--------------------------------------------------------------------------------
-- CONNECTED ENTITY MANAGEMENT
--------------------------------------------------------------------------------

--- Update the list of connected entities for a combinator
--- @param unit_number number The combinator's unit number
function logistics_combinator.update_connected_entities(unit_number)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data or not combinator_data.entity or not combinator_data.entity.valid then
        return
    end

    local entity = combinator_data.entity

    -- Use the new circuit_utils function to find logistics-capable entities
    local logistics_entities = circuit_utils.find_logistics_entities_on_output(entity)

    -- Store entity references directly (not unit_numbers)
    -- This is more efficient and avoids lookup overhead
    combinator_data.connected_entities = logistics_entities
end

--------------------------------------------------------------------------------
-- GROUP INJECTION/REMOVAL
--------------------------------------------------------------------------------

--- Reconcile target entity sections with configured sections
--- Ensures that the actual state matches the desired state based on condition result
--- This handles: section deletions, modifications, additions, and condition changes
--- @param unit_number number The combinator's unit number
--- @param should_inject boolean True if sections should be injected, false if removed
function logistics_combinator.reconcile_sections(unit_number, should_inject)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data then
        return
    end

    -- Get configured sections (what SHOULD be present)
    local configured_sections = globals.get_logistics_sections(unit_number) or {}

    -- Get tracking data (what IS currently injected)
    local tracking = globals.get_injected_tracking(unit_number)

    -- Get connected entities
    local connected_entities = combinator_data.connected_entities or {}

    -- Build a lookup table of configured sections for fast checking
    local configured_lookup = {}
    for _, section in ipairs(configured_sections) do
        if section.group then
            local key = section.group .. "|" .. (section.multiplier or 1.0)
            configured_lookup[key] = section
        end
    end

    -- For each connected entity, reconcile its sections
    for _, target_entity in ipairs(connected_entities) do
        if target_entity.valid then
            local entity_tracking = tracking[target_entity.unit_number]

            -- Step 1: Remove tracked sections that shouldn't be present
            -- (either not configured anymore, or condition is false)
            if entity_tracking and entity_tracking.sections then
                for _, tracked_section in ipairs(entity_tracking.sections) do
                    local key = tracked_section.group .. "|" .. tracked_section.multiplier
                    local is_configured = configured_lookup[key] ~= nil

                    if not is_configured or not should_inject then
                        -- Section was deleted/changed OR condition is false -> remove it
                        logistics_combinator.remove_group(
                            unit_number,
                            target_entity,
                            tracked_section.group,
                            tracked_section
                        )
                    end
                end
            end

            -- Step 2: Inject configured sections if condition is true
            if should_inject then
                for _, section in ipairs(configured_sections) do
                    if section.group then
                        logistics_combinator.inject_group(
                            unit_number,
                            target_entity,
                            section.group,
                            section
                        )
                    end
                end
            end
        end
    end
end

--- Handle injection of a logistics group
--- @param combinator_unit_number number The combinator's unit number
--- @param entity LuaEntity Target entity
--- @param group_name string Name of the group to inject
--- @param section_data table Section data with group and multiplier
function logistics_combinator.inject_group(combinator_unit_number, entity, group_name, section_data)
    if not entity or not entity.valid then
        return  -- Entity destroyed
    end

    -- Check if entity has logistics capability (safe check)
    if not logistics_utils.supports_logistics_control(entity) then
        return  -- Not a logistics-capable entity
    end

    local requester_point = entity.get_requester_point()
    if not requester_point then
        return  -- Entity doesn't have requester point
    end

    local sections = requester_point.sections
    local multiplier = section_data.multiplier or 1.0

    -- Find the LAST section matching {group_name, multiplier} tuple
    -- We search backwards to find the most recently added section
    local existing_section_index = nil
    for i = #sections, 1, -1 do
        local section = sections[i]
        if section and section.group == group_name and section.multiplier == multiplier then
            existing_section_index = i
            break  -- Found the last match
        end
    end

    if existing_section_index then
        -- Section already exists with matching group and multiplier
        -- This is assumed to be our injected section, so nothing to do
        return
    end

    -- Section doesn't exist - inject a new one
    local section_index, err = logistics_utils.inject_logistics_group(
        entity,
        group_name,
        combinator_unit_number
    )

    if not section_index then
        -- Failed to inject group
        return
    end

    -- IMPORTANT: Reload sections after injection to get the updated list
    local updated_sections = requester_point.sections

    -- Apply multiplier to the newly created section
    if section_index <= #updated_sections then
        local logistic_section = updated_sections[section_index]
        if logistic_section then
            logistic_section.multiplier = multiplier
        end
    end

    -- Track the injection by {group_name, multiplier} tuple
    globals.track_injected_section(combinator_unit_number, entity.unit_number, group_name, multiplier)
end

--- Handle removal of a logistics group
--- @param combinator_unit_number number The combinator's unit number
--- @param entity LuaEntity Target entity
--- @param group_name string Name of the group to remove
--- @param section_data table Section data with group and multiplier
function logistics_combinator.remove_group(combinator_unit_number, entity, group_name, section_data)
    if not entity or not entity.valid then
        return  -- Entity destroyed
    end

    -- Check if entity has logistics capability
    if not logistics_utils.supports_logistics_control(entity) then
        return
    end

    local requester_point = entity.get_requester_point()
    if not requester_point then
        return
    end

    local sections = requester_point.sections
    local multiplier = section_data.multiplier or 1.0

    -- Find the LAST section matching {group_name, multiplier} tuple
    local section_to_remove = nil
    for i = #sections, 1, -1 do
        local section = sections[i]
        if section and section.group == group_name and section.multiplier == multiplier then
            section_to_remove = i
            break  -- Found the last match
        end
    end

    if not section_to_remove then
        -- Section doesn't exist (may have been manually removed by player)
        -- Clear tracking for this tuple
        globals.remove_tracked_section(combinator_unit_number, entity.unit_number, group_name, multiplier)
        return
    end

    -- Remove the section
    requester_point.remove_section(section_to_remove)

    -- Clear tracking for this tuple
    globals.remove_tracked_section(combinator_unit_number, entity.unit_number, group_name, multiplier)
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Cleanup all groups injected by a combinator
--- @param unit_number number The combinator's unit number
---
--- PERFORMANCE NOTE:
---   Reuses reconcile_sections() with should_inject=false to remove all tracked sections.
---   This leverages cached connected_entities instead of searching all surfaces.
---   Limitation: If an entity was disconnected before combinator removal,
---   its injected sections will remain. This is an acceptable trade-off
---   to avoid catastrophic performance issues with large bases.
function logistics_combinator.cleanup_injected_groups(unit_number)
    -- Use existing reconciliation logic with should_inject=false
    -- This removes all tracked sections from connected entities
    logistics_combinator.reconcile_sections(unit_number, false)

    -- Clear all tracking
    globals.clear_injected_tracking(unit_number)
end

--------------------------------------------------------------------------------
-- STATUS AND VALIDATION
--------------------------------------------------------------------------------

--- Get the status of a logistics combinator
--- @param unit_number number The combinator's unit number
--- @return table Status information
function logistics_combinator.get_status(unit_number)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data then
        return {
            active_rules = 0,
            connected_entities = 0,
            injected_groups = 0
        }
    end

    -- Count active sections (those with a group selected)
    local active_count = 0
    local sections = globals.get_logistics_sections(unit_number)
    if sections then
        for _, section in ipairs(sections) do
            if section.group then
                active_count = active_count + 1
            end
        end
    end

    -- Count connected entities
    local connected_count = 0
    if combinator_data.connected_entities then
        for _, entity in ipairs(combinator_data.connected_entities) do
            if entity.valid then
                connected_count = connected_count + 1
            end
        end
    end

    -- Count injected groups
    local injected_count = 0
    local tracking = globals.get_injected_tracking(unit_number)
    if tracking then
        for entity_unit_number, entity_tracking in pairs(tracking) do
            if entity_tracking.sections then
                injected_count = injected_count + #entity_tracking.sections
            end
        end
    end

    return {
        active_rules = active_count,
        connected_entities = connected_count,
        injected_groups = injected_count
    }
end

--- Check if a rule's state has changed (edge detection)
--- @param rule table The rule configuration
--- @param current_value number Current signal value
--- @return boolean True if state changed
--- NOTE: This function is kept for potential future use but is not currently needed
---       because process_rules() handles edge detection directly
function logistics_combinator.rule_state_changed(rule, current_value)
    -- This is handled inline in process_rules() for efficiency
    return false
end

--- Add a new rule to a combinator
--- @param unit_number number The combinator's unit number
--- @param rule table The rule configuration
--- NOTE: This function may not be needed if GUI uses globals functions directly
function logistics_combinator.add_rule(unit_number, rule)
    -- GUI uses globals.add_logistics_condition() and globals.add_logistics_section()
    -- This function is kept for potential API use
end

--- Remove a rule from a combinator
--- @param unit_number number The combinator's unit number
--- @param rule_index number Index of the rule to remove
--- NOTE: This function may not be needed if GUI uses globals functions directly
function logistics_combinator.remove_rule(unit_number, rule_index)
    -- GUI uses globals.remove_logistics_condition() and globals.remove_logistics_section()
    -- This function is kept for potential API use
end

--- Validate a rule configuration
--- @param rule table The rule to validate
--- @return boolean True if valid
--- @return string|nil Error message if invalid
--- NOTE: This function may not be needed if GUI performs validation
function logistics_combinator.validate_rule(rule)
    -- GUI performs validation before saving
    -- This function is kept for potential API use
    return true, nil
end

return logistics_combinator

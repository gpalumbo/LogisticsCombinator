-- Mission Control Mod - Logistics Chooser Combinator Logic
-- This module handles the core functionality of logistics chooser combinators
--
-- The chooser combinator supports two modes:
-- - "Each" mode: ALL groups with true conditions are activated
-- - "First Only" mode: Only the FIRST group with a true condition is activated (priority-based)

local signal_utils = require("lib.signal_utils")
local circuit_utils = require("lib.circuit_utils")
local logistics_utils = require("lib.logistics_utils")
local logistics_injection = require("lib.logistics_injection")
local gui_utils = require("lib.gui_utils")
local globals = require("scripts.globals")

local logistics_chooser = {}

--------------------------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------------------------

--- Process all logistics chooser combinators on the given tick
--- Called every 15 ticks from the main control script
function logistics_chooser.process_all_choosers()
    if not storage.logistics_choosers then
        return
    end

    -- Process each active chooser
    for unit_number, chooser_data in pairs(storage.logistics_choosers) do
        if chooser_data.entity and chooser_data.entity.valid then
            logistics_chooser.process_groups(unit_number)
        else
            -- Entity destroyed, cleanup
            globals.unregister_logistics_chooser(unit_number)
        end
    end
end

--------------------------------------------------------------------------------
-- GROUP PROCESSING
--------------------------------------------------------------------------------

--- Process groups for a specific logistics chooser combinator
--- Evaluates each group's condition and activates groups based on mode:
--- - "each" mode: activates ALL groups with true conditions
--- - "first_only" mode: activates only the FIRST group with a true condition
--- @param unit_number number The chooser's unit number
function logistics_chooser.process_groups(unit_number)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data or not chooser_data.entity or not chooser_data.entity.valid then
        return
    end

    local entity = chooser_data.entity

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
            local key = signal_utils.get_signal_key(sig_data.signal_id)
            red_signals[key] = sig_data.count
        end
    end

    for _, sig_data in ipairs(input_signals.green or {}) do
        if sig_data.signal_id then
            local key = signal_utils.get_signal_key(sig_data.signal_id)
            green_signals[key] = sig_data.count
        end
    end

    -- 3. Evaluate each group's condition
    local groups = chooser_data.groups or {}
    local mode = chooser_data.mode or "each"  -- Default to "each" mode
    local active_group_indices = {}
    local first_active_index = nil

    for i, group in ipairs(groups) do
        local is_active = false

        if group.condition and group.group then
            -- Evaluate this group's condition
            -- Note: We pass an array with a single condition since each group has one condition
            is_active = signal_utils.evaluate_complex_conditions(
                {group.condition},
                red_signals,
                green_signals
            )
        end

        -- Update the group's is_active state for GUI display
        group.is_active = is_active

        -- Track active groups
        if is_active then
            table.insert(active_group_indices, i)
            if not first_active_index then
                first_active_index = i
            end
        end
    end

    -- 4. Store updated group states
    for i, group in ipairs(groups) do
        globals.update_chooser_group(unit_number, i, group)
    end

    -- 5. Determine which groups should be injected based on mode
    local desired_sections = {}

    if mode == "first_only" then
        -- First Only mode: inject only the first active group
        if first_active_index then
            local active_group = groups[first_active_index]
            if active_group and active_group.group then
                table.insert(desired_sections, active_group)
            end
        end
    else
        -- Each mode (default): inject ALL active groups
        for _, idx in ipairs(active_group_indices) do
            local active_group = groups[idx]
            if active_group and active_group.group then
                table.insert(desired_sections, active_group)
            end
        end
    end

    -- 6. Reconcile logistics sections
    logistics_chooser.reconcile_groups(unit_number, desired_sections)
end

--------------------------------------------------------------------------------
-- CONNECTED ENTITY MANAGEMENT
--------------------------------------------------------------------------------

--- Update the list of connected entities for a chooser
--- @param unit_number number The chooser's unit number
function logistics_chooser.update_connected_entities(unit_number)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data or not chooser_data.entity or not chooser_data.entity.valid then
        return
    end

    local entity = chooser_data.entity

    -- Use shared logistics_injection function to find connected entities
    local logistics_entities = logistics_injection.update_connected_entities(entity)

    -- Store entity references directly (not unit_numbers)
    -- This is more efficient and avoids lookup overhead
    chooser_data.connected_entities = logistics_entities
end

--------------------------------------------------------------------------------
-- GROUP INJECTION/REMOVAL (Using Shared Library)
--------------------------------------------------------------------------------

--- Reconcile target entity sections with desired groups
--- Ensures that the active groups are injected based on mode
--- @param unit_number number The chooser's unit number
--- @param desired_sections table Array of sections that should be injected (0+ elements)
function logistics_chooser.reconcile_groups(unit_number, desired_sections)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data then
        return
    end

    -- Get tracking data (what IS currently injected)
    local tracking = globals.get_chooser_tracking(unit_number)

    -- Get connected entities
    local connected_entities = chooser_data.connected_entities or {}

    -- Use shared reconciliation logic
    logistics_injection.reconcile_sections(
        unit_number,
        connected_entities,
        desired_sections,
        tracking,
        globals.track_chooser_injection,
        globals.remove_chooser_tracking
    )
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Cleanup all groups injected by a chooser
--- @param unit_number number The chooser's unit number
function logistics_chooser.cleanup_injected_groups(unit_number)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data then
        return
    end

    -- Use shared cleanup logic
    logistics_injection.cleanup_injected_groups(
        unit_number,
        chooser_data.connected_entities or {},
        globals.get_chooser_tracking(unit_number),
        globals.remove_chooser_tracking,
        globals.clear_chooser_tracking
    )
end

--------------------------------------------------------------------------------
-- STATUS AND VALIDATION
--------------------------------------------------------------------------------

--- Get the status of a logistics chooser combinator
--- @param unit_number number The chooser's unit number
--- @return table Status information
function logistics_chooser.get_status(unit_number)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data then
        return {
            total_groups = 0,
            active_group = nil,
            connected_entities = 0,
            injected_groups = 0
        }
    end

    -- Count total groups
    local total_groups = 0
    local active_group_index = nil
    local groups = chooser_data.groups or {}

    for i, group in ipairs(groups) do
        if group.group then
            total_groups = total_groups + 1
            if group.is_active and not active_group_index then
                active_group_index = i
            end
        end
    end

    -- Count connected entities
    local connected_count = 0
    if chooser_data.connected_entities then
        for _, entity in ipairs(chooser_data.connected_entities) do
            if entity.valid then
                connected_count = connected_count + 1
            end
        end
    end

    -- Count injected groups
    local injected_count = 0
    local tracking = globals.get_chooser_tracking(unit_number)
    if tracking then
        for entity_unit_number, entity_tracking in pairs(tracking) do
            if entity_tracking.sections then
                injected_count = injected_count + #entity_tracking.sections
            end
        end
    end

    return {
        total_groups = total_groups,
        active_group = active_group_index,
        connected_entities = connected_count,
        injected_groups = injected_count
    }
end

return logistics_chooser
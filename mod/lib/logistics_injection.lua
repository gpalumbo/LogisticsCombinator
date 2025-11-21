-- logistics_injection.lua
-- Mission Control Mod - Shared Logistics Group Injection/Reconciliation Logic
--
-- PURPOSE:
--   Provides shared logic for injecting and reconciling logistics groups across
--   multiple combinators. This module handles the core reconciliation algorithm
--   that ensures target entities' logistics sections match the desired state.
--
-- RESPONSIBILITIES:
--   - Reconciling target entity sections with desired sections
--   - Injecting groups into target entities
--   - Removing groups from target entities
--   - Cleanup when combinator is removed
--   - Finding connected logistics entities
--
-- DOES NOT OWN:
--   - Determining WHICH groups should be active (combinator-specific logic)
--   - Evaluating conditions (combinator-specific logic)
--   - Global state storage (uses globals module via parameters)
--   - GUI logic
--
-- DEPENDENCIES:
--   - lib/logistics_utils.lua (low-level group operations)
--   - lib/circuit_utils.lua (finding connected entities)
--
-- USAGE PATTERN:
--   1. Combinator determines which groups should be active
--   2. Calls reconcile_sections() with desired groups
--   3. This module handles injection/removal to match desired state
--
-- MODULE BOUNDARY:
--   ✅ OWNS: Reconciliation algorithm, injection/removal coordination
--   ❌ DOES NOT OWN: Condition evaluation, deciding which groups are active
--
-- =============================================================================

local logistics_utils = require("lib.logistics_utils")
local circuit_utils = require("lib.circuit_utils")

local logistics_injection = {}

-- =============================================================================
-- CONNECTED ENTITY MANAGEMENT
-- =============================================================================

--- Update the list of connected entities for a combinator
--- Scans output circuit networks for logistics-capable entities
--- @param combinator_entity LuaEntity The combinator entity
--- @return table Array of connected logistics entities
---
--- USAGE:
---   local entities = logistics_injection.update_connected_entities(combinator)
---   combinator_data.connected_entities = entities
function logistics_injection.update_connected_entities(combinator_entity)
    if not combinator_entity or not combinator_entity.valid then
        return {}
    end

    -- Use circuit_utils to find logistics-capable entities on output
    local logistics_entities = circuit_utils.find_logistics_entities_on_output(combinator_entity)

    return logistics_entities
end

-- =============================================================================
-- GROUP INJECTION/REMOVAL
-- =============================================================================

--- Inject a logistics group into a target entity
--- Checks if group already exists before creating a new section
--- @param combinator_unit_number number The combinator's unit number (for tracking)
--- @param target_entity LuaEntity Target entity to inject into
--- @param group_name string Name of the logistics group
--- @param section_data table Section configuration {group, multiplier}
--- @return boolean True if injection succeeded or group already exists
---
--- EDGE CASES:
---   - Returns false if entity is invalid
---   - Returns false if entity doesn't support logistics
---   - Returns true if group already exists (no duplicate injection)
---   - Applies multiplier after injection
---
--- USAGE:
---   local success = logistics_injection.inject_group(
---     combinator.unit_number,
---     target_entity,
---     "fuel-request",
---     {group = "fuel-request", multiplier = 2.0}
---   )
function logistics_injection.inject_group(combinator_unit_number, target_entity, group_name, section_data)
    if not target_entity or not target_entity.valid then
        return false  -- Entity destroyed
    end

    -- Check if entity has logistics capability (safe check)
    if not logistics_utils.supports_logistics_control(target_entity) then
        return false  -- Not a logistics-capable entity
    end

    local requester_point = target_entity.get_requester_point()
    if not requester_point then
        return false  -- Entity doesn't have requester point
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
        return true
    end

    -- Section doesn't exist - inject a new one
    local section_index, err = logistics_utils.inject_logistics_group(
        target_entity,
        group_name,
        combinator_unit_number
    )

    if not section_index then
        -- Failed to inject group
        return false
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

    return true
end

--- Remove a logistics group from a target entity
--- Only removes sections matching the group name and multiplier
--- @param combinator_unit_number number The combinator's unit number
--- @param target_entity LuaEntity Target entity to remove from
--- @param group_name string Name of the logistics group
--- @param section_data table Section configuration {group, multiplier}
--- @return boolean True if removal succeeded or group didn't exist
---
--- EDGE CASES:
---   - Returns false if entity is invalid
---   - Returns true if group doesn't exist (already removed)
---   - Removes only the LAST matching section
---
--- USAGE:
---   local success = logistics_injection.remove_group(
---     combinator.unit_number,
---     target_entity,
---     "fuel-request",
---     {group = "fuel-request", multiplier = 2.0}
---   )
function logistics_injection.remove_group(combinator_unit_number, target_entity, group_name, section_data)
    if not target_entity or not target_entity.valid then
        return false  -- Entity destroyed
    end

    -- Check if entity has logistics capability
    if not logistics_utils.supports_logistics_control(target_entity) then
        return false
    end

    local requester_point = target_entity.get_requester_point()
    if not requester_point then
        return false
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
        return true
    end

    -- Remove the section
    requester_point.remove_section(section_to_remove)

    return true
end

-- =============================================================================
-- RECONCILIATION LOGIC
-- =============================================================================

--- Reconcile target entity sections with desired sections
--- Ensures that the actual state matches the desired state
--- Handles: section deletions, modifications, additions, and condition changes
---
--- @param combinator_unit_number number The combinator's unit number
--- @param connected_entities table Array of connected logistics entities
--- @param desired_sections table Array of sections that should exist {group, multiplier}
--- @param tracking table Tracking data {[entity_unit_number] = {sections = {...}}}
--- @param track_injection function(combinator_id, entity_id, group, multiplier) Callback to track injection
--- @param remove_tracked function(combinator_id, entity_id, group, multiplier) Callback to remove tracking
---
--- ALGORITHM:
---   For each connected entity:
---     1. Remove tracked sections that are not in desired_sections
---     2. Inject desired sections that don't exist yet
---
--- DESIRED SECTIONS FORMAT:
---   {
---     {group = "fuel-request", multiplier = 2.0},
---     {group = "science-request", multiplier = 1.0}
---   }
---
--- TRACKING FORMAT:
---   {
---     [entity_unit_number] = {
---       sections = {
---         {group = "fuel-request", multiplier = 2.0},
---         ...
---       }
---     }
---   }
---
--- USAGE EXAMPLE (Logistics Combinator):
---   -- When condition is true, inject all configured sections
---   local desired = combinator_data.sections or {}
---   logistics_injection.reconcile_sections(
---     combinator.unit_number,
---     combinator_data.connected_entities,
---     desired,
---     storage.injected_groups[combinator.unit_number],
---     globals.track_injected_section,
---     globals.remove_tracked_section
---   )
---
--- USAGE EXAMPLE (Chooser Combinator):
---   -- Only inject the first active group
---   local desired = {}
---   for _, group in ipairs(combinator_data.groups) do
---     if group.is_active then
---       table.insert(desired, group)
---       break  -- Only first active
---     end
---   end
---   logistics_injection.reconcile_sections(...)
function logistics_injection.reconcile_sections(
    combinator_unit_number,
    connected_entities,
    desired_sections,
    tracking,
    track_injection,
    remove_tracked
)
    if not connected_entities then
        return
    end

    -- Build a lookup table of desired sections for fast checking
    local desired_lookup = {}
    for _, section in ipairs(desired_sections or {}) do
        if section.group then
            local key = section.group .. "|" .. (section.multiplier or 1.0)
            desired_lookup[key] = section
        end
    end

    -- For each connected entity, reconcile its sections
    for _, target_entity in ipairs(connected_entities) do
        if target_entity.valid then
            local entity_tracking = tracking and tracking[target_entity.unit_number]

            -- Step 1: Remove tracked sections that shouldn't be present
            if entity_tracking and entity_tracking.sections then
                for _, tracked_section in ipairs(entity_tracking.sections) do
                    local key = tracked_section.group .. "|" .. tracked_section.multiplier
                    local is_desired = desired_lookup[key] ~= nil

                    if not is_desired then
                        -- Section was deleted/changed OR should not be present -> remove it
                        logistics_injection.remove_group(
                            combinator_unit_number,
                            target_entity,
                            tracked_section.group,
                            tracked_section
                        )

                        -- Clear tracking
                        if remove_tracked then
                            remove_tracked(
                                combinator_unit_number,
                                target_entity.unit_number,
                                tracked_section.group,
                                tracked_section.multiplier
                            )
                        end
                    end
                end
            end

            -- Step 2: Inject desired sections
            for _, section in ipairs(desired_sections or {}) do
                if section.group then
                    local success = logistics_injection.inject_group(
                        combinator_unit_number,
                        target_entity,
                        section.group,
                        section
                    )

                    -- Track the injection
                    if success and track_injection then
                        track_injection(
                            combinator_unit_number,
                            target_entity.unit_number,
                            section.group,
                            section.multiplier or 1.0
                        )
                    end
                end
            end
        end
    end
end

-- =============================================================================
-- CLEANUP OPERATIONS
-- =============================================================================

--- Cleanup all groups injected by a combinator
--- Uses reconciliation with empty desired_sections to remove everything
--- @param combinator_unit_number number The combinator's unit number
--- @param connected_entities table Array of connected logistics entities
--- @param tracking table Tracking data for this combinator
--- @param remove_tracked function Callback to remove tracking
--- @param clear_tracking function Callback to clear all tracking
---
--- PERFORMANCE NOTE:
---   Reuses reconcile_sections() with empty desired_sections to remove all tracked sections.
---   This leverages cached connected_entities instead of searching all surfaces.
---   Limitation: If an entity was disconnected before combinator removal,
---   its injected sections will remain. This is an acceptable trade-off
---   to avoid catastrophic performance issues with large bases.
---
--- USAGE:
---   logistics_injection.cleanup_injected_groups(
---     combinator.unit_number,
---     combinator_data.connected_entities,
---     storage.injected_groups[combinator.unit_number],
---     globals.remove_tracked_section,
---     globals.clear_injected_tracking
---   )
function logistics_injection.cleanup_injected_groups(
    combinator_unit_number,
    connected_entities,
    tracking,
    remove_tracked,
    clear_tracking
)
    -- Use reconciliation with empty desired sections to remove everything
    logistics_injection.reconcile_sections(
        combinator_unit_number,
        connected_entities,
        {},  -- Empty desired sections = remove all
        tracking,
        nil,  -- No injection tracking needed
        remove_tracked
    )

    -- Clear all tracking for this combinator
    if clear_tracking then
        clear_tracking(combinator_unit_number)
    end
end

-- =============================================================================
-- MODULE EXPORT
-- =============================================================================

return logistics_injection

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

--[[

EXAMPLE 1: Logistics Combinator (inject all when condition is true)
---------------------------------------------------------------------
local logistics_injection = require("lib.logistics_injection")
local globals = require("scripts.globals")

function logistics_combinator.reconcile_sections(unit_number, should_inject)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data then return end

    local configured_sections = globals.get_logistics_sections(unit_number) or {}
    local tracking = globals.get_injected_tracking(unit_number)
    local connected_entities = combinator_data.connected_entities or {}

    -- Determine desired sections based on condition
    local desired_sections = should_inject and configured_sections or {}

    -- Use shared reconciliation logic
    logistics_injection.reconcile_sections(
        unit_number,
        connected_entities,
        desired_sections,
        tracking,
        globals.track_injected_section,
        globals.remove_tracked_section
    )
end


EXAMPLE 2: Chooser Combinator (inject only first active group)
----------------------------------------------------------------
local logistics_injection = require("lib.logistics_injection")
local globals = require("scripts.globals")

function logistics_chooser.reconcile_groups(unit_number)
    local chooser_data = globals.get_logistics_chooser_data(unit_number)
    if not chooser_data then return end

    local groups = chooser_data.groups or {}
    local tracking = globals.get_chooser_tracking(unit_number)
    local connected_entities = chooser_data.connected_entities or {}

    -- Find the first active group (priority-based selection)
    local desired_sections = {}
    for _, group in ipairs(groups) do
        if group.is_active then
            table.insert(desired_sections, group)
            break  -- Only inject the first active group
        end
    end

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


EXAMPLE 3: Cleanup on combinator removal
------------------------------------------
local logistics_injection = require("lib.logistics_injection")
local globals = require("scripts.globals")

function on_combinator_removed(unit_number)
    local combinator_data = globals.get_logistics_combinator_data(unit_number)
    if not combinator_data then return end

    -- Cleanup all injected groups
    logistics_injection.cleanup_injected_groups(
        unit_number,
        combinator_data.connected_entities,
        globals.get_injected_tracking(unit_number),
        globals.remove_tracked_section,
        globals.clear_injected_tracking
    )

    -- Unregister from globals
    globals.unregister_logistics_combinator(unit_number)
end

--]]
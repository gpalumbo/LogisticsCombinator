-- logistics_utils.lua
-- Mission Control Mod - Logistics Group Management Utilities
--
-- PURPOSE:
-- Low-level operations for injecting and removing logistics groups from entities.
-- This module performs the Factorio API operations but does NOT track injections
-- in global state. The caller (scripts/logistics_combinator.lua) is responsible
-- for tracking which combinator injected which groups.
--
-- DEPENDENCIES: None (pure utility functions)
--
-- MODULE BOUNDARY:
-- ✅ OWNS: Low-level logistics section manipulation
-- ❌ DOES NOT OWN: Tracking injections in global, deciding when to inject/remove
--
-- =============================================================================

local logistics_utils = {}

-- =============================================================================
-- ENTITY CAPABILITY DETECTION
-- =============================================================================

--- Check if entity supports logistics control
-- @param entity LuaEntity: Entity to check
-- @return boolean: True if entity has logistic_sections property
--
-- USAGE:
-- if logistics_utils.supports_logistics_control(entity) then
--   -- Safe to call injection/removal functions
-- end
function logistics_utils.supports_logistics_control(entity)
  if not entity or not entity.valid then
    return false
  end

  -- Check if entity has a requester point (logistics capability)
  -- This includes: cargo landing pads, inserters, assemblers, cargo bays, etc.
  local requester_point = entity.get_requester_point()
  return requester_point ~= nil
end

-- =============================================================================
-- NETWORK SCANNING
-- =============================================================================

--- Find all logistics-enabled entities connected to a circuit network
--
-- ⚠️ WARNING: This function requires entity tracking via wire connection events!
-- LuaCircuitNetwork does NOT have a connected_entities property in Factorio 2.0.
--
-- IMPLEMENTATION REQUIRED:
-- - Track entities when wires are connected (on_wire_added event)
-- - Store in global: storage.circuit_entities[network_id] = {entity_unit_numbers}
-- - Use this function as a helper to filter tracked entities
--
-- @param circuit_network LuaCircuitNetwork: Network to scan
-- @return table: Array of entities with logistics capability (may be empty)
--
-- TEMPORARY IMPLEMENTATION:
-- Currently returns empty array. Caller must implement event-based tracking.
-- See scripts/logistics_combinator.lua for tracking implementation.
function logistics_utils.find_logistics_entities_on_network(circuit_network)
  local results = {}

  if not circuit_network or not circuit_network.valid then
    return results
  end

  -- TODO: Implement event-based entity tracking
  -- LuaCircuitNetwork.connected_entities does NOT exist in Factorio API
  -- This function cannot work without external tracking

  -- Placeholder: Return empty array
  -- The logistics combinator script must track connected entities via:
  -- - on_wire_added event: Add entity to storage.circuit_entities[network.network_id]
  -- - on_wire_removed event: Remove entity from tracking
  -- - Pass tracked entities to this function for filtering

  return results
end

-- =============================================================================
-- GROUP DETECTION
-- =============================================================================

--- Check if entity has a logistics section with the specified group name
-- Searches through all logistic sections on the entity
-- @param entity LuaEntity: Entity to check
-- @param group_name string: Name of logistics group to find
-- @return boolean: True if entity has a section with this group name
-- @return number|nil: Section index if found, nil otherwise
--
-- USAGE:
-- local has_group, section_idx = logistics_utils.has_logistics_group(entity, "fuel-request")
-- if has_group then
--   game.print("Entity already has fuel-request group at section " .. section_idx)
-- end
function logistics_utils.has_logistics_group(entity, group_name)
  if not logistics_utils.supports_logistics_control(entity) then
    return false, nil
  end

  if not group_name or group_name == "" then
    return false, nil
  end

  local requester_point = entity.get_requester_point()
  if not requester_point then
    return false, nil
  end

  local sections = requester_point.sections

  -- Iterate through all sections
  for i = 1, #sections do
    local section = sections[i]
    if section and section.group and section.group == group_name then
      return true, i
    end
  end

  return false, nil
end

-- =============================================================================
-- GROUP INJECTION
-- =============================================================================

--- Inject a logistics group into an entity
-- Creates a new logistic section with the specified group assignment
-- Does NOT check if group already exists - caller should check first
-- Does NOT track injection in global - caller must do that
--
-- @param entity LuaEntity: Target entity with logistic_sections
-- @param group_name string: Name of logistics group to inject
-- @param combinator_id number: Combinator unit_number (stored in metadata for tracking)
-- @return number|nil: Section index of created section, or nil on failure
-- @return string|nil: Error message if failed
--
-- USAGE:
-- if not logistics_utils.has_logistics_group(entity, "fuel-request") then
--   local section_idx, err = logistics_utils.inject_logistics_group(entity, "fuel-request", combinator.unit_number)
--   if section_idx then
--     -- Caller must now track: storage.injected_groups[entity.unit_number][section_idx] = combinator.unit_number
--   else
--     game.print("Failed to inject: " .. err)
--   end
-- end
function logistics_utils.inject_logistics_group(entity, group_name, combinator_id)
  -- Validate inputs
  if not logistics_utils.supports_logistics_control(entity) then
    return nil, "Entity does not support logistics control"
  end

  if not group_name or group_name == "" then
    return nil, "Group name cannot be empty"
  end

  if not combinator_id then
    return nil, "Combinator ID required for tracking"
  end

  -- Get requester point and create new logistics section
  local requester_point = entity.get_requester_point()
  if not requester_point then
    return nil, "Entity does not have a requester point"
  end

  local new_section = requester_point.add_section()

  if not new_section then
    return nil, "Failed to create logistics section"
  end

  -- Assign group to section
  new_section.group = group_name

  -- Store combinator ID in section metadata (if API supports it)
  -- Note: Factorio 2.0 logistic sections may not have custom metadata storage
  -- In that case, caller MUST track this in storage.injected_groups
  -- new_section.metadata = {combinator_id = combinator_id}  -- Not available in API

  -- Return the section index (1-based)
  local section_index = #requester_point.sections

  return section_index, nil
end

-- =============================================================================
-- GROUP REMOVAL
-- =============================================================================

--- Remove a logistics group from an entity
-- Searches for sections with matching group name and removes them
-- Only removes sections that were injected by the specified combinator
-- Requires tracking data to identify which sections belong to which combinator
--
-- @param entity LuaEntity: Target entity
-- @param group_name string: Name of logistics group to remove
-- @param combinator_id number: Only remove if injected by this combinator
-- @param tracking_data table: Tracking table {[section_index] = combinator_id}
-- @return boolean: True if any sections were removed
-- @return number: Count of sections removed
--
-- USAGE:
-- local tracking = storage.injected_groups[entity.unit_number] or {}
-- local removed, count = logistics_utils.remove_logistics_group(entity, "fuel-request", combinator.unit_number, tracking)
-- if removed then
--   game.print("Removed " .. count .. " sections")
--   -- Caller must update storage.injected_groups
-- end
function logistics_utils.remove_logistics_group(entity, group_name, combinator_id, tracking_data)
  if not logistics_utils.supports_logistics_control(entity) then
    return false, 0
  end

  if not group_name or group_name == "" then
    return false, 0
  end

  local requester_point = entity.get_requester_point()
  if not requester_point then
    return false, 0
  end

  tracking_data = tracking_data or {}
  local sections = requester_point.sections
  local removed_count = 0

  -- Iterate backwards to safely remove sections
  for i = #sections, 1, -1 do
    local section = sections[i]

    -- Check if this section matches the group name
    if section and section.group == group_name then
      -- Check if this section was injected by the specified combinator
      local injected_by = tracking_data[i]

      if injected_by == combinator_id then
        -- Remove the section
        requester_point.remove_section(i)
        removed_count = removed_count + 1
      end
    end
  end

  return removed_count > 0, removed_count
end

-- =============================================================================
-- GROUP VALIDATION
-- =============================================================================

--- Get logistics group template/definition by name
-- In Factorio 2.0, logistics groups are user-defined and managed by the game
-- This function validates that a group name exists in the game
--
-- @param group_name string: Name of logistics group
-- @return boolean: True if group exists
-- @return string|nil: Error message if not found
--
-- USAGE:
-- local valid, err = logistics_utils.get_logistics_group_template("fuel-request")
-- if not valid then
--   game.print("Invalid group: " .. err)
-- end
--
-- NOTE: Factorio's logistics groups are stored in game.logistic_groups
-- This function just validates the name exists
function logistics_utils.get_logistics_group_template(group_name)
  if not group_name or group_name == "" then
    return false, "Group name cannot be empty"
  end

  -- In Factorio 2.0, logistics groups are part of the game state
  -- We can't directly enumerate them without a force/player context
  -- For now, we'll accept any non-empty string as valid
  -- The actual validation happens when assigning to a section

  -- If the group doesn't exist, Factorio will handle the error
  -- when we try to assign it to a section

  return true, nil
end

-- =============================================================================
-- CLEANUP OPERATIONS
-- =============================================================================

--- Remove all logistics groups injected by a specific combinator
-- Used when a combinator is removed or needs to clean up all its injections
-- Requires tracking data to know which sections to remove
--
-- @param combinator_id number: Combinator unit_number
-- @param tracking_data table: Full tracking table {[entity_id] = {[section_idx] = combinator_id}}
-- @return number: Total count of sections removed
--
-- USAGE:
-- local removed_count = logistics_utils.cleanup_combinator_groups(
--   combinator.unit_number,
--   storage.injected_groups
-- )
-- game.print("Cleaned up " .. removed_count .. " injected groups")
-- -- Caller must clear tracking data from storage.injected_groups
function logistics_utils.cleanup_combinator_groups(combinator_id, tracking_data)
  if not combinator_id or not tracking_data then
    return 0
  end

  local total_removed = 0

  -- Iterate through all tracked entities
  for entity_id, entity_sections in pairs(tracking_data) do
    -- Find the entity
    local entity = nil

    -- Try to find entity by unit_number (expensive, but necessary)
    -- In production, caller should pass entity references or use game.get_entity_by_unit_number
    for _, surface in pairs(game.surfaces) do
      local found_entities = surface.find_entities_filtered{
        name = {"cargo-landing-pad", "inserter", "assembling-machine", "cargo-bay"},
        limit = 1000  -- Reasonable limit
      }

      for _, e in pairs(found_entities) do
        if e.valid and e.unit_number == entity_id then
          entity = e
          break
        end
      end

      if entity then break end
    end

    -- If entity found, remove sections injected by this combinator
    if entity and entity.valid and logistics_utils.supports_logistics_control(entity) then
      local requester_point = entity.get_requester_point()
      if requester_point then
        local sections = requester_point.sections

        -- Iterate backwards to safely remove
        for section_idx = #sections, 1, -1 do
          if entity_sections[section_idx] == combinator_id then
            requester_point.remove_section(section_idx)
            total_removed = total_removed + 1
          end
        end
      end
    end
  end

  return total_removed
end

--- Remove all logistics groups from a specific entity
-- Used when an entity is removed or needs cleanup
-- Only removes sections that were tracked (injected by combinators)
--
-- @param entity LuaEntity: Entity to clean up
-- @param tracking_data table: Tracking table for this entity {[section_idx] = combinator_id}
-- @return number: Count of sections removed
--
-- USAGE:
-- local tracking = storage.injected_groups[entity.unit_number] or {}
-- local removed_count = logistics_utils.cleanup_entity_groups(entity, tracking)
-- game.print("Cleaned up " .. removed_count .. " injected groups from entity")
-- -- Caller must clear tracking data: storage.injected_groups[entity.unit_number] = nil
function logistics_utils.cleanup_entity_groups(entity, tracking_data)     
  if not logistics_utils.supports_logistics_control(entity) then
    return 0
  end

  if not tracking_data then
    return 0
  end

  local requester_point = entity.get_requester_point()
  if not requester_point then
    return 0
  end

  local sections = requester_point.sections
  local removed_count = 0

  -- Iterate backwards to safely remove sections
  for section_idx = #sections, 1, -1 do
    if tracking_data[section_idx] then
      requester_point.remove_section(section_idx)
      removed_count = removed_count + 1
    end
  end

  return removed_count
end

-- =============================================================================
-- MODULE EXPORT
-- =============================================================================

return logistics_utils

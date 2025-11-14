-- init.lua
-- Mission Control Mod - Logistics Combinator Module
--
-- PURPOSE:
-- Business logic for logistics combinators: rule processing, entity tracking,
-- and coordinating logistics group injection/removal.
--
-- RESPONSIBILITIES:
-- - Entity lifecycle (build/remove)
-- - Rule processing and evaluation
-- - Connected entity detection and caching
-- - Rule state tracking (edge-triggering)
-- - Coordinating with lib/logistics_utils for injection/removal
--
-- DOES NOT OWN:
-- - Low-level logistics operations (that's lib/logistics_utils)
-- - GUI creation (that's scripts/logistics_combinator/gui)
-- - Condition evaluation algorithm (that's lib/gui_utils)
-- - Global state storage (that's scripts/mc_globals)

local logistics_combinator = {}

-- Load dependencies
local mc_globals = require("scripts.mc_globals")
local logistics_utils = require("lib.logistics_utils")
local gui_utils = require("lib.gui_utils")
local circuit_utils = require("lib.circuit_utils")
local signal_utils = require("lib.signal_utils")

-- GUI module will be loaded lazily to avoid circular dependencies
local logistics_gui = nil

-- ==============================================================================
-- MODULE-LOCAL ENTITY CACHE (Performance Optimization)
-- ==============================================================================
-- CRITICAL: These caches are NOT serialized in storage. They are rebuilt on_load.
-- Storage state stores surface_index + position for reconstruction.
-- This avoids O(n²) entity lookups that would cause severe performance issues.

--- Cache of combinator entities by unit_number
-- @type table<number, LuaEntity>
local combinator_entity_cache = {}

--- Cache of connected entities by unit_number
-- @type table<number, LuaEntity>
local connected_entity_cache = {}

--- Clear all entity caches (called on_load)
local function clear_entity_caches()
  combinator_entity_cache = {}
  connected_entity_cache = {}
end

--- Get combinator entity by unit_number (uses cache, O(1) after first lookup)
-- @param unit_number number: Combinator unit_number
-- @return LuaEntity|nil: Combinator entity or nil if not found/invalid
local function get_combinator_entity(unit_number)
  -- Check cache first
  local cached = combinator_entity_cache[unit_number]
  if cached and cached.valid then
    return cached
  end

  -- Cache miss - need to find entity
  if not storage.logistics_combinators or not storage.logistics_combinators[unit_number] then
    return nil
  end

  local data = storage.logistics_combinators[unit_number]
  local surface_index = data.surface_index
  local position = data.position

  if not surface_index or not position then
    return nil
  end

  local surface = game.surfaces[surface_index]
  if not surface then
    return nil
  end

  -- Find entity at stored position
  local entity = surface.find_entity("logistics-combinator", position)

  if entity and entity.valid and entity.unit_number == unit_number then
    -- Cache for next time
    combinator_entity_cache[unit_number] = entity
    return entity
  end

  return nil
end

--- Get any entity by unit_number (uses cache, O(1) after first lookup)
-- @param unit_number number: Entity unit_number
-- @return LuaEntity|nil: Entity or nil if not found/invalid
local function get_entity_by_unit_number(unit_number)
  -- Check cache first
  local cached = connected_entity_cache[unit_number]
  if cached and cached.valid then
    return cached
  end

  -- Cache miss - need to search
  -- This is still expensive, but only happens once per entity
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{}) do
      if entity.valid and entity.unit_number == unit_number then
        -- Cache for next time
        connected_entity_cache[unit_number] = entity
        return entity
      end
    end
  end

  return nil
end

-- ==============================================================================
-- ENTITY LIFECYCLE
-- ==============================================================================

--- Handle logistics combinator built event
-- @param entity LuaEntity: The combinator entity
-- @param player LuaPlayer|nil: Player who built it (may be nil for robots)
function logistics_combinator.on_built(entity, player)
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  -- Register in global state - initialize data structure
  local unit_number = entity.unit_number
  if not unit_number then return end

  storage.logistics_combinators = storage.logistics_combinators or {}
  storage.logistics_combinators[unit_number] = {
    entity_unit_number = unit_number,
    surface_index = entity.surface.index,  -- Store for entity reconstruction
    position = entity.position,            -- Store for entity reconstruction
    conditions = {},  -- Array of {signal, operator, value, logic="AND"|"OR"}
    last_state = false,  -- Overall condition state for edge triggering
    connected_entities = {}
  }

  -- Cache entity immediately
  combinator_entity_cache[unit_number] = entity

  -- Initialize connected entities cache
  logistics_combinator.update_connected_entities(unit_number)

  log("Logistics combinator built: " .. unit_number)

  -- GUI opening will be handled by on_gui_opened event
end

--- Handle logistics combinator removed event
-- @param entity LuaEntity: The combinator entity
function logistics_combinator.on_removed(entity)
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  local unit_number = entity.unit_number

  -- Cleanup: Remove all groups injected by this combinator
  -- This also handles tracking cleanup internally
  logistics_combinator.cleanup_all_injected_groups(unit_number)

  -- Clear from entity cache
  combinator_entity_cache[unit_number] = nil

  -- Unregister from global state
  if storage.logistics_combinators then
    storage.logistics_combinators[unit_number] = nil
  end

  log("Logistics combinator removed: " .. unit_number)
end

-- ==============================================================================
-- CONNECTED ENTITY DETECTION
-- ==============================================================================

--- Find and cache all logistics-enabled entities connected to combinator output
-- Uses Factorio 2.0 LuaWireConnector API to traverse circuit connections
-- PERFORMANCE: Uses entity cache, O(1) lookup instead of O(n²) search
-- @param unit_number number: Combinator unit_number
function logistics_combinator.update_connected_entities(unit_number)
  if not storage.logistics_combinators then return end
  local combinator_data = storage.logistics_combinators[unit_number]
  if not combinator_data then return end

  -- Get the entity using cache (O(1) after first lookup)
  local entity = get_combinator_entity(unit_number)

  if not entity or not entity.valid then
    combinator_data.connected_entities = {}
    return
  end

  -- Use Factorio 2.0 API: get all wire connectors for this entity
  local wire_connectors = entity.get_wire_connectors(false)

  if not wire_connectors then
    combinator_data.connected_entities = {}
    return
  end

  -- Collect entities from all wire connections
  local entities_set = {}  -- Use set to avoid duplicates

  for connector_id, wire_connector in pairs(wire_connectors) do
    -- Iterate through all real connections (excluding ghost wires)
    local connections = wire_connector.real_connections

    if connections then
      for _, connected_wire_connector in pairs(connections) do
        local connected_entity = connected_wire_connector.owner

        -- Check if entity is valid and supports logistics control
        if connected_entity and connected_entity.valid and
           logistics_utils.supports_logistics_control(connected_entity) then
          entities_set[connected_entity.unit_number] = true
          -- Cache connected entities for later retrieval
          connected_entity_cache[connected_entity.unit_number] = connected_entity
        end
      end
    end
  end

  -- Convert set to array
  local entities_array = {}
  for unit_num in pairs(entities_set) do
    table.insert(entities_array, unit_num)
  end

  -- Only log if connections changed
  local old_count = combinator_data.connected_entities and #combinator_data.connected_entities or 0
  local new_count = #entities_array

  -- Cache in combinator data
  combinator_data.connected_entities = entities_array

  if old_count ~= new_count then
    log("Updated connected entities for combinator " .. unit_number .. ": " .. old_count .. " -> " .. new_count .. " entities")
  end
end

-- ==============================================================================
-- RULE PROCESSING
-- ==============================================================================

--- Process complex condition for a logistics combinator
-- Called every 15 ticks for active combinators
-- Implements edge-triggered behavior: only act on condition state changes
-- When condition becomes TRUE: inject ALL logistics sections into connected entities
-- When condition becomes FALSE: remove ALL injected sections from connected entities
-- PERFORMANCE: Uses entity cache, O(1) lookup instead of O(n²) search
-- @param unit_number number: Combinator unit_number
function logistics_combinator.process_rules(unit_number)
  if not storage.logistics_combinators then return end
  local combinator_data = storage.logistics_combinators[unit_number]
  if not combinator_data then return end

  -- Get the combinator entity using cache (O(1) after first lookup)
  local entity = get_combinator_entity(unit_number)

  if not entity or not entity.valid then return end

  -- Read input signals (merge red and green networks)
  local signals = {}

  -- Read red network
  local red_network = entity.get_circuit_network(defines.wire_connector_id.combinator_input_red)
  if red_network and red_network.signals then
    for _, signal_data in pairs(red_network.signals) do
      if signal_data and signal_data.signal and signal_data.count then
        local key = gui_utils.get_signal_key(signal_data.signal)
        if key ~= "" then
          signals[key] = (signals[key] or 0) + signal_data.count
        end
      end
    end
  end

  -- Read green network
  local green_network = entity.get_circuit_network(defines.wire_connector_id.combinator_input_green)
  if green_network and green_network.signals then
    for _, signal_data in pairs(green_network.signals) do
      if signal_data and signal_data.signal and signal_data.count then
        local key = gui_utils.get_signal_key(signal_data.signal)
        if key ~= "" then
          signals[key] = (signals[key] or 0) + signal_data.count
        end
      end
    end
  end

  -- Evaluate complex condition (with AND/OR logic)
  local overall_result = logistics_combinator.evaluate_complex_condition(signals, combinator_data.conditions)

  -- Edge-triggered: only act if state changed
  local state_changed = (overall_result ~= combinator_data.last_state)

  if state_changed then
    combinator_data.last_state = overall_result

    if overall_result then
      -- Condition became TRUE: inject ALL logistics sections
      logistics_combinator.inject_all_sections(entity, combinator_data, unit_number)
    else
      -- Condition became FALSE: remove ALL injected sections
      logistics_combinator.remove_all_sections(entity, combinator_data, unit_number)
    end
  end
end

--- Evaluate complex condition with AND/OR logic
-- @param signals table: Current signal values {[key] = count}
-- @param conditions table: Array of {signal, operator, value, logic}
-- @return boolean: True if overall condition met
function logistics_combinator.evaluate_complex_condition(signals, conditions)
  if not conditions or #conditions == 0 then return false end

  local result = true
  local next_logic = "AND"  -- Start with AND

  for i, condition in ipairs(conditions) do
    -- Evaluate this condition
    local cond_met = gui_utils.evaluate_condition(signals, condition)

    -- Apply previous logic operator
    if next_logic == "AND" then
      result = result and cond_met
    elseif next_logic == "OR" then
      result = result or cond_met
    end

    -- Set logic for next condition
    next_logic = condition.logic or "AND"
  end

  return result
end

--- Inject all logistics sections from combinator into connected entities
-- @param combinator_entity LuaEntity: The combinator entity
-- @param combinator_data table: Combinator data from storage
-- @param unit_number number: Combinator unit_number
function logistics_combinator.inject_all_sections(combinator_entity, combinator_data, unit_number)
  -- Get logistics sections from the combinator entity itself
  if not combinator_entity.logistic_sections then
    log("Combinator " .. unit_number .. " has no logistics sections to inject")
    return
  end

  local sections_to_inject = {}
  for section_index = 1, combinator_entity.logistic_sections.section_count do
    local section = combinator_entity.logistic_sections[section_index]
    if section and section.active then
      table.insert(sections_to_inject, section)
    end
  end

  if #sections_to_inject == 0 then
    log("Combinator " .. unit_number .. " has no active sections to inject")
    return
  end

  -- Inject into all connected entities
  local connected_entity_ids = combinator_data.connected_entities or {}
  local injected_count = 0

  for _, entity_id in ipairs(connected_entity_ids) do
    local target_entity = get_entity_by_unit_number(entity_id)

    if target_entity and target_entity.valid and target_entity.logistic_sections then
      for _, section in ipairs(sections_to_inject) do
        -- Copy the section to the target entity
        local new_section = target_entity.logistic_sections.add_section()
        if new_section then
          -- Copy section properties
          new_section.group = section.group
          new_section.active = section.active
          new_section.multiplier = section.multiplier

          -- Track injection
          storage.injected_groups = storage.injected_groups or {}
          storage.injected_groups[entity_id] = storage.injected_groups[entity_id] or {}
          storage.injected_groups[entity_id][new_section.index] = unit_number

          injected_count = injected_count + 1
        end
      end
    end
  end

  log("Injected " .. #sections_to_inject .. " sections into " .. #connected_entity_ids .. " entities (" .. injected_count .. " total sections)")
end

--- Remove all logistics sections injected by this combinator
-- @param combinator_entity LuaEntity: The combinator entity
-- @param combinator_data table: Combinator data from storage
-- @param unit_number number: Combinator unit_number
function logistics_combinator.remove_all_sections(combinator_entity, combinator_data, unit_number)
  local connected_entity_ids = combinator_data.connected_entities or {}
  local removed_count = 0

  for _, entity_id in ipairs(connected_entity_ids) do
    local target_entity = get_entity_by_unit_number(entity_id)

    if target_entity and target_entity.valid and target_entity.logistic_sections then
      local tracking = storage.injected_groups and storage.injected_groups[entity_id]
      if tracking then
        -- Remove sections injected by this combinator
        for section_idx, combinator_id in pairs(tracking) do
          if combinator_id == unit_number then
            target_entity.logistic_sections.remove_section(section_idx)
            tracking[section_idx] = nil
            removed_count = removed_count + 1
          end
        end

        -- Clean up empty tracking
        if not next(tracking) then
          storage.injected_groups[entity_id] = nil
        end
      end
    end
  end

  log("Removed " .. removed_count .. " injected sections from combinator " .. unit_number)
end

-- ==============================================================================
-- CLEANUP OPERATIONS
-- ==============================================================================

--- Remove all logistics groups injected by a specific combinator
-- Called when combinator is removed
-- @param combinator_unit_number number: Combinator unit_number
function logistics_combinator.cleanup_all_injected_groups(combinator_unit_number)
  local removed_count = logistics_utils.cleanup_combinator_groups(
    combinator_unit_number,
    storage.injected_groups
  )

  log("Cleaned up " .. removed_count .. " injected groups from combinator " .. combinator_unit_number)

  -- Clear tracking data
  for entity_id, sections in pairs(storage.injected_groups) do
    for section_idx, comb_id in pairs(sections) do
      if comb_id == combinator_unit_number then
        sections[section_idx] = nil
      end
    end

    -- Clean up empty entity tracking
    if not next(sections) then
      storage.injected_groups[entity_id] = nil
    end
  end
end

-- ==============================================================================
-- WIRE CONNECTION EVENTS
-- ==============================================================================

--- Handle wire added to combinator
-- Updates connected entities cache
-- @param entity LuaEntity: Entity that had wire added
function logistics_combinator.on_wire_added(entity)
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  -- Update connected entities cache
  logistics_combinator.update_connected_entities(entity.unit_number)
end

--- Handle wire removed from combinator
-- Updates connected entities cache
-- @param entity LuaEntity: Entity that had wire removed
function logistics_combinator.on_wire_removed(entity)
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  -- Update connected entities cache
  logistics_combinator.update_connected_entities(entity.unit_number)
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

-- Export cache clearing function for on_load
logistics_combinator.clear_entity_caches = clear_entity_caches

return logistics_combinator

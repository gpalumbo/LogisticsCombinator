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
-- - Global state storage (that's scripts/globals)

local logistics_combinator = {}

-- Load dependencies
local globals = require("scripts.globals")
local logistics_utils = require("lib.logistics_utils")
local gui_utils = require("lib.gui_utils")
local circuit_utils = require("lib.circuit_utils")
local signal_utils = require("lib.signal_utils")

-- GUI module will be loaded lazily to avoid circular dependencies
local logistics_gui = nil

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

  global.logistics_combinators = global.logistics_combinators or {}
  global.logistics_combinators[unit_number] = {
    entity_unit_number = unit_number,
    rules = {},
    connected_entities = {}
  }

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
  logistics_combinator.cleanup_all_injected_groups(unit_number)

  -- Unregister from global state
  if global.logistics_combinators then
    global.logistics_combinators[unit_number] = nil
  end

  -- Clean up injected groups tracking
  if global.injected_groups then
    for entity_id, sections in pairs(global.injected_groups) do
      for section_idx, comb_id in pairs(sections) do
        if comb_id == unit_number then
          sections[section_idx] = nil
        end
      end

      -- Clean up empty entity entries
      if not next(sections) then
        global.injected_groups[entity_id] = nil
      end
    end
  end

  log("Logistics combinator removed: " .. unit_number)
end

-- ==============================================================================
-- CONNECTED ENTITY DETECTION
-- ==============================================================================

--- Find and cache all logistics-enabled entities connected to combinator output
-- Uses Factorio's circuit_connected_entities API to find entities on output network
-- @param unit_number number: Combinator unit_number
function logistics_combinator.update_connected_entities(unit_number)
  if not global.logistics_combinators then return end
  local combinator_data = global.logistics_combinators[unit_number]
  if not combinator_data then return end

  -- Get the entity
  local entity = nil
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{
      name = "logistics-combinator",
      limit = 1000
    }
    for _, e in pairs(found) do
      if e.valid and e.unit_number == unit_number then
        entity = e
        break
      end
    end
    if entity then break end
  end

  if not entity or not entity.valid then
    combinator_data.connected_entities = {}
    return
  end

  -- Get all circuit-connected entities
  local connected = entity.circuit_connected_entities

  if not connected then
    combinator_data.connected_entities = {}
    return
  end

  -- Collect entities from both red and green networks
  local entities_set = {}  -- Use set to avoid duplicates

  for _, e in pairs(connected.red or {}) do
    if e.valid and logistics_utils.supports_logistics_control(e) then
      entities_set[e.unit_number] = true
    end
  end

  for _, e in pairs(connected.green or {}) do
    if e.valid and logistics_utils.supports_logistics_control(e) then
      entities_set[e.unit_number] = true
    end
  end

  -- Convert set to array
  local entities_array = {}
  for unit_num in pairs(entities_set) do
    table.insert(entities_array, unit_num)
  end

  -- Cache in combinator data
  combinator_data.connected_entities = entities_array

  log("Updated connected entities for combinator " .. unit_number .. ": " .. #entities_array .. " entities")
end

-- ==============================================================================
-- RULE PROCESSING
-- ==============================================================================

--- Process all rules for a logistics combinator
-- Called every 15 ticks for active combinators
-- Implements edge-triggered behavior: only act on condition state changes
-- @param unit_number number: Combinator unit_number
function logistics_combinator.process_rules(unit_number)
  if not global.logistics_combinators then return end
  local combinator_data = global.logistics_combinators[unit_number]
  if not combinator_data then return end

  -- Get the combinator entity
  local entity = nil
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{
      name = "logistics-combinator",
      limit = 1000
    }
    for _, e in pairs(found) do
      if e.valid and e.unit_number == unit_number then
        entity = e
        break
      end
    end
    if entity then break end
  end

  if not entity or not entity.valid then return end

  -- Read input signals (merge red and green)
  local merged_signals = entity.get_merged_signals(defines.circuit_connector_id.combinator_input)

  -- Convert to signal lookup table
  local signals = {}
  if merged_signals then
    for _, signal_data in pairs(merged_signals) do
      if signal_data.signal and signal_data.count then
        local key = gui_utils.get_signal_key(signal_data.signal)
        signals[key] = signal_data.count
      end
    end
  end

  -- Get connected entities
  local connected_entity_ids = combinator_data.connected_entities or {}

  -- Process each rule
  for rule_idx, rule in ipairs(combinator_data.rules) do
    -- Evaluate condition
    local condition_met = gui_utils.evaluate_condition(signals, rule.condition)

    -- Edge-triggered: only act if state changed
    local state_changed = (condition_met ~= rule.last_state)

    if state_changed then
      rule.last_state = condition_met

      -- Only act when condition becomes true
      if condition_met then
        logistics_combinator.execute_rule(rule, connected_entity_ids, unit_number)
      end
    end
  end
end

--- Execute a single rule on all connected entities
-- @param rule table: Rule definition
-- @param connected_entity_ids table: Array of entity unit_numbers
-- @param combinator_unit_number number: Combinator that owns this rule
function logistics_combinator.execute_rule(rule, connected_entity_ids, combinator_unit_number)
  if not rule or not rule.group_name or not rule.action then return end

  -- Find all connected entities
  for _, entity_id in ipairs(connected_entity_ids) do
    local entity = nil

    -- Find entity by unit_number
    for _, surface in pairs(game.surfaces) do
      local all_entities = surface.find_entities_filtered{limit = 10000}
      for _, e in pairs(all_entities) do
        if e.valid and e.unit_number == entity_id then
          entity = e
          break
        end
      end
      if entity then break end
    end

    if entity and entity.valid and logistics_utils.supports_logistics_control(entity) then
      if rule.action == "inject" then
        -- Check if group already exists
        local has_group, section_idx = logistics_utils.has_logistics_group(entity, rule.group_name)

        if not has_group then
          -- Inject the group
          local new_section_idx, err = logistics_utils.inject_logistics_group(
            entity,
            rule.group_name,
            combinator_unit_number
          )

          if new_section_idx then
            -- Track the injection
            global.injected_groups = global.injected_groups or {}
            global.injected_groups[entity_id] = global.injected_groups[entity_id] or {}
            global.injected_groups[entity_id][new_section_idx] = combinator_unit_number

            log("Injected group '" .. rule.group_name .. "' into entity " .. entity_id .. " at section " .. new_section_idx)
          else
            log("Failed to inject group: " .. tostring(err))
          end
        end

      elseif rule.action == "remove" then
        -- Remove the group (only if injected by this combinator)
        local tracking = (global.injected_groups and global.injected_groups[entity_id]) or {}
        local removed, count = logistics_utils.remove_logistics_group(
          entity,
          rule.group_name,
          combinator_unit_number,
          tracking
        )

        if removed then
          log("Removed " .. count .. " sections of group '" .. rule.group_name .. "' from entity " .. entity_id)
          -- Note: tracking data cleanup happens in logistics_utils
        end
      end
    end
  end
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
    global.injected_groups
  )

  log("Cleaned up " .. removed_count .. " injected groups from combinator " .. combinator_unit_number)

  -- Clear tracking data
  for entity_id, sections in pairs(global.injected_groups) do
    for section_idx, comb_id in pairs(sections) do
      if comb_id == combinator_unit_number then
        sections[section_idx] = nil
      end
    end

    -- Clean up empty entity tracking
    if not next(sections) then
      global.injected_groups[entity_id] = nil
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

return logistics_combinator

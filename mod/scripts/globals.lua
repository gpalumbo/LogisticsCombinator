-- globals.lua
-- Mission Control Mod - Global State Management
--
-- PURPOSE:
-- Centralized management of global state tables. This module ONLY handles
-- data structure initialization and access - it does NOT contain business logic.
--
-- RESPONSIBILITIES:
-- - Initialize global tables
-- - Provide accessors for global state
-- - Entity registration/unregistration
-- - Migration support
--
-- DOES NOT OWN:
-- - Business logic (that's in entity scripts)
-- - Event handling (that's in entity scripts and control.lua)
-- - Signal processing
-- - GUI creation

local globals = {}

-- ==============================================================================
-- GLOBAL STATE STRUCTURE
-- ==============================================================================

--[[
  global = {
    -- Logistics Combinator state
    logistics_combinators = {
      [combinator_unit_number] = {
        entity_unit_number = number,
        rules = {  -- Array of rules
          {
            group_name = string,
            condition = {signal = {type, name}, operator = string, value = number},
            action = "inject" | "remove",
            last_state = boolean  -- For edge-triggering
          },
          ...
        },
        connected_entities = {unit_number1, unit_number2, ...},  -- Cached entities on output network
      }
    },

    -- Track which groups were injected by which combinator
    injected_groups = {
      [entity_unit_number] = {
        [section_index] = combinator_unit_number  -- Which combinator injected this section
      }
    },

    -- GUI state per player
    gui_state = {
      [player_index] = {
        open_gui = string,  -- "logistics_combinator" or nil
        open_entity = number  -- unit_number of entity with open GUI
      }
    }
  }
--]]

-- ==============================================================================
-- INITIALIZATION
-- ==============================================================================

--- Initialize all global tables
-- Called on_init and on_configuration_changed
function globals.init_globals()
  global.logistics_combinators = global.logistics_combinators or {}
  global.injected_groups = global.injected_groups or {}
  global.gui_state = global.gui_state or {}

  log("Mission Control: Global state initialized")
end

-- ==============================================================================
-- LOGISTICS COMBINATOR REGISTRATION
-- ==============================================================================

--- Register a logistics combinator entity
-- @param entity LuaEntity: Logistics combinator entity
-- @return table: Created combinator data
function globals.register_logistics_combinator(entity)
  if not entity or not entity.valid then
    error("Cannot register invalid entity")
  end

  if entity.name ~= "logistics-combinator" then
    error("Attempted to register non-logistics-combinator entity: " .. entity.name)
  end

  local unit_number = entity.unit_number
  if not unit_number then
    error("Entity has no unit_number")
  end

  -- Initialize combinator data structure
  global.logistics_combinators[unit_number] = {
    entity_unit_number = unit_number,
    rules = {},
    connected_entities = {}
  }

  log("Registered logistics combinator: " .. unit_number)

  return global.logistics_combinators[unit_number]
end

--- Unregister a logistics combinator entity
-- @param unit_number number: Combinator unit_number
function globals.unregister_logistics_combinator(unit_number)
  if not unit_number then return end

  -- Remove combinator data
  global.logistics_combinators[unit_number] = nil

  -- Clean up injected groups tracking
  -- Remove all references to this combinator from injected_groups
  for entity_id, sections in pairs(global.injected_groups) do
    for section_idx, combinator_id in pairs(sections) do
      if combinator_id == unit_number then
        sections[section_idx] = nil
      end
    end

    -- Clean up empty entity entries
    if not next(sections) then
      global.injected_groups[entity_id] = nil
    end
  end

  log("Unregistered logistics combinator: " .. unit_number)
end

--- Get logistics combinator data
-- @param unit_number number: Combinator unit_number
-- @return table|nil: Combinator data or nil if not found
function globals.get_logistics_combinator(unit_number)
  if not unit_number then return nil end
  return global.logistics_combinators[unit_number]
end

-- ==============================================================================
-- RULE MANAGEMENT
-- ==============================================================================

--- Add a rule to a logistics combinator
-- @param unit_number number: Combinator unit_number
-- @param rule table: Rule definition {group_name, condition, action}
function globals.add_logistics_rule(unit_number, rule)
  local combinator = globals.get_logistics_combinator(unit_number)
  if not combinator then
    error("Combinator not found: " .. tostring(unit_number))
  end

  -- Initialize last_state for edge triggering
  rule.last_state = false

  table.insert(combinator.rules, rule)

  log("Added rule to combinator " .. unit_number .. ": " .. rule.group_name)
end

--- Remove a rule from a logistics combinator
-- @param unit_number number: Combinator unit_number
-- @param rule_index number: Index of rule to remove (1-based)
function globals.remove_logistics_rule(unit_number, rule_index)
  local combinator = globals.get_logistics_combinator(unit_number)
  if not combinator then return end

  if rule_index > 0 and rule_index <= #combinator.rules then
    table.remove(combinator.rules, rule_index)
    log("Removed rule " .. rule_index .. " from combinator " .. unit_number)
  end
end

--- Update a rule in a logistics combinator
-- @param unit_number number: Combinator unit_number
-- @param rule_index number: Index of rule to update (1-based)
-- @param rule table: New rule definition
function globals.update_logistics_rule(unit_number, rule_index, rule)
  local combinator = globals.get_logistics_combinator(unit_number)
  if not combinator then return end

  if rule_index > 0 and rule_index <= #combinator.rules then
    -- Preserve last_state for edge triggering
    rule.last_state = combinator.rules[rule_index].last_state or false
    combinator.rules[rule_index] = rule
    log("Updated rule " .. rule_index .. " in combinator " .. unit_number)
  end
end

-- ==============================================================================
-- CONNECTED ENTITIES CACHE
-- ==============================================================================

--- Update connected entities cache for a combinator
-- @param unit_number number: Combinator unit_number
-- @param entities table: Array of entity unit_numbers
function globals.set_connected_entities(unit_number, entities)
  local combinator = globals.get_logistics_combinator(unit_number)
  if not combinator then return end

  combinator.connected_entities = entities or {}
end

--- Get connected entities for a combinator
-- @param unit_number number: Combinator unit_number
-- @return table: Array of entity unit_numbers
function globals.get_connected_entities(unit_number)
  local combinator = globals.get_logistics_combinator(unit_number)
  if not combinator then return {} end

  return combinator.connected_entities or {}
end

-- ==============================================================================
-- INJECTED GROUPS TRACKING
-- ==============================================================================

--- Track an injected logistics group
-- @param entity_unit_number number: Entity that received the group
-- @param section_index number: Index of the injected section
-- @param combinator_unit_number number: Combinator that injected it
function globals.track_injected_group(entity_unit_number, section_index, combinator_unit_number)
  if not global.injected_groups[entity_unit_number] then
    global.injected_groups[entity_unit_number] = {}
  end

  global.injected_groups[entity_unit_number][section_index] = combinator_unit_number
end

--- Get injected groups tracking data for an entity
-- @param entity_unit_number number: Entity unit_number
-- @return table: Tracking data {[section_index] = combinator_unit_number}
function globals.get_injected_groups(entity_unit_number)
  return global.injected_groups[entity_unit_number] or {}
end

--- Clear all injected groups tracking for an entity
-- @param entity_unit_number number: Entity unit_number
function globals.clear_entity_injected_groups(entity_unit_number)
  global.injected_groups[entity_unit_number] = nil
end

-- ==============================================================================
-- GUI STATE MANAGEMENT
-- ==============================================================================

--- Set GUI state for a player
-- @param player_index number: Player index
-- @param gui_name string|nil: Name of open GUI
-- @param entity_unit_number number|nil: Unit number of entity with open GUI
function globals.set_gui_state(player_index, gui_name, entity_unit_number)
  if not global.gui_state[player_index] then
    global.gui_state[player_index] = {}
  end

  global.gui_state[player_index].open_gui = gui_name
  global.gui_state[player_index].open_entity = entity_unit_number
end

--- Get GUI state for a player
-- @param player_index number: Player index
-- @return table: GUI state {open_gui, open_entity}
function globals.get_gui_state(player_index)
  return global.gui_state[player_index] or {open_gui = nil, open_entity = nil}
end

--- Clear GUI state for a player
-- @param player_index number: Player index
function globals.clear_gui_state(player_index)
  global.gui_state[player_index] = nil
end

-- ==============================================================================
-- MIGRATION SUPPORT
-- ==============================================================================

--- Migrate global state from old version to new version
-- @param old_version string: Old mod version
-- @param new_version string: New mod version
function globals.migrate_globals(old_version, new_version)
  log("Migrating Mission Control mod from " .. tostring(old_version) .. " to " .. tostring(new_version))

  -- Initialize any missing tables
  globals.init_globals()

  -- Add version-specific migrations here as mod evolves
  -- Example:
  -- if old_version == "0.1.0" and new_version == "0.2.0" then
  --   -- Perform specific migration
  -- end
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

return globals

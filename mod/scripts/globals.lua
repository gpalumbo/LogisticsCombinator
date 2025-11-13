-- globals.lua
-- Mission Control Mod - Global State Management
--
-- PURPOSE:
-- Centralized initialization and access patterns for global state.
-- This module provides ONLY data structure initialization and basic accessors.
-- Entity-specific data manipulation is done in entity modules.
--
-- RESPONSIBILITIES:
-- - Initialize global tables
-- - Provide basic accessors for global state
-- - Migration support
--
-- DOES NOT OWN:
-- - Business logic (that's in entity scripts)
-- - Entity-specific data manipulation (that's in entity scripts)
-- - Event handling
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
-- BASIC ACCESSORS
-- ==============================================================================

--- Get logistics combinator data
-- @param unit_number number: Combinator unit_number
-- @return table|nil: Combinator data or nil if not found
function globals.get_logistics_combinator(unit_number)
  if not unit_number or not global.logistics_combinators then return nil end
  return global.logistics_combinators[unit_number]
end

-- ==============================================================================
-- GUI STATE MANAGEMENT
-- ==============================================================================

--- Set GUI state for a player
-- @param player_index number: Player index
-- @param gui_name string|nil: Name of open GUI
-- @param entity_unit_number number|nil: Unit number of entity with open GUI
function globals.set_gui_state(player_index, gui_name, entity_unit_number)
  if not global.gui_state then
    global.gui_state = {}
  end

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
  if not global.gui_state or not global.gui_state[player_index] then
    return {open_gui = nil, open_entity = nil}
  end
  return global.gui_state[player_index]
end

--- Clear GUI state for a player
-- @param player_index number: Player index
function globals.clear_gui_state(player_index)
  if not global.gui_state then return end
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

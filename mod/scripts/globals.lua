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
    }
  }

  NOTE: GUI state is NOT tracked in global. Instead, GUI elements use tags
  to store entity references (element.tags.entity_unit_number).
--]]

-- ==============================================================================
-- INITIALIZATION
-- ==============================================================================

--- Initialize all global tables
-- Called on_init and on_configuration_changed
function globals.init_globals()
  global.logistics_combinators = global.logistics_combinators or {}
  global.injected_groups = global.injected_groups or {}

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

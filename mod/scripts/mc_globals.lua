-- mc_globals.lua
-- Mission Control Mod - Global State Management
--
-- PURPOSE:
-- Centralized initialization and access patterns for Factorio's storage table.
-- This module provides ONLY data structure initialization and basic accessors.
-- Entity-specific data manipulation is done in entity modules.
--
-- NAMING: "mc_globals" (module name) manages "storage" (Factorio 2.0 persistent table)
-- NOTE: In Factorio 2.0, the persistent table was renamed from "global" to "storage"
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

local mc_globals = {}

-- ==============================================================================
-- GLOBAL STATE STRUCTURE
-- ==============================================================================

--[[
  storage = {
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

  NOTE: GUI state is NOT tracked in storage. Instead, GUI elements use tags
  to store entity references (element.tags.entity_unit_number).
  NOTE: In Factorio 2.0, "global" was renamed to "storage" for persistent data.
--]]

-- ==============================================================================
-- INITIALIZATION
-- ==============================================================================

--- Initialize all storage tables
-- Called on_init and on_configuration_changed
function mc_globals.init_globals()
  storage.logistics_combinators = storage.logistics_combinators or {}
  storage.injected_groups = storage.injected_groups or {}

  log("Mission Control: Storage initialized")
end

-- ==============================================================================
-- BASIC ACCESSORS
-- ==============================================================================

--- Get logistics combinator data
-- @param unit_number number: Combinator unit_number
-- @return table|nil: Combinator data or nil if not found
function mc_globals.get_logistics_combinator(unit_number)
  if not unit_number or not storage.logistics_combinators then return nil end
  return storage.logistics_combinators[unit_number]
end

-- ==============================================================================
-- MIGRATION SUPPORT
-- ==============================================================================

--- Migrate storage state from old version to new version
-- @param old_version string: Old mod version
-- @param new_version string: New mod version
function mc_globals.migrate_globals(old_version, new_version)
  log("Migrating Mission Control mod from " .. tostring(old_version) .. " to " .. tostring(new_version))

  -- Initialize any missing tables
  mc_globals.init_globals()

  -- Add version-specific migrations here as mod evolves
  -- Example:
  -- if old_version == "0.1.0" and new_version == "0.2.0" then
  --   -- Perform specific migration
  -- end
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

return mc_globals

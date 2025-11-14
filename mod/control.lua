-- control.lua
-- Mission Control Mod - Main Control Script
--
-- This file is loaded during Factorio's control phase and is responsible for
-- handling all runtime events and coordinating between different modules.

-- ==============================================================================
-- IMPORTS
-- ==============================================================================

local mc_globals = require("scripts.mc_globals")
local logistics_combinator = require("scripts.logistics_combinator.init")
local gui_handlers = require("scripts.gui_handlers")

-- ==============================================================================
-- INITIALIZATION
-- ==============================================================================

--- Initialize mod on first load or when added to existing save
script.on_init(function()
  log("Mission Control mod: Initializing...")
  mc_globals.init_globals()
  log("Mission Control mod: Initialization complete")
end)

--- Handle configuration changes (mod updates, mod list changes)
script.on_configuration_changed(function(data)
  log("Mission Control mod: Configuration changed")

  -- Get old and new versions
  local mod_changes = data.mod_changes and data.mod_changes["mission-control"]
  local old_version = mod_changes and mod_changes.old_version
  local new_version = mod_changes and mod_changes.new_version

  -- Migrate if needed
  if old_version and new_version then
    mc_globals.migrate_globals(old_version, new_version)
  else
    -- Ensure globals are initialized
    mc_globals.init_globals()
  end

  log("Mission Control mod: Configuration change handled")
end)

--- Restore runtime state on load
script.on_load(function()
  -- Clear entity caches (they are rebuilt on first access)
  logistics_combinator.clear_entity_caches()

  -- This function is for registering metatables and conditional event handlers
  log("Mission Control mod: Runtime state restored, caches cleared")
end)

-- ==============================================================================
-- ENTITY LIFECYCLE EVENTS
-- ==============================================================================

--- Handle entity built by player
script.on_event(defines.events.on_built_entity, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  local player = event.player_index and game.players[event.player_index]

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_built(entity, player)
  end
end)

--- Handle entity built by robot
script.on_event(defines.events.on_robot_built_entity, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_built(entity, nil)
  end
end)

--- Handle entity built via script
script.on_event(defines.events.script_raised_built, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_built(entity, nil)
  end
end)

--- Handle entity mined by player
script.on_event(defines.events.on_player_mined_entity, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_removed(entity)
  end
end)

--- Handle entity mined by robot
script.on_event(defines.events.on_robot_mined_entity, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_removed(entity)
  end
end)

--- Handle entity destroyed
script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_removed(entity)
  end
end)

--- Handle entity destroyed via script
script.on_event(defines.events.script_raised_destroy, function(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    logistics_combinator.on_removed(entity)
  end
end)

-- ==============================================================================
-- CIRCUIT WIRE EVENTS
-- ==============================================================================

--[[
  IMPORTANT: Wire connection/disconnection events DO NOT EXIST in Factorio's API!

  Events like on_wire_created, on_wire_removed, on_wire_added, on_wire_disconnected
  were NEVER part of the official API. This has been a long-standing feature request
  since 2017, but Factorio developers have rejected it because connecting/disconnecting
  networks destroys and recreates networks, which would trigger cascading events.

  SOLUTION: We use POLLING instead
  - Connection discovery: on_nth_tick(60) checks for new wire connections every second
  - Rule processing: on_tick processes rules and checks connections when conditions change

  See: https://forums.factorio.com/viewtopic.php?t=46375
--]]

-- ==============================================================================
-- GUI EVENTS
-- ==============================================================================

--- Handle GUI opened
script.on_event(defines.events.on_gui_opened, function(event)
  gui_handlers.on_gui_opened(event)
end)

--- Handle GUI closed
script.on_event(defines.events.on_gui_closed, function(event)
  gui_handlers.on_gui_closed(event)
end)

--- Handle GUI click
script.on_event(defines.events.on_gui_click, function(event)
  gui_handlers.on_gui_click(event)
end)

--- Handle GUI element changed (dropdowns, checkboxes, etc.)
script.on_event(defines.events.on_gui_elem_changed, function(event)
  gui_handlers.on_gui_elem_changed(event)
end)

--- Handle GUI text changed (textfields)
script.on_event(defines.events.on_gui_text_changed, function(event)
  gui_handlers.on_gui_text_changed(event)
end)

--- Handle GUI selection state changed (dropdowns)
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  gui_handlers.on_gui_selection_state_changed(event)
end)

-- ==============================================================================
-- PERIODIC UPDATES
-- ==============================================================================

--- Process logistics combinator conditions every 15 ticks (like vanilla combinators poll interval)
-- This handles condition evaluation and logistics section injection/removal
-- PERFORMANCE: Only processes combinators with conditions, uses entity cache for O(1) lookups
script.on_nth_tick(15, function(event)
  -- Process all registered logistics combinators
  for unit_number, combinator_data in pairs(storage.logistics_combinators or {}) do
    -- Only process if combinator has conditions
    if combinator_data.conditions and #combinator_data.conditions > 0 then
      logistics_combinator.process_rules(unit_number)
    end
  end
end)

--- Update connected entities for all combinators every 60 ticks (once per second)
-- This is our wire change detection mechanism since Factorio has no wire events
-- PERFORMANCE: Polling interval chosen to balance responsiveness vs UPS impact
script.on_nth_tick(60, function(event)
  -- Update connections for all registered logistics combinators
  for unit_number, combinator_data in pairs(storage.logistics_combinators or {}) do
    logistics_combinator.update_connected_entities(unit_number)
  end
end)

-- ==============================================================================
-- REMOTE INTERFACE (optional, for debugging and integration)
-- ==============================================================================

remote.add_interface("mission_control", {
  --- Get version of Mission Control mod
  get_version = function()
    return game.active_mods["mission-control"]
  end,

  --- Get combinator data for debugging
  -- @param unit_number number: Combinator unit_number
  -- @return table: Combinator data or nil
  get_combinator_data = function(unit_number)
    return mc_globals.get_logistics_combinator(unit_number)
  end,

  --- Force update connected entities for a combinator
  -- @param unit_number number: Combinator unit_number
  force_update_connections = function(unit_number)
    logistics_combinator.update_connected_entities(unit_number)
  end,

  --- Force process rules for a combinator
  -- @param unit_number number: Combinator unit_number
  force_process_rules = function(unit_number)
    logistics_combinator.process_rules(unit_number)
  end
})

-- ==============================================================================
-- LOGGING
-- ==============================================================================

log("Mission Control mod: Control script loaded successfully")

-- gui_handlers.lua
-- Mission Control Mod - GUI Event Dispatcher
--
-- PURPOSE:
-- Central dispatcher for GUI events. Routes events to entity-specific GUI modules.
-- When more entity types are added (Mission Control, Receiver Combinator), their
-- GUI handlers will be imported and routed through this file.
--
-- RESPONSIBILITIES:
-- - Route GUI events to appropriate entity-specific handlers
-- - Provide unified interface for control.lua
--
-- DOES NOT OWN:
-- - Entity-specific GUI creation (that's in entity subdirectories)
-- - GUI state storage (that's scripts/globals)
-- - Entity business logic

local gui_handlers = {}

-- Load entity-specific GUI modules
local logistics_gui = require("scripts.logistics_combinator.gui")

-- Future imports for other entity types:
-- local mission_control_gui = require("scripts.mission_control.gui")
-- local receiver_gui = require("scripts.receiver_combinator.gui")

-- ==============================================================================
-- EVENT DISPATCHERS
-- ==============================================================================

--- Handle GUI opened event
-- Routes to appropriate entity-specific handler based on entity type
-- @param event EventData: on_gui_opened event
function gui_handlers.on_gui_opened(event)
  local player = game.players[event.player_index]
  local entity = event.entity

  if not entity or not entity.valid then return end

  -- Route to entity-specific handler
  if entity.name == "logistics-combinator" then
    logistics_gui.on_opened(player, entity)
  end

  -- Future entity types:
  -- elseif entity.name == "mission-control-building" then
  --   mission_control_gui.on_opened(player, entity)
  -- elseif entity.name == "receiver-combinator" then
  --   receiver_gui.on_opened(player, entity)
  -- end
end

--- Handle GUI closed event
-- Routes to appropriate entity-specific handler
-- @param event EventData: on_gui_closed event
function gui_handlers.on_gui_closed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Route to entity-specific handler based on GUI element
  -- Logistics combinator GUI
  logistics_gui.on_closed(player, element)

  -- Future entity types will check their own GUI element names
end

--- Handle GUI click event
-- Routes to appropriate handler based on event
-- @param event EventData: on_gui_click event
function gui_handlers.on_gui_click(event)
  -- Route to entity-specific handlers
  -- Each handler checks if the event is relevant to it
  logistics_gui.on_click(event)

  -- Future handlers will check their own elements:
  -- mission_control_gui.on_click(event)
  -- receiver_gui.on_click(event)
end

--- Handle GUI element changed event
-- Routes to appropriate handler
-- @param event EventData: on_gui_elem_changed event
function gui_handlers.on_gui_elem_changed(event)
  -- Route to entity-specific handlers
  logistics_gui.on_elem_changed(event)

  -- Future handlers:
  -- mission_control_gui.on_elem_changed(event)
  -- receiver_gui.on_elem_changed(event)
end

--- Handle GUI text changed event
-- Routes to appropriate handler
-- @param event EventData: on_gui_text_changed event
function gui_handlers.on_gui_text_changed(event)
  -- Route to entity-specific handlers
  logistics_gui.on_text_changed(event)

  -- Future handlers:
  -- mission_control_gui.on_text_changed(event)
  -- receiver_gui.on_text_changed(event)
end

--- Handle GUI selection state changed event
-- Routes to appropriate handler
-- @param event EventData: on_gui_selection_state_changed event
function gui_handlers.on_gui_selection_state_changed(event)
  -- Route to entity-specific handlers
  logistics_gui.on_selection_changed(event)

  -- Future handlers:
  -- mission_control_gui.on_selection_changed(event)
  -- receiver_gui.on_selection_changed(event)
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

return gui_handlers

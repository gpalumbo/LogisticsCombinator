-- gui_handlers.lua
-- Mission Control Mod - GUI Event Handlers
--
-- PURPOSE:
-- Handle all GUI events and create entity-specific GUIs.
-- This module creates GUIs and routes events, but delegates business logic
-- to entity scripts and generic operations to gui_utils.
--
-- RESPONSIBILITIES:
-- - Entity-specific GUI creation (logistics combinator)
-- - GUI event routing and handling
-- - GUI state updates
-- - GUI open/close logic
--
-- DOES NOT OWN:
-- - Generic GUI components (that's lib/gui_utils)
-- - GUI state storage (that's scripts/globals)
-- - Entity business logic (that's scripts/logistics_combinator)

local gui_handlers = {}

-- Load dependencies
local globals = require("scripts.globals")
local gui_utils = require("lib.gui_utils")
local logistics_combinator = require("scripts.logistics_combinator")

-- ==============================================================================
-- GUI ELEMENT NAMES (for event routing)
-- ==============================================================================

local GUI_NAMES = {
  LOGISTICS_MAIN = "mission_control_logistics_gui",
  LOGISTICS_CLOSE = "logistics_close",
  LOGISTICS_ADD_RULE = "logistics_add_rule",
  LOGISTICS_RULE_PREFIX = "logistics_rule_",  -- Followed by rule index
  LOGISTICS_DELETE_RULE = "logistics_delete_rule_",  -- Followed by rule index
  LOGISTICS_GROUP_PICKER = "logistics_group_",  -- Followed by rule index
  LOGISTICS_ACTION_INJECT = "logistics_action_inject_",  -- Followed by rule index
  LOGISTICS_ACTION_REMOVE = "logistics_action_remove_"  -- Followed by rule index
}

-- ==============================================================================
-- LOGISTICS COMBINATOR GUI
-- ==============================================================================

--- Create logistics combinator GUI for a player
-- @param player LuaPlayer: Player to create GUI for
-- @param entity LuaEntity: Logistics combinator entity
function gui_handlers.create_logistics_gui(player, entity)
  if not player or not player.valid then return end
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  -- Close any existing GUI
  gui_handlers.close_logistics_gui(player)

  -- Get combinator data
  local combinator_data = globals.get_logistics_combinator(entity.unit_number)
  if not combinator_data then return end

  -- Create main GUI window
  local main_frame = player.gui.screen.add{
    type = "frame",
    name = GUI_NAMES.LOGISTICS_MAIN,
    direction = "vertical"
  }

  -- Create titlebar
  gui_utils.create_titlebar(
    main_frame,
    {"entity-name.logistics-combinator"},
    GUI_NAMES.LOGISTICS_CLOSE
  )

  -- Main content flow
  local content_flow = main_frame.add{
    type = "flow",
    direction = "vertical"
  }
  content_flow.style.padding = gui_utils.GUI_CONSTANTS.PADDING
  content_flow.style.vertical_spacing = gui_utils.GUI_CONSTANTS.SPACING

  -- Header label
  content_flow.add{
    type = "label",
    caption = {"logistics-combinator.circuit-controlled-groups"},
    style = "bold_label"
  }

  -- Add rule button
  local add_button_flow = content_flow.add{
    type = "flow",
    direction = "horizontal"
  }
  add_button_flow.add{
    type = "button",
    name = GUI_NAMES.LOGISTICS_ADD_RULE,
    caption = {"logistics-combinator.add-rule"},
    tooltip = {"logistics-combinator.add-rule-tooltip"}
  }

  -- Rules list
  local rules_scroll = content_flow.add{
    type = "scroll-pane",
    direction = "vertical"
  }
  rules_scroll.style.maximal_height = 400
  rules_scroll.style.minimal_width = 500

  local rules_list = rules_scroll.add{
    type = "flow",
    name = "rules_list",
    direction = "vertical"
  }
  rules_list.style.vertical_spacing = gui_utils.GUI_CONSTANTS.SPACING

  -- Populate existing rules
  for rule_idx, rule in ipairs(combinator_data.rules) do
    gui_handlers.add_rule_to_gui(rules_list, rule_idx, rule)
  end

  -- Connected entities count
  local connected_count = #(combinator_data.connected_entities or {})
  content_flow.add{
    type = "label",
    caption = {"logistics-combinator.connected-entities", connected_count}
  }

  -- Center GUI on screen
  main_frame.force_auto_center()

  -- Store GUI state
  globals.set_gui_state(player.index, "logistics_combinator", entity.unit_number)
end

--- Add a rule display to the GUI
-- @param parent LuaGuiElement: Parent container
-- @param rule_index number: Index of this rule (1-based)
-- @param rule table: Rule definition
function gui_handlers.add_rule_to_gui(parent, rule_index, rule)
  local rule_frame = parent.add{
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame"
  }

  local rule_flow = rule_frame.add{
    type = "flow",
    direction = "horizontal"
  }
  rule_flow.style.horizontal_spacing = gui_utils.GUI_CONSTANTS.SPACING
  rule_flow.style.vertical_align = "center"

  -- Rule number label
  rule_flow.add{
    type = "label",
    caption = tostring(rule_index) .. "."
  }

  -- Logistics group picker
  rule_flow.add{
    type = "label",
    caption = {"logistics-combinator.group-label"}
  }

  local group_picker = rule_flow.add{
    type = "choose-elem-button",
    name = GUI_NAMES.LOGISTICS_GROUP_PICKER .. rule_index,
    elem_type = "logistic-group",
    tooltip = {"logistics-combinator.select-group-tooltip"}
  }

  -- Set current group if available
  if rule.group_name then
    group_picker.elem_value = rule.group_name
  end

  -- Condition builder
  rule_flow.add{
    type = "label",
    caption = {"logistics-combinator.when-label"}
  }

  local condition_widgets = gui_utils.create_condition_selector(
    rule_flow,
    GUI_NAMES.LOGISTICS_RULE_PREFIX .. rule_index .. "_"
  )

  -- Set current condition values
  if rule.condition then
    if rule.condition.signal then
      condition_widgets.signal_chooser.elem_value = rule.condition.signal
    end
    if rule.condition.operator then
      local op_index = gui_utils.get_index_from_operator(rule.condition.operator)
      condition_widgets.operator_dropdown.selected_index = op_index
    end
    if rule.condition.value then
      condition_widgets.value_field.text = tostring(rule.condition.value)
    end
  end

  -- Action radio buttons
  local action_flow = rule_flow.add{
    type = "flow",
    direction = "horizontal"
  }
  action_flow.style.horizontal_spacing = 4

  action_flow.add{
    type = "radiobutton",
    name = GUI_NAMES.LOGISTICS_ACTION_INJECT .. rule_index,
    caption = {"logistics-combinator.inject"},
    state = (rule.action == "inject"),
    tooltip = {"logistics-combinator.inject-tooltip"}
  }

  action_flow.add{
    type = "radiobutton",
    name = GUI_NAMES.LOGISTICS_ACTION_REMOVE .. rule_index,
    caption = {"logistics-combinator.remove"},
    state = (rule.action == "remove"),
    tooltip = {"logistics-combinator.remove-tooltip"}
  }

  -- Delete button
  rule_flow.add{
    type = "sprite-button",
    name = GUI_NAMES.LOGISTICS_DELETE_RULE .. rule_index,
    sprite = "utility/trash",
    style = "tool_button_red",
    tooltip = {"logistics-combinator.delete-rule"}
  }

  -- Status indicator (active/inactive based on last_state)
  local status_text = rule.last_state and "[img=utility/status_working]" or "[img=utility/status_not_working]"
  rule_frame.add{
    type = "label",
    caption = status_text .. " " .. (rule.last_state and {"logistics-combinator.active"} or {"logistics-combinator.inactive"})
  }
end

--- Close logistics combinator GUI for a player
-- @param player LuaPlayer: Player whose GUI to close
function gui_handlers.close_logistics_gui(player)
  if not player or not player.valid then return end

  gui_utils.close_gui_for_player(player, GUI_NAMES.LOGISTICS_MAIN)
  globals.clear_gui_state(player.index)
end

-- ==============================================================================
-- EVENT HANDLERS
-- ==============================================================================

--- Handle GUI opened event
-- @param event EventData: on_gui_opened event
function gui_handlers.on_gui_opened(event)
  local player = game.players[event.player_index]
  local entity = event.entity

  if not entity or not entity.valid then return end

  if entity.name == "logistics-combinator" then
    gui_handlers.create_logistics_gui(player, entity)
  end
end

--- Handle GUI closed event
-- @param event EventData: on_gui_closed event
function gui_handlers.on_gui_closed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element and element.name == GUI_NAMES.LOGISTICS_MAIN then
    -- Save any pending changes
    gui_handlers.save_gui_changes(player)

    -- Close GUI
    gui_handlers.close_logistics_gui(player)

    -- Trigger rule processing
    local gui_state = globals.get_gui_state(player.index)
    if gui_state and gui_state.open_entity then
      logistics_combinator.process_rules(gui_state.open_entity)
    end
  end
end

--- Handle GUI click event
-- @param event EventData: on_gui_click event
function gui_handlers.on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  local name = element.name

  -- Close button
  if name == GUI_NAMES.LOGISTICS_CLOSE then
    gui_handlers.close_logistics_gui(player)
    return
  end

  -- Add rule button
  if name == GUI_NAMES.LOGISTICS_ADD_RULE then
    gui_handlers.add_new_rule(player)
    return
  end

  -- Delete rule button
  if name:find("^" .. GUI_NAMES.LOGISTICS_DELETE_RULE) then
    local rule_index = tonumber(name:match("%d+$"))
    if rule_index then
      gui_handlers.delete_rule(player, rule_index)
    end
    return
  end

  -- Action radio buttons
  if name:find("^" .. GUI_NAMES.LOGISTICS_ACTION_INJECT) or name:find("^" .. GUI_NAMES.LOGISTICS_ACTION_REMOVE) then
    gui_handlers.update_rule_action(player, element)
    return
  end
end

--- Handle GUI element changed event
-- @param event EventData: on_gui_elem_changed event
function gui_handlers.on_gui_elem_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Group picker changed
  if element.name:find("^" .. GUI_NAMES.LOGISTICS_GROUP_PICKER) then
    gui_handlers.update_rule_group(player, element)
  end

  -- Signal chooser changed (condition)
  if element.name:find("signal$") then
    gui_handlers.update_rule_condition(player, element)
  end
end

--- Handle GUI text changed event
-- @param event EventData: on_gui_text_changed event
function gui_handlers.on_gui_text_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Value field changed (condition)
  if element.name:find("value$") then
    gui_handlers.update_rule_condition(player, element)
  end
end

--- Handle GUI selection state changed event
-- @param event EventData: on_gui_selection_state_changed event
function gui_handlers.on_gui_selection_state_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Operator dropdown changed (condition)
  if element.name:find("operator$") then
    gui_handlers.update_rule_condition(player, element)
  end
end

-- ==============================================================================
-- RULE MANIPULATION
-- ==============================================================================

--- Add a new rule
-- @param player LuaPlayer: Player adding the rule
function gui_handlers.add_new_rule(player)
  local gui_state = globals.get_gui_state(player.index)
  if not gui_state or not gui_state.open_entity then return end

  -- Create new rule with defaults
  local new_rule = {
    group_name = nil,
    condition = {
      signal = {type = "virtual", name = "signal-A"},
      operator = ">",
      value = 0
    },
    action = "inject",
    last_state = false
  }

  -- Add to global
  globals.add_logistics_rule(gui_state.open_entity, new_rule)

  -- Refresh GUI
  gui_handlers.refresh_gui(player, gui_state.open_entity)
end

--- Delete a rule
-- @param player LuaPlayer: Player deleting the rule
-- @param rule_index number: Index of rule to delete
function gui_handlers.delete_rule(player, rule_index)
  local gui_state = globals.get_gui_state(player.index)
  if not gui_state or not gui_state.open_entity then return end

  -- Remove from global
  globals.remove_logistics_rule(gui_state.open_entity, rule_index)

  -- Refresh GUI
  gui_handlers.refresh_gui(player, gui_state.open_entity)
end

--- Update rule group selection
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Group picker element
function gui_handlers.update_rule_group(player, element)
  local gui_state = globals.get_gui_state(player.index)
  if not gui_state or not gui_state.open_entity then return end

  local rule_index = tonumber(element.name:match("%d+$"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(gui_state.open_entity)
  if not combinator_data or not combinator_data.rules[rule_index] then return end

  -- Update rule
  combinator_data.rules[rule_index].group_name = element.elem_value
end

--- Update rule action (inject/remove)
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Radio button element
function gui_handlers.update_rule_action(player, element)
  local gui_state = globals.get_gui_state(player.index)
  if not gui_state or not gui_state.open_entity then return end

  local rule_index = tonumber(element.name:match("%d+$"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(gui_state.open_entity)
  if not combinator_data or not combinator_data.rules[rule_index] then return end

  -- Determine action from element name
  local action = nil
  if element.name:find(GUI_NAMES.LOGISTICS_ACTION_INJECT) then
    action = "inject"
  elseif element.name:find(GUI_NAMES.LOGISTICS_ACTION_REMOVE) then
    action = "remove"
  end

  if action then
    combinator_data.rules[rule_index].action = action

    -- Update radio buttons
    gui_handlers.refresh_gui(player, gui_state.open_entity)
  end
end

--- Update rule condition
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Condition element that changed
function gui_handlers.update_rule_condition(player, element)
  local gui_state = globals.get_gui_state(player.index)
  if not gui_state or not gui_state.open_entity then return end

  -- Extract rule index from element name
  local rule_index = tonumber(element.name:match("rule_(%d+)_"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(gui_state.open_entity)
  if not combinator_data or not combinator_data.rules[rule_index] then return end

  local rule = combinator_data.rules[rule_index]

  -- Update condition based on which element changed
  if element.name:find("signal$") then
    rule.condition.signal = element.elem_value
  elseif element.name:find("operator$") then
    rule.condition.operator = gui_utils.get_operator_from_index(element.selected_index)
  elseif element.name:find("value$") then
    rule.condition.value = tonumber(element.text) or 0
  end
end

--- Refresh GUI with current data
-- @param player LuaPlayer: Player whose GUI to refresh
-- @param entity_unit_number number: Entity unit_number
function gui_handlers.refresh_gui(player, entity_unit_number)
  if not player or not player.valid then return end

  -- Find entity
  local entity = nil
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{
      name = "logistics-combinator",
      limit = 1000
    }
    for _, e in pairs(found) do
      if e.valid and e.unit_number == entity_unit_number then
        entity = e
        break
      end
    end
    if entity then break end
  end

  if entity and entity.valid then
    gui_handlers.create_logistics_gui(player, entity)
  end
end

--- Save any pending GUI changes
-- @param player LuaPlayer: Player whose changes to save
function gui_handlers.save_gui_changes(player)
  -- Changes are saved in real-time during events
  -- This function is kept for future use if batching is needed
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

return gui_handlers

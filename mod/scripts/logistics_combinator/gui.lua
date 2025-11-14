-- gui.lua
-- Mission Control Mod - Logistics Combinator GUI Module
--
-- PURPOSE:
-- Handle GUI creation and events specifically for logistics combinator.
-- This is entity-specific GUI code, not shared across entity types.
--
-- RESPONSIBILITIES:
-- - Logistics combinator GUI creation and layout
-- - GUI event handling for logistics combinator
-- - GUI state updates for logistics combinator
--
-- DOES NOT OWN:
-- - Generic GUI components (that's lib/gui_utils)
-- - GUI state storage (that's scripts/globals)
-- - Entity business logic (that's scripts/logistics_combinator/init)

local logistics_gui = {}

-- Load dependencies
local globals = require("scripts.globals")
local gui_utils = require("lib.gui_utils")

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
function logistics_gui.create_gui(player, entity)
  if not player or not player.valid then return end
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  -- Close any existing GUI
  logistics_gui.close_gui(player)

  -- Get combinator data
  local combinator_data = globals.get_logistics_combinator(entity.unit_number)
  if not combinator_data then return end

  -- Create main GUI window
  local main_frame = player.gui.screen.add{
    type = "frame",
    name = GUI_NAMES.LOGISTICS_MAIN,
    direction = "vertical",
    tags = {entity_unit_number = entity.unit_number}  -- Store entity reference in tags
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
    logistics_gui.add_rule_to_gui(rules_list, rule_idx, rule)
  end

  -- Connected entities count
  local connected_count = #(combinator_data.connected_entities or {})
  content_flow.add{
    type = "label",
    caption = {"logistics-combinator.connected-entities", connected_count}
  }

  -- Center GUI on screen
  main_frame.force_auto_center()
end

--- Add a rule display to the GUI
-- @param parent LuaGuiElement: Parent container
-- @param rule_index number: Index of this rule (1-based)
-- @param rule table: Rule definition
function logistics_gui.add_rule_to_gui(parent, rule_index, rule)
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
function logistics_gui.close_gui(player)
  if not player or not player.valid then return end

  gui_utils.close_gui_for_player(player, GUI_NAMES.LOGISTICS_MAIN)
end

-- ==============================================================================
-- EVENT HANDLERS
-- ==============================================================================

--- Handle GUI opened event for logistics combinator
-- @param player LuaPlayer: Player opening GUI
-- @param entity LuaEntity: Logistics combinator entity
function logistics_gui.on_opened(player, entity)
  if not entity or not entity.valid then return end
  if entity.name ~= "logistics-combinator" then return end

  logistics_gui.create_gui(player, entity)
end

--- Handle GUI closed event for logistics combinator
-- @param player LuaPlayer: Player closing GUI
-- @param element LuaGuiElement: GUI element being closed
function logistics_gui.on_closed(player, element)
  if not element or element.name ~= GUI_NAMES.LOGISTICS_MAIN then return end

  -- Get entity reference from GUI element tags
  local entity_unit_number = element.tags and element.tags.entity_unit_number

  -- Save any pending changes
  logistics_gui.save_gui_changes(player)

  -- Close GUI
  logistics_gui.close_gui(player)

  -- Trigger rule processing for this combinator
  if entity_unit_number then
    local logistics_combinator = require("scripts.logistics_combinator.init")
    logistics_combinator.process_rules(entity_unit_number)
  end
end

--- Handle GUI click event
-- @param event EventData: on_gui_click event
function logistics_gui.on_click(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  local name = element.name

  -- Close button
  if name == GUI_NAMES.LOGISTICS_CLOSE then
    logistics_gui.close_gui(player)
    return
  end

  -- Add rule button
  if name == GUI_NAMES.LOGISTICS_ADD_RULE then
    logistics_gui.add_new_rule(player)
    return
  end

  -- Delete rule button
  if name:find("^" .. GUI_NAMES.LOGISTICS_DELETE_RULE) then
    local rule_index = tonumber(name:match("%d+$"))
    if rule_index then
      logistics_gui.delete_rule(player, rule_index)
    end
    return
  end

  -- Action radio buttons
  if name:find("^" .. GUI_NAMES.LOGISTICS_ACTION_INJECT) or name:find("^" .. GUI_NAMES.LOGISTICS_ACTION_REMOVE) then
    logistics_gui.update_rule_action(player, element)
    return
  end
end

--- Handle GUI element changed event
-- @param event EventData: on_gui_elem_changed event
function logistics_gui.on_elem_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Group picker changed
  if element.name:find("^" .. GUI_NAMES.LOGISTICS_GROUP_PICKER) then
    logistics_gui.update_rule_group(player, element)
  end

  -- Signal chooser changed (condition)
  if element.name:find("signal$") then
    logistics_gui.update_rule_condition(player, element)
  end
end

--- Handle GUI text changed event
-- @param event EventData: on_gui_text_changed event
function logistics_gui.on_text_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Value field changed (condition)
  if element.name:find("value$") then
    logistics_gui.update_rule_condition(player, element)
  end
end

--- Handle GUI selection state changed event
-- @param event EventData: on_gui_selection_state_changed event
function logistics_gui.on_selection_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Operator dropdown changed (condition)
  if element.name:find("operator$") then
    logistics_gui.update_rule_condition(player, element)
  end
end

-- ==============================================================================
-- RULE MANIPULATION
-- ==============================================================================

--- Add a new rule
-- @param player LuaPlayer: Player adding the rule
function logistics_gui.add_new_rule(player)
  -- Get entity unit_number from open GUI element
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

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

  -- Add to combinator data
  local combinator_data = globals.get_logistics_combinator(entity_unit_number)
  if combinator_data then
    -- Initialize last_state for edge triggering
    new_rule.last_state = false
    table.insert(combinator_data.rules, new_rule)
  end

  -- Refresh GUI
  logistics_gui.refresh_gui(player, entity_unit_number)
end

--- Delete a rule
-- @param player LuaPlayer: Player deleting the rule
-- @param rule_index number: Index of rule to delete
function logistics_gui.delete_rule(player, rule_index)
  -- Get entity unit_number from open GUI element
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Remove from combinator data
  local combinator_data = globals.get_logistics_combinator(entity_unit_number)
  if combinator_data and rule_index > 0 and rule_index <= #combinator_data.rules then
    table.remove(combinator_data.rules, rule_index)
  end

  -- Refresh GUI
  logistics_gui.refresh_gui(player, entity_unit_number)
end

--- Update rule group selection
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Group picker element
function logistics_gui.update_rule_group(player, element)
  -- Get entity unit_number from open GUI element
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  local rule_index = tonumber(element.name:match("%d+$"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(entity_unit_number)
  if not combinator_data or not combinator_data.rules[rule_index] then return end

  -- Update rule
  combinator_data.rules[rule_index].group_name = element.elem_value
end

--- Update rule action (inject/remove)
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Radio button element
function logistics_gui.update_rule_action(player, element)
  -- Get entity unit_number from open GUI element
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  local rule_index = tonumber(element.name:match("%d+$"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(entity_unit_number)
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
    logistics_gui.refresh_gui(player, entity_unit_number)
  end
end

--- Update rule condition
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Condition element that changed
function logistics_gui.update_rule_condition(player, element)
  -- Get entity unit_number from open GUI element
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Extract rule index from element name
  local rule_index = tonumber(element.name:match("rule_(%d+)_"))
  if not rule_index then return end

  local combinator_data = globals.get_logistics_combinator(entity_unit_number)
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
-- PERFORMANCE: Uses global state to find entity efficiently (O(1) instead of O(n²))
-- @param player LuaPlayer: Player whose GUI to refresh
-- @param entity_unit_number number: Entity unit_number
function logistics_gui.refresh_gui(player, entity_unit_number)
  if not player or not player.valid then return end

  -- Get combinator data from global (has surface_index and position)
  local combinator_data = global.logistics_combinators and global.logistics_combinators[entity_unit_number]
  if not combinator_data then return end

  -- Find entity using stored location (O(1) lookup)
  local surface = game.surfaces[combinator_data.surface_index]
  if not surface then return end

  local entity = surface.find_entity("logistics-combinator", combinator_data.position)

  if entity and entity.valid and entity.unit_number == entity_unit_number then
    logistics_gui.create_gui(player, entity)
  end
end

--- Save any pending GUI changes
-- @param player LuaPlayer: Player whose changes to save
function logistics_gui.save_gui_changes(player)
  -- Changes are saved in real-time during events
  -- This function is kept for future use if batching is needed
end

-- ==============================================================================
-- EXPORT
-- ==============================================================================

return logistics_gui

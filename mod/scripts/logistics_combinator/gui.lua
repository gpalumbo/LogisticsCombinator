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
-- - GUI state storage (that's scripts/mc_globals)
-- - Entity business logic (that's scripts/logistics_combinator/init)

local logistics_gui = {}

-- Load dependencies
local mc_globals = require("scripts.mc_globals")
local gui_utils = require("lib.gui_utils")
local logistics_combinator = require("scripts.logistics_combinator.init")
local circuit_utils = require("lib.circuit_utils")
local signal_utils = require("lib.signal_utils")

-- ==============================================================================
-- GUI ELEMENT NAMES (for event routing)
-- ==============================================================================

local GUI_NAMES = {
  LOGISTICS_MAIN = "mission_control_logistics_gui",
  LOGISTICS_CLOSE = "logistics_close",
  LOGISTICS_ADD_RULE = "logistics_add_rule",
  LOGISTICS_RULE_PREFIX = "logistics_rule_",  -- Followed by rule index
  LOGISTICS_DELETE_RULE = "logistics_delete_rule_"  -- Followed by rule index
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
  local combinator_data = mc_globals.get_logistics_combinator(entity.unit_number)
  if not combinator_data then return end

  -- Initialize rules if not present
  if not combinator_data.rules then
    combinator_data.rules = {}
  end

  -- Create main GUI window
  local main_frame = player.gui.screen.add{
    type = "frame",
    name = GUI_NAMES.LOGISTICS_MAIN,
    direction = "vertical",
    tags = {entity_unit_number = entity.unit_number}  -- Store entity reference in tags
  }

  -- Create titlebar with drag handle
  local titlebar, drag_handle = gui_utils.create_titlebar(
    main_frame,
    {"entity-name.logistics-combinator"},
    GUI_NAMES.LOGISTICS_CLOSE
  )

  -- -- Set drag target to enable window dragging
  -- main_frame.drag_target = main_frame

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
    caption = {"logistics-combinator.controlled-groups"},
    style = "bold_label"
  }

  -- Rules frame container
  local rules_frame = content_flow.add{
    type = "frame",
    direction = "vertical",
    style = "inside_deep_frame"
  }

  local rules_scroll = rules_frame.add{
    type = "scroll-pane",
    direction = "vertical",
    style = "naked_scroll_pane"
  }
  rules_scroll.style.maximal_height = 400
  rules_scroll.style.minimal_height = 150
  rules_scroll.style.minimal_width = 600

  local rules_list = rules_scroll.add{
    type = "flow",
    name = "rules_list",
    direction = "vertical"
  }
  rules_list.style.vertical_spacing = 8
  rules_list.style.padding = 4

  -- Populate existing rules
  if combinator_data.rules then
    for rule_idx, rule in ipairs(combinator_data.rules) do
      logistics_gui.add_rule_row(rules_list, rule_idx, rule)
    end
  end

  -- Add rule button
  content_flow.add{
    type = "button",
    name = GUI_NAMES.LOGISTICS_ADD_RULE,
    caption = {"logistics-combinator.add-rule"},
    tooltip = {"logistics-combinator.add-rule-tooltip"}
  }

  -- Footer section: Connected entities and input signals
  local footer_flow = main_frame.add{
    type = "flow",
    direction = "vertical"
  }
  footer_flow.style.padding = gui_utils.GUI_CONSTANTS.PADDING
  footer_flow.style.vertical_spacing = gui_utils.GUI_CONSTANTS.SPACING

  -- Connected entities count
  local connected_count = #(combinator_data.connected_entities or {})
  footer_flow.add{
    type = "label",
    caption = {"logistics-combinator.connected-entities", connected_count}
  }

  -- Input signals section
  logistics_gui.create_input_signals_section(footer_flow, entity)

  -- Center GUI on screen
  main_frame.force_auto_center()
end

--- Add a rule row to the rules list
-- Each rule combines: logistics group + circuit condition + action
-- @param parent LuaGuiElement: Parent flow to add rule to
-- @param rule_index number: Index of this rule
-- @param rule table: Rule data {group, condition, action, last_state}
function logistics_gui.add_rule_row(parent, rule_index, rule)
  -- Container for this rule
  local rule_container = parent.add{
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame"
  }
  rule_container.style.padding = 8

  -- Top row: Group selector and action selector
  local top_row = rule_container.add{
    type = "flow",
    direction = "horizontal"
  }
  top_row.style.horizontal_spacing = 8
  top_row.style.vertical_align = "center"

  -- Group label
  top_row.add{
    type = "label",
    caption = {"logistics-combinator.group-label"}
  }

  -- Logistics group dropdown
  -- Get available logistics groups from player's force
  local player = parent.gui.player
  local available_groups = player and player.valid and player.force.get_logistic_groups() or {}

  -- Add "None" option at the beginning
  local group_items = {"(None)"}
  for _, group_name in ipairs(available_groups) do
    table.insert(group_items, group_name)
  end

  local group_dropdown = top_row.add{
    type = "drop-down",
    name = GUI_NAMES.LOGISTICS_RULE_PREFIX .. rule_index .. "_group",
    items = group_items,
    tooltip = {"logistics-combinator.group-tooltip"}
  }
  group_dropdown.style.width = 200

  -- Set selected index if rule has a group
  if rule and rule.group then
    for i, group_name in ipairs(group_items) do
      if group_name == rule.group then
        group_dropdown.selected_index = i
        break
      end
    end
  else
    group_dropdown.selected_index = 1  -- Default to "(None)"
  end

  -- Spacer (fills remaining space on right)
  top_row.add{
    type = "empty-widget",
    style = "draggable_space"
  }.style.horizontally_stretchable = true

  -- Bottom row: Condition
  local bottom_row = rule_container.add{
    type = "flow",
    direction = "horizontal"
  }
  bottom_row.style.horizontal_spacing = 8
  bottom_row.style.vertical_align = "center"
  bottom_row.style.top_margin = 4

  -- Condition label
  bottom_row.add{
    type = "label",
    caption = {"logistics-combinator.condition-label"}
  }

  -- Signal chooser
  local signal_chooser = bottom_row.add{
    type = "choose-elem-button",
    name = GUI_NAMES.LOGISTICS_RULE_PREFIX .. rule_index .. "_signal",
    elem_type = "signal",
    tooltip = {"logistics-combinator.signal-tooltip"}
  }

  if rule and rule.condition and rule.condition.signal then
    signal_chooser.elem_value = rule.condition.signal
  end

  -- Operator dropdown
  local operator_dropdown = bottom_row.add{
    type = "drop-down",
    name = GUI_NAMES.LOGISTICS_RULE_PREFIX .. rule_index .. "_operator",
    items = {},
    tooltip = {"logistics-combinator.operator-tooltip"}
  }
  operator_dropdown.style.width = 60
  gui_utils.populate_operator_dropdown(operator_dropdown)

  if rule and rule.condition and rule.condition.operator then
    local op_index = gui_utils.get_index_from_operator(rule.condition.operator)
    operator_dropdown.selected_index = op_index
  else
    operator_dropdown.selected_index = 1
  end

  -- Value field
  local value_field = bottom_row.add{
    type = "textfield",
    name = GUI_NAMES.LOGISTICS_RULE_PREFIX .. rule_index .. "_value",
    text = "0",
    numeric = true,
    allow_negative = true,
    tooltip = {"logistics-combinator.value-tooltip"}
  }
  value_field.style.width = 80

  if rule and rule.condition and rule.condition.value then
    value_field.text = tostring(rule.condition.value)
  end

  -- Spacer
  bottom_row.add{
    type = "empty-widget",
    style = "draggable_space"
  }.style.horizontally_stretchable = true

  -- Status indicator (shows if rule is currently active)
  local status_label = bottom_row.add{
    type = "label",
    caption = (rule and rule.last_state) and {"logistics-combinator.active"} or {"logistics-combinator.inactive"},
    tooltip = {"logistics-combinator.status-tooltip"}
  }
  status_label.style.font = "default-small"
  status_label.style.font_color = (rule and rule.last_state) and {r=0, g=1, b=0} or {r=0.5, g=0.5, b=0.5}

  -- Delete button
  bottom_row.add{
    type = "sprite-button",
    name = GUI_NAMES.LOGISTICS_DELETE_RULE .. rule_index,
    sprite = "utility/trash",
    style = "tool_button_red",
    tooltip = {"logistics-combinator.delete-rule"}
  }
end


--- Create input signals display section
-- Shows current circuit network input signals (red and green separately)
-- @param parent LuaGuiElement: Parent flow to add section to
-- @param entity LuaEntity: Logistics combinator entity
function logistics_gui.create_input_signals_section(parent, entity)
  if not parent or not entity or not entity.valid then return end

  -- Section header
  local header = parent.add{
    type = "label",
    caption = {"logistics-combinator.input-signals"},
    style = "bold_label"
  }
  header.style.top_margin = 4

  -- Container frame for both red and green signals
  local signals_container = parent.add{
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame"
  }
  signals_container.style.padding = 8
  signals_container.style.minimal_width = 600

  -- Read input signals from red and green networks
  local red_signals = circuit_utils.get_circuit_signals(entity, defines.wire_connector_id.combinator_input_red)
  local green_signals = circuit_utils.get_circuit_signals(entity, defines.wire_connector_id.combinator_input_green)

  -- Check if either network has signals
  local has_red_signals = red_signals and next(red_signals) ~= nil
  local has_green_signals = green_signals and next(green_signals) ~= nil

  if not has_red_signals and not has_green_signals then
    -- No signals on either network
    local no_signals_label = signals_container.add{
      type = "label",
      caption = {"logistics-combinator.no-input-signals"}
    }
    no_signals_label.style.font_color = {r=0.5, g=0.5, b=0.5}
    return
  end

  -- Red circuit signals section
  logistics_gui.create_signal_network_display(
    signals_container,
    {"logistics-combinator.red-circuit"},
    red_signals,
    {r=1, g=0.3, b=0.3}  -- Red color
  )

  -- Green circuit signals section
  logistics_gui.create_signal_network_display(
    signals_container,
    {"logistics-combinator.green-circuit"},
    green_signals,
    {r=0.3, g=1, b=0.3}  -- Green color
  )
end

--- Create signal display for a single network (red or green)
-- @param parent LuaGuiElement: Parent container
-- @param caption LocalisedString: Caption for this network
-- @param signals table|nil: Signal table {[signal_id] = count}
-- @param color table: RGB color for the header {r, g, b}
function logistics_gui.create_signal_network_display(parent, caption, signals, color)
  if not parent then return end

  -- Network container
  local network_flow = parent.add{
    type = "flow",
    direction = "vertical"
  }
  network_flow.style.vertical_spacing = 4

  -- Network label with color
  local network_label = network_flow.add{
    type = "label",
    caption = caption,
    style = "caption_label"
  }
  network_label.style.font_color = color

  -- Check if this network has signals
  local has_signals = signals and next(signals) ~= nil

  if not has_signals then
    -- No signals on this network
    local empty_label = network_flow.add{
      type = "label",
      caption = {"logistics-combinator.no-signals-on-network"}
    }
    empty_label.style.font_color = {r=0.5, g=0.5, b=0.5}
    empty_label.style.left_margin = 8
    return
  end

  -- Create signal display table
  local signals_table = network_flow.add{
    type = "table",
    column_count = 10,  -- 10 signals per row
    style = "slot_table"
  }
  signals_table.style.left_margin = 8

  -- Display each signal as a sprite-button with count
  for signal_id, count in pairs(signals) do
    -- Validate signal_id structure before using it
    if signal_id and signal_id.name and count and count ~= 0 then
      -- FACTORIO 2.0 API: When type is "item", the type field is nil when reading
      -- Default to "item" if type is nil
      local signal_type = signal_id.type or "item"

      local signal_button = signals_table.add{
        type = "sprite-button",
        sprite = signal_type .. "/" .. signal_id.name,
        number = count,
        enabled = true,
        tooltip = {"", signal_id.name, ": ", count},
        style = "slot_button",
        tint = color
      }
    end
  end
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

  -- Override vanilla GUI with our custom GUI
  -- This prevents the vanilla decider combinator GUI from appearing
  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if main_frame and main_frame.valid then
    player.opened = main_frame
  end
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
    local rule_index = tonumber(name:match("_(%d+)"))
    if rule_index then
      logistics_gui.delete_rule(player, rule_index)
    end
    return
  end

end

--- Handle GUI element changed event
-- @param event EventData: on_gui_elem_changed event
function logistics_gui.on_elem_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Signal chooser changed (condition)
  if element.name:find("_signal$") then
    logistics_gui.update_rule_signal(player, element)
    return
  end
end

--- Handle GUI text changed event
-- @param event EventData: on_gui_text_changed event
function logistics_gui.on_text_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Value field changed (condition value)
  if element.name:find("_value$") then
    logistics_gui.update_rule_value(player, element)
    return
  end
end

--- Handle GUI selection state changed event
-- @param event EventData: on_gui_selection_state_changed event
function logistics_gui.on_selection_changed(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Group dropdown changed
  if element.name:find("_group$") then
    logistics_gui.update_rule_group(player, element)
    return
  end

  -- Operator dropdown changed
  if element.name:find("_operator$") then
    logistics_gui.update_rule_operator(player, element)
    return
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
  -- Action is automatic: condition TRUE = inject, condition FALSE = remove
  local new_rule = {
    group = nil,  -- No group selected initially
    condition = {
      signal = {type = "virtual", name = "signal-A"},
      operator = ">",
      value = 0
    },
    last_state = false
  }

  -- Add to combinator data
  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if combinator_data then
    if not combinator_data.rules then
      combinator_data.rules = {}
    end
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
  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if combinator_data and combinator_data.rules and rule_index > 0 and rule_index <= #combinator_data.rules then
    table.remove(combinator_data.rules, rule_index)
  end

  -- Refresh GUI
  logistics_gui.refresh_gui(player, entity_unit_number)
end

--- Update rule operator
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Operator dropdown element
function logistics_gui.update_rule_operator(player, element)
  if not player or not element or not element.valid then return end

  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Parse rule index from element name: logistics_rule_X_operator
  local rule_index = tonumber(element.name:match("(%d+)_operator$"))
  if not rule_index then return end

  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if not combinator_data or not combinator_data.rules or not combinator_data.rules[rule_index] then return end

  -- Update condition operator
  if not combinator_data.rules[rule_index].condition then
    combinator_data.rules[rule_index].condition = {}
  end
  combinator_data.rules[rule_index].condition.operator = gui_utils.get_operator_from_index(element.selected_index)
end

--- Update rule value
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Value textfield element
function logistics_gui.update_rule_value(player, element)
  if not player or not element or not element.valid then return end

  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Parse rule index from element name: logistics_rule_X_value
  local rule_index = tonumber(element.name:match("(%d+)_value$"))
  if not rule_index then return end

  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if not combinator_data or not combinator_data.rules or not combinator_data.rules[rule_index] then return end

  -- Update condition value
  if not combinator_data.rules[rule_index].condition then
    combinator_data.rules[rule_index].condition = {}
  end
  combinator_data.rules[rule_index].condition.value = tonumber(element.text) or 0
end

--- Update rule logistics group
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Group chooser element
function logistics_gui.update_rule_group(player, element)
  if not player or not element or not element.valid then return end

  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Parse rule index from element name: logistics_rule_X_group
  local rule_index = tonumber(element.name:match("(%d+)_group$"))
  if not rule_index then return end

  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if not combinator_data or not combinator_data.rules then return end

  -- Get selected group name from dropdown
  local selected_index = element.selected_index
  if not selected_index or selected_index == 0 then return end

  local group_name = element.get_item(selected_index)

  -- Handle "(None)" selection
  if group_name == "(None)" then
    group_name = nil
  end

  -- Update rule data
  if not combinator_data.rules[rule_index] then
    combinator_data.rules[rule_index] = {
      group = group_name,
      condition = {signal = {type = "virtual", name = "signal-A"}, operator = ">", value = 0},
      last_state = false
    }
  else
    combinator_data.rules[rule_index].group = group_name
  end
end

--- Update rule signal
-- @param player LuaPlayer: Player making the change
-- @param element LuaGuiElement: Signal chooser element
function logistics_gui.update_rule_signal(player, element)
  if not player or not element or not element.valid then return end

  local main_frame = player.gui.screen[GUI_NAMES.LOGISTICS_MAIN]
  if not main_frame or not main_frame.tags then return end

  local entity_unit_number = main_frame.tags.entity_unit_number
  if not entity_unit_number then return end

  -- Parse rule index from element name: logistics_rule_X_signal
  local rule_index = tonumber(element.name:match("(%d+)_signal$"))
  if not rule_index then return end

  local combinator_data = mc_globals.get_logistics_combinator(entity_unit_number)
  if not combinator_data or not combinator_data.rules or not combinator_data.rules[rule_index] then return end

  -- Update condition signal
  if not combinator_data.rules[rule_index].condition then
    combinator_data.rules[rule_index].condition = {}
  end
  combinator_data.rules[rule_index].condition.signal = element.elem_value
end

--- Refresh GUI with current data
-- PERFORMANCE: Uses global state to find entity efficiently (O(1) instead of O(n²))
-- @param player LuaPlayer: Player whose GUI to refresh
-- @param entity_unit_number number: Entity unit_number
function logistics_gui.refresh_gui(player, entity_unit_number)
  if not player or not player.valid then return end

  -- Get combinator data from global (has surface_index and position)
  local combinator_data = storage.logistics_combinators and storage.logistics_combinators[entity_unit_number]
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

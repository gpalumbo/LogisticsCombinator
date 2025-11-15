-- gui_utils.lua
-- Purpose: Common GUI creation patterns and helpers for Mission Control mod
-- Dependencies: None
-- This module provides REUSABLE GUI components used across multiple entity types
-- Does NOT contain entity-specific GUI layouts (those are in scripts/gui_handlers)

-- ==============================================================================
-- CONSTANTS
-- ==============================================================================

local GUI_CONSTANTS = {
  TITLEBAR_HEIGHT = 28,
  BUTTON_HEIGHT = 28,
  SPACING = 8,
  PADDING = 12,
  MIN_WIDTH = 300,
  MAX_WIDTH = 600
}

-- Operator definitions (index matches dropdown position)
local OPERATORS = {
  {symbol = "<",  display = "<"},
  {symbol = ">",  display = ">"},
  {symbol = "=",  display = "="},
  {symbol = "≠",  display = "≠"},
  {symbol = "≤",  display = "≤"},
  {symbol = "≥",  display = "≥"}
}

-- Icon types for status labels
local STATUS_ICONS = {
  connected = "[img=utility/status_working]",
  disconnected = "[img=utility/status_not_working]",
  warning = "[img=utility/warning_icon]"
}

-- ==============================================================================
-- GUI COMPONENT CREATION
-- ==============================================================================

--- Create standard titlebar with close button
-- Creates a horizontal flow with title label and close button
-- @param parent LuaGuiElement: Parent container
-- @param title LocalisedString: Window title text
-- @param close_button_name string: Name for close button (for event handling)
-- @return LuaGuiElement: Created titlebar flow
function create_titlebar(parent, title, close_button_name)
  local titlebar = parent.add{
    type = "flow",
    direction = "horizontal"
  }
  titlebar.style.height = GUI_CONSTANTS.TITLEBAR_HEIGHT
  titlebar.style.horizontally_stretchable = true
  titlebar.style.vertical_align = "center"

  -- Title label (takes up most space)
  local title_label = titlebar.add{
    type = "label",
    caption = title,
    style = "frame_title"
  }
  title_label.style.horizontally_stretchable = true

  -- Drag handle (empty filler for window dragging)
  titlebar.add{
    type = "empty-widget",
    style = "draggable_space_header"
  }.style.horizontally_stretchable = true

  -- Close button
  titlebar.add{
    type = "sprite-button",
    name = close_button_name,
    sprite = "utility/close_white",
    style = "frame_action_button",
    tooltip = {"gui.close"}
  }

  return titlebar
end

--- Create row of buttons
-- Creates a horizontal flow with evenly-spaced buttons
-- @param parent LuaGuiElement: Parent container
-- @param buttons array: Array of {name, caption, tooltip} tables
-- @return LuaGuiElement: Created button flow
-- Example: create_button_row(parent, {
--   {name = "select_all", caption = {"gui.select-all"}, tooltip = {"gui.select-all-tooltip"}},
--   {name = "clear_all", caption = {"gui.clear-all"}, tooltip = nil}
-- })
function create_button_row(parent, buttons)
  local button_flow = parent.add{
    type = "flow",
    direction = "horizontal"
  }
  button_flow.style.horizontal_spacing = GUI_CONSTANTS.SPACING
  button_flow.style.vertically_stretchable = false

  for _, button_def in ipairs(buttons) do
    local button = button_flow.add{
      type = "button",
      name = button_def.name,
      caption = button_def.caption,
      tooltip = button_def.tooltip
    }
    button.style.height = GUI_CONSTANTS.BUTTON_HEIGHT
    button.style.minimal_width = 100
  end

  return button_flow
end

--- Create status label with icon
-- Creates a label with an icon prefix indicating status
-- @param parent LuaGuiElement: Parent container
-- @param status_text LocalisedString: Status message
-- @param icon_type string: "connected", "disconnected", or "warning"
-- @return LuaGuiElement: Created label
function create_status_label(parent, status_text, icon_type)
  local icon = STATUS_ICONS[icon_type] or ""
  local label = parent.add{
    type = "label",
    caption = icon .. " " .. status_text
  }
  label.style.single_line = false
  return label
end

--- Create condition selector (signal + operator + value)
-- Creates a horizontal flow with signal chooser, operator dropdown, and value field
-- This is a reusable pattern for circuit condition building
-- @param parent LuaGuiElement: Parent container
-- @param name_prefix string: Prefix for child element names (e.g., "rule_1_")
-- @return table: {signal_chooser, operator_dropdown, value_field, flow}
function create_condition_selector(parent, name_prefix)
  local condition_flow = parent.add{
    type = "flow",
    direction = "horizontal"
  }
  condition_flow.style.horizontal_spacing = GUI_CONSTANTS.SPACING
  condition_flow.style.vertical_align = "center"

  -- Signal chooser
  local signal_chooser = condition_flow.add{
    type = "choose-elem-button",
    name = name_prefix .. "signal",
    elem_type = "signal",
    tooltip = {"gui.condition-signal-tooltip"}
  }

  -- Operator dropdown
  local operator_dropdown = condition_flow.add{
    type = "drop-down",
    name = name_prefix .. "operator",
    items = {},  -- Will be populated with populate_operator_dropdown
    selected_index = 1,
    tooltip = {"gui.condition-operator-tooltip"}
  }
  populate_operator_dropdown(operator_dropdown)

  -- Value field (can be number or signal)
  local value_field = condition_flow.add{
    type = "textfield",
    name = name_prefix .. "value",
    text = "0",
    numeric = true,
    allow_negative = true,
    tooltip = {"gui.condition-value-tooltip"}
  }
  value_field.style.width = 80

  return {
    signal_chooser = signal_chooser,
    operator_dropdown = operator_dropdown,
    value_field = value_field,
    flow = condition_flow
  }
end

-- ==============================================================================
-- GUI UTILITY FUNCTIONS
-- ==============================================================================

--- Close GUI for player by name
-- Safely destroys GUI element if it exists
-- @param player LuaPlayer: Player whose GUI to close
-- @param gui_name string: Name of root GUI element
function close_gui_for_player(player, gui_name)
  if not player or not player.valid then return end

  local gui_element = player.gui.screen[gui_name]
  if gui_element and gui_element.valid then
    gui_element.destroy()
  end
end

-- ==============================================================================
-- OPERATOR UTILITIES
-- ==============================================================================

--- Populate dropdown with standard operators
-- Fills a dropdown element with comparison operators
-- @param dropdown LuaGuiElement: Dropdown element to populate
function populate_operator_dropdown(dropdown)
  if not dropdown or not dropdown.valid then return end

  local items = {}
  for _, op in ipairs(OPERATORS) do
    table.insert(items, op.display)
  end

  dropdown.items = items
  if dropdown.selected_index == 0 then
    dropdown.selected_index = 1  -- Default to "<"
  end
end

--- Get operator symbol from dropdown index
-- Converts dropdown selected index to operator symbol
-- @param index number: Dropdown selected index (1-based)
-- @return string: Operator symbol (<, >, =, ≠, ≤, ≥)
function get_operator_from_index(index)
  if index < 1 or index > #OPERATORS then
    return "<"  -- Default fallback
  end
  return OPERATORS[index].symbol
end

--- Get dropdown index from operator symbol
-- Converts operator symbol to dropdown index
-- @param operator string: Operator symbol
-- @return number: Dropdown index (1-based)
function get_index_from_operator(operator)
  for i, op in ipairs(OPERATORS) do
    if op.symbol == operator then
      return i
    end
  end
  return 1  -- Default to first operator
end

-- ==============================================================================
-- WIRE FILTER COMPONENTS
-- ==============================================================================

--- Create wire filter checkboxes (R/G)
-- Creates a pair of checkboxes for filtering red and green wire signals
-- @param parent LuaGuiElement: Parent container
-- @param name_prefix string: Prefix for checkbox names (e.g., "left_", "right_")
-- @return table: {red_checkbox, green_checkbox, flow}
function create_wire_filter_checkboxes(parent, name_prefix)
  local filter_flow = parent.add{
    type = "flow",
    direction = "horizontal"
  }
  filter_flow.style.horizontal_spacing = 2
  filter_flow.style.vertical_align = "center"

  -- Red checkbox
  local red_checkbox = filter_flow.add{
    type = "checkbox",
    name = name_prefix .. "red",
    state = true,  -- Default: both enabled
    tooltip = {"gui.wire-filter-red-tooltip"}
  }
  red_checkbox.style.width = 20
  red_checkbox.style.height = 20

  -- Red label
  filter_flow.add{
    type = "label",
    caption = "[color=red]R[/color]",
    tooltip = {"gui.wire-filter-red-tooltip"}
  }

  -- Green checkbox
  local green_checkbox = filter_flow.add{
    type = "checkbox",
    name = name_prefix .. "green",
    state = true,  -- Default: both enabled
    tooltip = {"gui.wire-filter-green-tooltip"}
  }
  green_checkbox.style.width = 20
  green_checkbox.style.height = 20

  -- Green label
  filter_flow.add{
    type = "label",
    caption = "[color=green]G[/color]",
    tooltip = {"gui.wire-filter-green-tooltip"}
  }

  return {
    red_checkbox = red_checkbox,
    green_checkbox = green_checkbox,
    flow = filter_flow
  }
end

--- Get wire filter from checkbox states
-- Converts checkbox states to wire filter string
-- @param red_enabled boolean: Red checkbox state
-- @param green_enabled boolean: Green checkbox state
-- @return string: "red", "green", "both", or "none"
function get_wire_filter_from_checkboxes(red_enabled, green_enabled)
  if red_enabled and green_enabled then
    return "both"
  elseif red_enabled then
    return "red"
  elseif green_enabled then
    return "green"
  else
    return "none"  -- Invalid state, but handle it
  end
end

--- Set checkbox states from wire filter
-- Converts wire filter string to checkbox states
-- @param wire_filter string: "red", "green", or "both"
-- @return table: {red = boolean, green = boolean}
function get_checkboxes_from_wire_filter(wire_filter)
  if wire_filter == "both" then
    return {red = true, green = true}
  elseif wire_filter == "red" then
    return {red = true, green = false}
  elseif wire_filter == "green" then
    return {red = false, green = true}
  else
    -- Default to both if unknown
    return {red = true, green = true}
  end
end

-- ==============================================================================
-- CONDITION EVALUATION
-- ==============================================================================

--- Evaluate circuit condition
-- Generic signal comparison logic used by multiple entities
-- This function belongs here (not in logistics_combinator) because it's
-- generic logic with no entity-specific knowledge
-- @param signals table: Current signal values {[signal_name] = value}
-- @param condition table: {signal, operator, value} or {signal, operator, compare_signal}
-- @return boolean: True if condition met
--
-- Condition format:
--   condition.signal = {type = "item"|"fluid"|"virtual", name = "signal-name"}
--   condition.operator = "<" | ">" | "=" | "≠" | "≤" | "≥"
--   condition.value = number OR
--   condition.compare_signal = {type = "...", name = "..."} for signal-to-signal comparison
--
-- Examples:
--   evaluate_condition({iron_plate = 100}, {signal = {type="item", name="iron-plate"}, operator = "<", value = 50})
--   -> false (100 is not < 50)
--
--   evaluate_condition({coal = 10, wood = 20}, {signal = {type="item", name="coal"}, operator = "≤", compare_signal = {type="item", name="wood"}})
--   -> true (10 <= 20)
function evaluate_condition(signals, condition)
  if not signals or not condition then return false end
  if not condition.signal or not condition.operator then return false end

  -- Get left-hand value (the signal being checked)
  local signal_key = get_signal_key(condition.signal)
  local left_value = signals[signal_key] or 0

  -- Get right-hand value (constant or another signal)
  local right_value
  if condition.compare_signal then
    -- Signal-to-signal comparison
    local compare_key = get_signal_key(condition.compare_signal)
    right_value = signals[compare_key] or 0
  else
    -- Constant value comparison
    right_value = condition.value or 0
  end

  -- Perform comparison based on operator
  local operator = condition.operator

  if operator == "<" then
    return left_value < right_value
  elseif operator == ">" then
    return left_value > right_value
  elseif operator == "=" then
    return left_value == right_value
  elseif operator == "≠" then
    return left_value ~= right_value
  elseif operator == "≤" then
    return left_value <= right_value
  elseif operator == "≥" then
    return left_value >= right_value
  else
    -- Unknown operator, default to false
    return false
  end
end

--- Evaluate complex conditions with boolean operators
-- Evaluates an array of conditions with per-condition AND/OR operators
-- @param conditions table: Array of condition objects with logical_op field
-- @param red_signals table: Signals from red wire {[signal_id] = count}
-- @param green_signals table: Signals from green wire {[signal_id] = count}
-- @return boolean: True if overall condition expression is true
--
-- Condition format:
--   {
--     {
--       logical_op = "AND"|"OR",  -- How to combine with PREVIOUS result
--       left_signal = {type="item", name="iron-plate"},
--       left_wire_filter = "red"|"green"|"both",
--       operator = "<"|">"|"="|"≠"|"≤"|"≥",
--       right_type = "constant"|"signal",
--       right_value = 100,  -- If constant
--       right_signal = {...},  -- If signal
--       right_wire_filter = "red"|"green"|"both"
--     },
--     -- ... more conditions
--   }
--
-- Examples:
--   evaluate_complex_conditions({{...}}, red, green) => true/false
--   Empty conditions array => false (no conditions to evaluate)
--   First condition's logical_op is ignored (no previous result)
function evaluate_complex_conditions(conditions, red_signals, green_signals)
  if not conditions or #conditions == 0 then
    return false  -- No conditions = false
  end

  local result = nil  -- Start with no result

  for i, cond in ipairs(conditions) do
    -- Get signals for left side based on wire filter
    local left_signals = get_filtered_signals_from_tables(red_signals, green_signals, cond.left_wire_filter)

    -- Get left signal value
    local left_key = get_signal_key(cond.left_signal)
    local left_value = left_signals[left_key] or 0

    -- Get right signal value
    local right_value
    if cond.right_type == "signal" then
      local right_signals = get_filtered_signals_from_tables(red_signals, green_signals, cond.right_wire_filter)
      local right_key = get_signal_key(cond.right_signal)
      right_value = right_signals[right_key] or 0
    else
      right_value = cond.right_value or 0
    end

    -- Evaluate this condition
    local cond_result = compare_values(left_value, right_value, cond.operator)

    -- Combine with previous result using logical operator
    if result == nil then
      -- First condition, no previous result
      result = cond_result
    elseif cond.logical_op == "AND" then
      result = result and cond_result
    elseif cond.logical_op == "OR" then
      result = result or cond_result
    else
      -- Unknown operator, treat as AND
      result = result and cond_result
    end
  end

  return result or false
end

--- Get filtered signals from separate red/green tables
-- Helper for complex condition evaluation
-- @param red_signals table: Signals from red wire
-- @param green_signals table: Signals from green wire
-- @param wire_filter string: "red", "green", or "both"
-- @return table: Filtered signal table
function get_filtered_signals_from_tables(red_signals, green_signals, wire_filter)
  local result = {}

  if wire_filter == "red" or wire_filter == "both" then
    if red_signals then
      for signal_id, count in pairs(red_signals) do
        result[signal_id] = (result[signal_id] or 0) + count
      end
    end
  end

  if wire_filter == "green" or wire_filter == "both" then
    if green_signals then
      for signal_id, count in pairs(green_signals) do
        result[signal_id] = (result[signal_id] or 0) + count
      end
    end
  end

  return result
end

--- Compare two values with an operator
-- Helper function for condition evaluation
-- @param left number: Left-hand value
-- @param right number: Right-hand value
-- @param operator string: Comparison operator
-- @return boolean: Result of comparison
function compare_values(left, right, operator)
  if operator == "<" then
    return left < right
  elseif operator == ">" then
    return left > right
  elseif operator == "=" then
    return left == right
  elseif operator == "≠" then
    return left ~= right
  elseif operator == "≤" then
    return left <= right
  elseif operator == "≥" then
    return left >= right
  else
    return false  -- Unknown operator
  end
end

--- Get signal key for table lookup
-- Internal helper to convert signal definition to string key
-- @param signal table: {type = "item"|"fluid"|"virtual", name = "signal-name"}
-- @return string: Key for signal table lookup
function get_signal_key(signal)
  if not signal or not signal.name then return "" end
  -- For simplicity, use name as key. In real implementation, may need type prefix
  -- to distinguish between item/fluid/virtual signals with same name
  return signal.type .. ":" .. signal.name
end

--- Create condition result indicator
-- Creates a status indicator showing true/false for condition evaluation
-- @param parent LuaGuiElement: Parent container
-- @param name string: Name for the indicator element
-- @return table: {flow, sprite, label}
function create_condition_indicator(parent, name)
  local indicator_flow = parent.add{
    type = "flow",
    name = name .. "_flow",
    direction = "horizontal"
  }
  indicator_flow.style.horizontal_spacing = 4
  indicator_flow.style.vertical_align = "center"

  indicator_flow.add{
    type = "label",
    caption = "Condition: "
  }

  local sprite = indicator_flow.add{
    type = "sprite",
    name = name .. "_sprite",
    sprite = "utility/status_not_working"  -- Default: false (red X)
  }

  local label = indicator_flow.add{
    type = "label",
    name = name .. "_label",
    caption = "False"
  }

  return {
    flow = indicator_flow,
    sprite = sprite,
    label = label
  }
end

--- Update condition indicator state
-- Updates the visual state of a condition indicator
-- @param sprite LuaGuiElement: Sprite element
-- @param label LuaGuiElement: Label element
-- @param state boolean: True/false state to display
function update_condition_indicator(sprite, label, state)
  if sprite and sprite.valid then
    sprite.sprite = state and "utility/status_working" or "utility/status_not_working"
  end

  if label and label.valid then
    label.caption = state and "[color=green]True[/color]" or "[color=red]False[/color]"
  end
end

-- ==============================================================================
-- EXPORTS
-- ==============================================================================

return {
  -- Constants
  GUI_CONSTANTS = GUI_CONSTANTS,

  -- Component creation
  create_titlebar = create_titlebar,
  create_button_row = create_button_row,
  create_status_label = create_status_label,
  create_condition_selector = create_condition_selector,
  create_wire_filter_checkboxes = create_wire_filter_checkboxes,
  create_condition_indicator = create_condition_indicator,

  -- Utility functions
  close_gui_for_player = close_gui_for_player,
  update_condition_indicator = update_condition_indicator,

  -- Wire filter utilities
  get_wire_filter_from_checkboxes = get_wire_filter_from_checkboxes,
  get_checkboxes_from_wire_filter = get_checkboxes_from_wire_filter,

  -- Operator utilities
  populate_operator_dropdown = populate_operator_dropdown,
  get_operator_from_index = get_operator_from_index,
  get_index_from_operator = get_index_from_operator,

  -- Condition evaluation
  evaluate_condition = evaluate_condition,
  evaluate_complex_conditions = evaluate_complex_conditions,
  get_signal_key = get_signal_key,
  compare_values = compare_values,
  get_filtered_signals_from_tables = get_filtered_signals_from_tables
}

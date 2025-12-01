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

-- Signal evaluation types for special handling of aggregate signals
local SIGNAL_EVAL_TYPE = {
  NORMAL = "normal",         -- Standard signal comparison
  EACH = "each",             -- Not supported in conditions
  ANYTHING = "anything",     -- TRUE if ANY signal matches condition
  EVERYTHING = "everything"  -- TRUE if ALL signals match condition
}

function find_child_recursive(element, name)
    if element.name == name then
        return element
    end
    if element.children then
        for _, child in pairs(element.children) do
            local found = find_child_recursive(child, name)
            if found then return found end
        end
    end
    return nil
end

-- ==============================================================================
-- VIRTUAL SIGNAL EVALUATION TYPE
-- ==============================================================================

--- Determine the evaluation type for a signal
-- Returns the appropriate SIGNAL_EVAL_TYPE based on the signal
-- @param signal SignalID: The signal to check {type=string, name=string}
-- @return string: One of SIGNAL_EVAL_TYPE values (NORMAL, EACH, ANYTHING, EVERYTHING)
function get_signal_eval_type(signal)
    if not signal then return SIGNAL_EVAL_TYPE.NORMAL end
    if signal.type ~= "virtual" then return SIGNAL_EVAL_TYPE.NORMAL end

    if signal.name == "signal-each" then
        return SIGNAL_EVAL_TYPE.EACH
    elseif signal.name == "signal-anything" then
        return SIGNAL_EVAL_TYPE.ANYTHING
    elseif signal.name == "signal-everything" then
        return SIGNAL_EVAL_TYPE.EVERYTHING
    end

    return SIGNAL_EVAL_TYPE.NORMAL
end

--- Validate a signal for use in conditions
-- Returns nil if valid, or an error message key if invalid
-- @param signal SignalID: The signal to validate
-- @return string|nil: Locale key for error message, or nil if valid
function validate_condition_signal(signal)
    local eval_type = get_signal_eval_type(signal)
    if eval_type == SIGNAL_EVAL_TYPE.EACH then
        return "gui.signal-each-not-supported"
    end
    return nil  -- NORMAL, Everything, and Anything are valid
end

--- Validate a signal for use on the RIGHT side of conditions
-- Only NORMAL signals are allowed on the right side (no ANYTHING, EVERYTHING, EACH)
-- @param signal SignalID: The signal to validate
-- @return string|nil: Locale key for error message, or nil if valid
function validate_right_signal(signal)
    local eval_type = get_signal_eval_type(signal)
    if eval_type ~= SIGNAL_EVAL_TYPE.NORMAL then
        return "gui.special-signal-not-allowed-right"
    end
    return nil  -- Only NORMAL signals are valid on right side
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
    name = name_prefix,
    direction = "vertical",
    visible = true
  }
  filter_flow.style.vertical_spacing = 0
  filter_flow.style.horizontal_align = "center"

  local checkbox_panel = filter_flow.add{
    type = "flow",
    direction = "horizontal"
  }
  checkbox_panel.style.horizontal_spacing = 2
  checkbox_panel.style.vertical_align = "center"

  -- Red checkbox
  local red_checkbox = checkbox_panel.add{
    type = "checkbox",
    name = name_prefix .. "red",
    state = true,  -- Default: both enabled
    tooltip = {"gui.wire-filter-red-tooltip"}
  }
  red_checkbox.style.width = 20
  red_checkbox.style.height = 20

  -- Red label
  checkbox_panel.add{
    type = "label",
    caption = "[color=red]R[/color]",
    tooltip = {"gui.wire-filter-red-tooltip"}
  }


  checkbox_panel = filter_flow.add{
    type = "flow",
    direction = "horizontal"
  }
  checkbox_panel.style.horizontal_spacing = 2
  checkbox_panel.style.vertical_align = "center"

  -- Green checkbox
  local green_checkbox = checkbox_panel.add{
    type = "checkbox",
    name = name_prefix .. "green",
    state = true,  -- Default: both enabled
    tooltip = {"gui.wire-filter-green-tooltip"}
  }
  green_checkbox.style.width = 20
  green_checkbox.style.height = 20

  -- Green label
  checkbox_panel.add{
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

--- Create complete condition row for complex conditions
-- Creates a full condition row matching decider combinator style
-- @param parent LuaGuiElement: Parent container
-- @param rule_index number: Index of this condition (for naming)
-- @param condition table: Optional existing condition data to populate
-- @param is_first boolean: True if this is the first condition (no AND/OR button)
-- @param show_delete_button boolean: Optional, defaults to true. Set to false to omit delete button
-- @return table: {flow, and_or_button, left_wire_filter, left_signal, operator, right_type_toggle, right_value, right_signal, right_wire_filter, delete_button}
function create_condition_row(parent, rule_index, condition, is_first, show_delete_button)
  condition = condition or {}
  is_first = is_first or (rule_index == 1)
  if show_delete_button == nil then show_delete_button = true end  -- Default to true

  local row_flow = parent.add{
    type = "flow",
    name = "condition_row_" .. rule_index,
    direction = "horizontal"
  }
  row_flow.style.horizontal_spacing = 4
  row_flow.style.vertical_align = "center"
  row_flow.style.bottom_margin = 4

  -- AND/OR toggle button (only for non-first conditions)
  local and_or_button = nil
  if not is_first then
    -- Determine current logical operator (default to AND)
    local logical_op = condition.logical_op or "AND"
    local is_or = (logical_op == "OR")

    -- Create toggle button
    and_or_button = row_flow.add{
      type = "button",
      name = "cond_" .. rule_index .. "_and_or_toggle",
      caption = logical_op,
      tooltip = is_or and {"gui.switch-to-and"} or {"gui.switch-to-or"},
      style = "button",
      style_mods = {
        minimal_width = 50,
        height = 28
      }
    }

    -- Apply left padding for OR conditions (visual precedence indicator)
    if is_or then
      row_flow.style.left_padding = 20  -- Left-shift OR rows
    end
  end

  -- Left wire filter checkboxes (R/G)
  local left_wire_filter = create_wire_filter_checkboxes(row_flow, "cond_" .. rule_index .. "_left_wire_")

  local states = get_checkboxes_from_wire_filter(condition.left_wire_filter)
  left_wire_filter.red_checkbox.state = states.red
  left_wire_filter.green_checkbox.state = states.green

  -- Left signal selector
  local left_signal = row_flow.add{
    type = "choose-elem-button",
    name = "cond_" .. rule_index .. "_left_signal",
    elem_type = "signal",
    signal = condition.left_signal,  -- Use 'signal' parameter during creation, not 'elem_value'
    tooltip = {"gui.condition-left-signal-tooltip"}
  }
  left_signal.style.width = 40
  left_signal.style.height = 40

  -- Operator dropdown
  local operator_dropdown = row_flow.add{
    type = "drop-down",
    name = "cond_" .. rule_index .. "_operator",
    tooltip = {"gui.condition-operator-tooltip"}
  }
  populate_operator_dropdown(operator_dropdown)
  if condition.operator then
    operator_dropdown.selected_index = get_index_from_operator(condition.operator)
  end
  operator_dropdown.style.width = 60

  -- Right type toggle (constant vs signal)
  local right_type_toggle = row_flow.add{
    type = "sprite-button",
    name = "cond_" .. rule_index .. "_right_type_toggle",
    sprite = (condition.right_type == "signal") and "utility/custom_tag_icon" or "utility/slot",
    tooltip = (condition.right_type == "signal") and {"gui.switch-to-constant"} or {"gui.switch-to-signal"},
    style = "slot_button"
  }
  right_type_toggle.style.width = 28
  right_type_toggle.style.height = 28

  -- Right value container (for constant)
  local right_value = row_flow.add{
    type = "textfield",
    name = "cond_" .. rule_index .. "_right_value",
    text = tostring(condition.right_value or 0),
    numeric = true,
    allow_negative = true,
    visible = (condition.right_type ~= "signal"),  -- Hidden when signal mode
    tooltip = {"gui.condition-value-tooltip"}
  }
  right_value.style.width = 80

  -- Right signal selector (for signal comparison)
  local right_signal = row_flow.add{
    type = "choose-elem-button",
    name = "cond_" .. rule_index .. "_right_signal",
    elem_type = "signal",
    signal = condition.right_signal,
    visible = (condition.right_type == "signal"),  -- Visible only in signal mode
    tooltip = {"gui.condition-right-signal-tooltip"}
  }
  right_signal.style.width = 40
  right_signal.style.height = 40

  -- Right wire filter (only for signal mode)
  local right_wire_filter = create_wire_filter_checkboxes(row_flow, "cond_" .. rule_index .. "_right_wire_")
  right_wire_filter.flow.visible = (condition.right_type == "signal")

  -- Set checkbox states from existing condition

  local states = get_checkboxes_from_wire_filter(condition.right_wire_filter)
  right_wire_filter.red_checkbox.state = states.red
  right_wire_filter.green_checkbox.state = states.green

  -- Delete button (optional, based on parameter)
  local delete_button = nil
  if show_delete_button then
    delete_button = row_flow.add{
      type = "sprite-button",
      name = "cond_" .. rule_index .. "_delete",
      sprite = "utility/close",
      tooltip = {"gui.delete-condition"},
      style = "tool_button_red"
    }
    delete_button.style.width = 28
    delete_button.style.height = 28
  end

  return {
    flow = row_flow,
    and_or_button = and_or_button,
    left_wire_filter = left_wire_filter,
    left_signal = left_signal,
    operator = operator_dropdown,
    right_type_toggle = right_type_toggle,
    right_value = right_value,
    right_signal = right_signal,
    right_wire_filter = right_wire_filter,
    delete_button = delete_button
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

  -- Check for aggregate signal types (Everything, Anything, Each)
  local eval_type = get_signal_eval_type(condition.signal)

  -- Each signal is not supported - return false
  if eval_type == SIGNAL_EVAL_TYPE.EACH then
    return false
  end

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

  local operator = condition.operator

  -- Handle EVERYTHING: ALL non-zero signals must satisfy condition
  if eval_type == SIGNAL_EVAL_TYPE.EVERYTHING then
    local has_signals = false
    for _, value in pairs(signals) do
      has_signals = true
      if not compare_values(value, right_value, operator) then
        return false  -- Any failure means false
      end
    end
    return has_signals  -- False if no signals at all
  end

  -- Handle ANYTHING: AT LEAST ONE signal must satisfy condition
  if eval_type == SIGNAL_EVAL_TYPE.ANYTHING then
    for _, value in pairs(signals) do
      if compare_values(value, right_value, operator) then
        return true  -- Any match means true
      end
    end
    return false  -- No matches
  end

  -- NORMAL: Standard single signal comparison
  local signal_key = get_signal_key(condition.signal)
  local left_value = signals[signal_key] or 0
  return compare_values(left_value, right_value, operator)
end

--- Evaluate a single condition with aggregate signal support (shared by both combinators)
-- Handles EVERYTHING, ANYTHING, EACH, and NORMAL signal types
-- @param left_signals table: Signals to evaluate {[signal_key] = value}
-- @param left_signal SignalID: The left signal (may be aggregate)
-- @param operator string: Comparison operator
-- @param right_value number: The right-hand value to compare against
-- @return boolean: Result of the condition evaluation
function evaluate_single_condition_with_aggregates(left_signals, left_signal, operator, right_value)
  local eval_type = get_signal_eval_type(left_signal)

  -- Each signal is not supported - treat as false
  if eval_type == SIGNAL_EVAL_TYPE.EACH then
    return false
  end

  -- EVERYTHING: ALL non-zero signals must satisfy condition
  if eval_type == SIGNAL_EVAL_TYPE.EVERYTHING then
    local has_signals = false
    for _, value in pairs(left_signals) do
      has_signals = true
      if not compare_values(value, right_value, operator) then
        return false
      end
    end
    return has_signals  -- False if no signals at all
  end

  -- ANYTHING: AT LEAST ONE signal must satisfy condition
  if eval_type == SIGNAL_EVAL_TYPE.ANYTHING then
    for _, value in pairs(left_signals) do
      if compare_values(value, right_value, operator) then
        return true
      end
    end
    return false
  end

  -- NORMAL: Standard single signal comparison
  local left_key = get_signal_key(left_signal)
  local left_value = left_signals[left_key] or 0
  return compare_values(left_value, right_value, operator)
end

--- Evaluate complex conditions with boolean operators and proper precedence
-- Evaluates an array of conditions with per-condition AND/OR operators
-- AND has higher precedence than OR (AND binds tighter)
-- @param conditions table: Array of condition objects with logical_op field
-- @param red_signals table: Signals from red wire {[signal_id] = count}
-- @param green_signals table: Signals from green wire {[signal_id] = count}
-- @return boolean: True if overall condition expression is true
--
-- Condition format:
--   {
--     {
--       logical_op = nil|"AND"|"OR",  -- nil for first, AND/OR for subsequent
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
-- Precedence Rules:
--   AND has higher precedence than OR
--   Example: A AND B AND C OR D OR E
--     Groups: [[A,B,C], [D], [E]]
--     Evaluation: (A AND B AND C) OR D OR E
--
--   Example: A OR B AND C OR D AND E
--     Groups: [[A], [B,C], [D,E]]
--     Evaluation: A OR (B AND C) OR (D AND E)
--
-- Examples:
--   evaluate_complex_conditions({{...}}, red, green) => true/false
--   Empty conditions array => false (no conditions to evaluate)
--   First condition's logical_op is ignored (should be nil)
function evaluate_complex_conditions(conditions, red_signals, green_signals)
  if not conditions or #conditions == 0 then
    return false  -- No conditions = false
  end

  -- Step 1: Evaluate all individual conditions and store results with their operators
  local evaluated_conditions = {}
  for i, cond in ipairs(conditions) do
    -- Get signals for left side based on wire filter
    local left_signals = get_filtered_signals_from_tables(red_signals, green_signals, cond.left_wire_filter)

    -- Get right signal value
    local right_value
    if cond.right_type == "signal" then
      local right_signals = get_filtered_signals_from_tables(red_signals, green_signals, cond.right_wire_filter)
      local right_key = get_signal_key(cond.right_signal)
      right_value = right_signals[right_key] or 0
    else
      right_value = cond.right_value or 0
    end

    -- Evaluate this condition using shared helper (handles aggregate signals)
    local cond_result = evaluate_single_condition_with_aggregates(
      left_signals, cond.left_signal, cond.operator, right_value
    )

    table.insert(evaluated_conditions, {
      result = cond_result,
      logical_op = cond.logical_op  -- nil for first, "AND" or "OR" for subsequent
    })
  end

  -- Step 2: Apply AND/OR precedence (AND binds tighter than OR)
  -- Split conditions into groups separated by OR, evaluate ANDs within each group
  return evaluate_with_precedence(evaluated_conditions)
end

--- Evaluate condition results with AND/OR precedence
-- AND has higher precedence than OR (AND operations are performed first)
-- @param evaluated_conditions table: Array of {result=boolean, logical_op=nil|"AND"|"OR"}
-- @return boolean: Final result
--
-- Algorithm:
--   1. Split conditions into groups separated by OR
--   2. Within each group, AND all conditions together
--   3. OR all group results together
--
-- Example: [true, AND true, AND false, OR true, OR false]
--   Groups: [[true, true, false], [true], [false]]
--   AND groups: [false, true, false]
--   Final OR: false OR true OR false = true
function evaluate_with_precedence(evaluated_conditions)
  if #evaluated_conditions == 0 then
    return false
  end

  -- Build groups: each group contains consecutive AND conditions (or standalone conditions)
  local groups = {}
  local current_group = {}

  for i, cond_data in ipairs(evaluated_conditions) do
    if i == 1 then
      -- First condition always starts a group (no logical_op)
      table.insert(current_group, cond_data.result)
    elseif cond_data.logical_op == "OR" then
      -- OR starts a new group (finish current group first)
      table.insert(groups, current_group)
      current_group = {cond_data.result}  -- Start new group with this condition
    else
      -- AND or nil (treat as AND) - add to current group
      table.insert(current_group, cond_data.result)
    end
  end

  -- Don't forget the last group
  if #current_group > 0 then
    table.insert(groups, current_group)
  end

  -- Step 2: Evaluate each group (AND all conditions within group)
  local group_results = {}
  for _, group in ipairs(groups) do
    local group_result = true
    for _, condition_result in ipairs(group) do
      group_result = group_result and condition_result
      if not group_result then
        break  -- Short-circuit: if any AND fails, whole group is false
      end
    end
    table.insert(group_results, group_result)
  end

  -- Step 3: OR all group results together
  local final_result = false
  for _, group_result in ipairs(group_results) do
    final_result = final_result or group_result
    if final_result then
      break  -- Short-circuit: if any OR succeeds, whole expression is true
    end
  end

  return final_result
end

--- Get filtered signals from separate red/green tables
-- Helper for complex condition evaluation
-- @param red_signals table: Signals from red wire
-- @param green_signals table: Signals from green wire
-- @param wire_filter string: "red", "green", "both", or "none"
-- @return table: Filtered signal table
function get_filtered_signals_from_tables(red_signals, green_signals, wire_filter)
  local result = {}

  -- Default to "both" if wire_filter is nil or invalid (defensive programming)
  if not wire_filter or wire_filter == "" then
    wire_filter = "both"
  end

  -- Handle "none" case explicitly - return empty table (all signals = 0)
  if wire_filter == "none" then
    return result
  end

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

--- Update visual layout of condition rows based on AND/OR mix
-- Applies left-shift to OR condition rows when mixed with AND conditions
-- @param parent LuaGuiElement: Parent element containing condition rows
-- @param conditions table: Array of conditions with logical_op fields
function update_condition_row_styles(parent, conditions)
  if not parent or not parent.valid or not conditions then return end

  -- Check if we have mixed AND/OR operators
  local has_and = false
  local has_or = false

  for i, cond in ipairs(conditions) do
    if i > 1 then  -- Skip first condition (no logical_op)
      if cond.logical_op == "AND" then
        has_and = true
      elseif cond.logical_op == "OR" then
        has_or = true
      end
    end
  end

  local is_mixed = has_and and has_or

  -- Update each row's style
  for i, cond in ipairs(conditions) do
    local row_flow = parent["condition_row_" .. i]
    if row_flow and row_flow.valid then
      -- Apply left-shift only to OR rows when mixed
      if i > 1 and cond.logical_op == "OR" and is_mixed then
        row_flow.style.left_padding = 20
      else
        row_flow.style.left_padding = 0
      end
    end
  end
end

--- Get signal key for table lookup
-- Internal helper to convert signal definition to string key
-- @param signal table: {type = "item"|"fluid"|"virtual", name = "signal-name"}
-- @return string: Key for signal table lookup
function get_signal_key(signal)
  if not signal or not signal.name then return "" end
  local signal_type = signal.type or "item"  -- Default to "item" if type not specified
  -- Use type:name format to distinguish between item/fluid/virtual signals with same name
  return signal_type .. ":" .. signal.name
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
  create_condition_row = create_condition_row,
  create_condition_indicator = create_condition_indicator,

  -- Utility functions
  find_child_recursive = find_child_recursive,
  close_gui_for_player = close_gui_for_player,
  update_condition_indicator = update_condition_indicator,
  update_condition_row_styles = update_condition_row_styles,

  -- Wire filter utilities
  get_wire_filter_from_checkboxes = get_wire_filter_from_checkboxes,
  get_checkboxes_from_wire_filter = get_checkboxes_from_wire_filter,

  -- Operator utilities
  populate_operator_dropdown = populate_operator_dropdown,
  get_operator_from_index = get_operator_from_index,
  get_index_from_operator = get_index_from_operator,

  -- Signal validation
  validate_condition_signal = validate_condition_signal,
  validate_right_signal = validate_right_signal,

  -- Condition evaluation
  evaluate_condition = evaluate_condition,
  evaluate_complex_conditions = evaluate_complex_conditions,
  evaluate_with_precedence = evaluate_with_precedence,
  get_signal_key = get_signal_key,
  compare_values = compare_values,
  get_filtered_signals_from_tables = get_filtered_signals_from_tables
}

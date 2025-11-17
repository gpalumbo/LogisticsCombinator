-- Mission Control Mod - Logistics Combinator GUI
-- This module handles the GUI for logistics combinators

local flib_gui = require("__flib__.gui")
local gui_utils = require("lib.gui_utils")
local globals = require("scripts.globals")
local circuit_utils = require("lib.circuit_utils")

local logistics_combinator_gui = {}


-- GUI element names
local GUI_NAMES = {
    MAIN_FRAME = "logistics_combinator_frame",
    TITLEBAR = "logistics_combinator_titlebar",
    TITLEBAR_FLOW = "logistics_combinator_titlebar_flow",
    DRAG_HANDLE = "logistics_combinator_drag_handle",
    CLOSE_BUTTON = "logistics_combinator_close",
    CONDITION_INDICATOR_FLOW = "logistics_combinator_condition_indicator_flow",
    CONDITION_INDICATOR_SPRITE = "logistics_combinator_condition_sprite",
    CONDITION_INDICATOR_LABEL = "logistics_combinator_condition_label",
    POWER_LABEL = "logistics_combinator_power",
    CONDITIONS_FRAME = "logistics_combinator_conditions_frame",
    LOGICAL_OP_OR = "logistics_combinator_logical_op_or",
    LOGICAL_OP_AND = "logistics_combinator_logical_op_and",
    CONDITIONS_SCROLL = "logistics_combinator_conditions_scroll",
    CONDITIONS_TABLE = "logistics_combinator_conditions_table",
    ADD_CONDITION_BUTTON = "logistics_combinator_add_condition",
    ACTIONS_FRAME = "logistics_combinator_actions_frame",
    SECTIONS_SCROLL = "logistics_combinator_sections_scroll",
    SECTIONS_TABLE = "logistics_combinator_sections_table",
    ADD_SECTION_BUTTON = "logistics_combinator_add_section",
    SECTION_ROW_PREFIX = "logistics_combinator_section_row_",
    GROUP_PICKER_PREFIX = "logistics_combinator_group_picker_",
    MULTIPLIER_PREFIX = "logistics_combinator_multiplier_",
    DELETE_SECTION_PREFIX = "logistics_combinator_delete_section_",
    SIGNAL_GRID_FRAME = "logistics_combinator_signal_grid_frame",
    SIGNAL_GRID_TABLE = "logistics_combinator_signal_grid_table",
    CONNECTED_ENTITIES_LABEL = "logistics_combinator_connected_count"
}


-- ============================================================================
-- UTILITY FUNCTIONS for reducing repetitive GUI traversal
-- ============================================================================

--- Get combinator data from player's GUI state
--- @param player LuaPlayer
--- @return table|nil combinator_data, LuaEntity|nil entity
local function get_combinator_data_from_player(player)
    if not player then return nil, nil end

    local gui_state = globals.get_player_gui_state(player.index)
    if not gui_state then return nil, nil end

    local combinator_data = globals.get_logistics_combinator_data(gui_state.open_entity)
    if not combinator_data or not combinator_data.entity or not combinator_data.entity.valid then
        return nil, nil
    end

    return combinator_data, combinator_data.entity
end

--- Get condition from combinator data by index
--- @param combinator_data table
--- @param condition_index number
--- @return table|nil condition
local function get_condition_by_index(combinator_data, condition_index)
    if not combinator_data or not combinator_data.conditions then return nil end
    if not combinator_data.conditions[condition_index] then return nil end
    return combinator_data.conditions[condition_index]
end

--- Get conditions table GUI element
--- @param player LuaPlayer
--- @return LuaGuiElement|nil conditions_table
local function get_conditions_table(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return nil end

    local content_frame = frame.children[2]  -- inside_shallow_frame
    if not content_frame then return nil end

    local conditions_frame = content_frame[GUI_NAMES.CONDITIONS_FRAME]
    if not conditions_frame then return nil end

    local scroll = conditions_frame[GUI_NAMES.CONDITIONS_SCROLL]
    if not scroll then return nil end

    return scroll[GUI_NAMES.CONDITIONS_TABLE]
end

--- Get condition row GUI element by index (uses get_conditions_table)
--- @param player LuaPlayer
--- @param condition_index number
--- @return LuaGuiElement|nil condition_row
local function get_condition_row(player, condition_index)
    local conditions_table = get_conditions_table(player)
    if not conditions_table then return nil end

    return conditions_table["condition_row_" .. condition_index]
end

-- ============================================================================
-- END UTILITY FUNCTIONS
-- ============================================================================

--- Evaluate combinator conditions and update indicator
--- @param player LuaPlayer The player viewing the GUI
--- @param entity LuaEntity The combinator entity
--- @return boolean The evaluation result
local function evaluate_and_update_indicator(player, entity)
    -- Get GUI elements by traversing the hierarchy
    -- Structure: frame -> children[2] (content) -> children[1] (status flow) -> CONDITION_INDICATOR_FLOW -> sprite/label
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return false end

    -- Navigate to the condition indicator elements
    local content_frame = frame.children[2]  -- inside_shallow_frame
    if not content_frame then return false end

    local status_flow = content_frame.children[1]  -- Power status flow
    if not status_flow then return false end

    local indicator_flow = status_flow[GUI_NAMES.CONDITION_INDICATOR_FLOW]
    if not indicator_flow then return false end

    local sprite = indicator_flow[GUI_NAMES.CONDITION_INDICATOR_SPRITE]
    local label = indicator_flow[GUI_NAMES.CONDITION_INDICATOR_LABEL]

    if not sprite or not label then return false end

    -- Get combinator data
    local combinator_data = globals.get_logistics_combinator_data(entity.unit_number)
    if not combinator_data then return false end

    -- Get input signals
    local input_signals = circuit_utils.get_input_signals(entity, "combinator_input")
    if not input_signals then
        input_signals = {red = {}, green = {}}
    end

    -- Convert signal arrays to tables for evaluation
    local red_signals = {}
    local green_signals = {}

    for _, sig_data in ipairs(input_signals.red or {}) do
        if sig_data.signal_id then
            local key = gui_utils.get_signal_key(sig_data.signal_id)
            red_signals[key] = sig_data.count
        end
    end

    for _, sig_data in ipairs(input_signals.green or {}) do
        if sig_data.signal_id then
            local key = gui_utils.get_signal_key(sig_data.signal_id)
            green_signals[key] = sig_data.count
        end
    end

    -- Evaluate conditions
    local result = false
    if combinator_data.conditions and #combinator_data.conditions > 0 then
        result = gui_utils.evaluate_complex_conditions(
            combinator_data.conditions,
            red_signals,
            green_signals
        )
    end

    -- Update indicator
    gui_utils.update_condition_indicator(sprite, label, result)

    -- Store result
    globals.set_condition_result(entity.unit_number, result)

    return result
end

-- Event handlers for GUI
local gui_handlers = {
    close_button = function(e)
        local player = game.get_player(e.player_index)
        if player then
            logistics_combinator_gui.close_gui(player)
        end
    end,

    -- Add new condition row
    add_condition_button = function(e)
        local player = game.get_player(e.player_index)
        if not player then
            game.print("[mission-control] Error: Player not found")
            return
        end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then
            game.print("[mission-control] Error: Combinator data not found or entity is invalid")
            return
        end

        -- Create new condition
        local new_condition = {
            logical_op = "AND",  -- Default to AND
            left_signal = nil,
            left_wire_filter = "both",
            operator = "<",
            right_type = "constant",
            right_value = 0,
            right_signal = nil,
            right_wire_filter = "both"
        }

        -- Add to storage
        globals.add_logistics_condition(entity.unit_number, new_condition)

        -- Get conditions table
        local conditions_table = get_conditions_table(player)
        if not conditions_table then
            game.print("[mission-control] Error: Conditions table not found")
            return
        end

        local condition_count = #combinator_data.conditions
        game.print("[mission-control] Debug: Adding condition #" .. condition_count .. " to table")
        local is_first = (condition_count == 1)
        gui_utils.create_condition_row(conditions_table, condition_count, new_condition, is_first)
        game.print("[mission-control] Debug: Condition row created successfully")

        -- Re-evaluate
        evaluate_and_update_indicator(player, entity)
    end,

    -- Delete condition row
    delete_condition = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        -- Parse element name to get condition index
        local element_name = e.element.name
        local condition_index = tonumber(element_name:match("cond_(%d+)_delete"))
        if not condition_index then return end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        -- Remove from storage
        globals.remove_logistics_condition(entity.unit_number, condition_index)

        -- Get conditions table
        local conditions_table = get_conditions_table(player)
        if not conditions_table then return end

        -- Clear all existing condition rows
        conditions_table.clear()

        -- Rebuild all condition rows with updated indices
        local updated_conditions = combinator_data.conditions
        if updated_conditions then
            for i, condition in ipairs(updated_conditions) do
                local is_first = (i == 1)
                gui_utils.create_condition_row(conditions_table, i, condition, is_first)
            end
        end

        -- Update visual styles (for AND/OR precedence indicators)
        if updated_conditions then
            gui_utils.update_condition_row_styles(conditions_table, updated_conditions)
        end

        -- Re-evaluate
        evaluate_and_update_indicator(player, entity)
    end,

    -- Toggle right type (constant vs signal)
    right_type_toggle = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        -- Parse element name to get condition index
        local element_name = e.element.name
        local condition_index = tonumber(element_name:match("cond_(%d+)_right_type_toggle"))
        if not condition_index then return end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        local condition = get_condition_by_index(combinator_data, condition_index)
        if not condition then return end

        -- Toggle type
        condition.right_type = (condition.right_type == "constant") and "signal" or "constant"

        -- Update storage explicitly to ensure persistence
        globals.update_logistics_condition(entity.unit_number, condition_index, condition)

        -- Find the condition row
        local condition_row = get_condition_row(player, condition_index)
        if not condition_row then return end

        -- Find elements within the row by their names
        local right_value = condition_row["cond_" .. condition_index .. "_right_value"]
        local right_signal = condition_row["cond_" .. condition_index .. "_right_signal"]

        -- Find right wire filter flow (the parent of the red checkbox)
        local right_wire_flow = find_child_recursive(condition_row, "cond_" .. condition_index .. "_right_wire_")
        -- Update visibility
        if right_value then
            right_value.visible = (condition.right_type == "constant")
        end
        if right_signal then
            right_signal.visible = (condition.right_type == "signal")
        end
        if right_wire_flow then
            game.print("[mission-control] Debug: Toggling right wire filter visibility for condition " .. condition_index)
            right_wire_flow.visible = (condition.right_type == "signal")
        end

        -- Update button sprite and tooltip
        e.element.sprite = (condition.right_type == "signal") and "utility/custom_tag_icon" or "utility/slot"
        e.element.tooltip = (condition.right_type == "signal") and {"gui.switch-to-constant"} or {"gui.switch-to-signal"}

        -- Re-evaluate
        evaluate_and_update_indicator(player, entity)
    end,

    -- Toggle AND/OR operator
    and_or_toggle = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        -- Parse element name to get condition index
        local element_name = e.element.name
        local condition_index = tonumber(element_name:match("cond_(%d+)_and_or_toggle"))
        if not condition_index then return end
        if condition_index == 1 then return end  -- First condition has no AND/OR button

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        local condition = get_condition_by_index(combinator_data, condition_index)
        if not condition then return end

        -- Toggle operator
        condition.logical_op = (condition.logical_op == "OR") and "AND" or "OR"
        local is_or = (condition.logical_op == "OR")

        -- Update storage explicitly to ensure persistence
        globals.update_logistics_condition(entity.unit_number, condition_index, condition)

        -- Update button appearance
        e.element.caption = condition.logical_op
        e.element.tooltip = is_or and {"gui.switch-to-and"} or {"gui.switch-to-or"}
        e.element.style = is_or and "red_button" or "green_button"

        -- Update visual layout of all condition rows
        local conditions_table = get_conditions_table(player)
        if conditions_table then
            gui_utils.update_condition_row_styles(conditions_table, combinator_data.conditions)
        end

        -- Re-evaluate conditions
        evaluate_and_update_indicator(player, entity)
    end,

    -- Save rule button
    save_rule = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        -- Get GUI elements
        local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
        if not frame then return end

        local group_name_field = frame[GUI_NAMES.GROUP_NAME_TEXTFIELD]
        local inject_radio = frame[GUI_NAMES.ACTION_RADIO_INJECT]

        if not group_name_field or not inject_radio then return end

        local group_name = group_name_field.text or ""
        if group_name == "" then
            player.create_local_flying_text{
                text = "Please enter a group name",
                create_at_cursor = true
            }
            return
        end

        -- Determine action from radio buttons
        local action = inject_radio.state and "inject" or "remove"

        -- Create new rule
        local new_rule = {
            group_name = group_name,
            action = action,
            conditions = {},  -- Copy current conditions
            is_active = false,
            last_state = false
        }

        -- Deep copy conditions
        if combinator_data.conditions then
            for _, cond in ipairs(combinator_data.conditions) do
                table.insert(new_rule.conditions, {
                    logical_op = cond.logical_op,
                    left_signal = cond.left_signal,
                    left_wire_filter = cond.left_wire_filter,
                    operator = cond.operator,
                    right_type = cond.right_type,
                    right_value = cond.right_value,
                    right_signal = cond.right_signal,
                    right_wire_filter = cond.right_wire_filter
                })
            end
        end

        -- Add rule to storage
        globals.add_logistics_rule(entity.unit_number, new_rule)

        -- Refresh GUI
        player.create_local_flying_text{
            text = "Rule saved successfully",
            create_at_cursor = true
        }

        -- Note: Full GUI refresh would be better, but for now just notify user
    end
}

-- Register handlers with FLib
flib_gui.add_handlers(gui_handlers)

--- Get power status for an entity
--- @param entity LuaEntity|nil The entity to check
--- @return table Status information with sprite and text
local function get_power_status(entity)
    if entity and entity.valid then
        -- Get energy ratio (current / max)
        local energy_ratio = 0
        if entity.electric_buffer_size and entity.electric_buffer_size > 0 then
            energy_ratio = entity.energy / entity.electric_buffer_size
        elseif entity.energy > 0 then
            -- For entities without buffer, just check if they have any energy
            energy_ratio = 1
        end

        if energy_ratio >= 0.5 then
            -- Green: Working (>50% energy)
            return {
                sprite = "utility/status_working",
                text = "Working"
            }
        elseif energy_ratio > 0 then
            -- Yellow: Low Power (1-50% energy)
            return {
                sprite = "utility/status_yellow",
                text = "Low Power"
            }
        else
            -- Red: No Power (0% energy)
            return {
                sprite = "utility/status_not_working",
                text = "No Power"
            }
        end
    end
    return {
        sprite = "utility/bar_gray_pip",
        text = "Unknown"
    }
end


--- Create signal grid display
--- @param parent LuaGuiElement Parent element to add signal grid to
--- @param entity LuaEntity The combinator entity
--- @return table References to created elements
local function create_signal_sub_grid(parent, entity, signals)
    -- Create scroll pane for signals
    local scroll = parent.add{
        type = "scroll-pane",
        style = "flib_naked_scroll_pane_no_padding",
        style_mods = {
            maximal_height = 200,
            minimal_width = 300
        }
    }

    -- Create table grid with 10 columns
    local signal_table = scroll.add{
        type = "table",
        name = GUI_NAMES.SIGNAL_GRID_TABLE,
        column_count = 10,
        style_mods = {
            horizontal_spacing = 1,
            vertical_spacing = 1
        }
    }

    -- Add signal buttons
    for _, sig_data in ipairs(signals) do
        -- Validate signal_id structure
        if not sig_data or not sig_data.signal_id then
            game.print("[mission-control] Warning: Invalid signal data (no signal_id)")
            goto continue
        end

        if not sig_data.signal_id.name then
            game.print("[mission-control] Warning: Invalid signal_id structure: " .. serpent.line(sig_data.signal_id))
            goto continue
        end     
        local signal_type = sig_data.signal_id.type or "item"
        local sprite_path = signal_type .. "/" .. sig_data.signal_id.name

        -- Determine color indicator sprite based on wire color
        local color_sprite
        if sig_data.wire_color == "red" then
            color_sprite = "mission-control-wire-indicator-red"
        elseif sig_data.wire_color == "green" then
            color_sprite = "mission-control-wire-indicator-green"
        else
            color_sprite = "mission-control-wire-indicator-both"
        end

        -- Add colored indicator overlay sprite behind button

        local item_slot = signal_table.add{
            type = "sprite-button",
            sprite = sprite_path,
            number = sig_data.count,
            tooltip = {"", "[font=default-semibold]", sig_data.signal_id.name, "[/font]\n",
                      "Count: ", sig_data.count, "\n",
                      "Wire: ", sig_data.wire_color},
            style = "slot_button",
            mouse_button_filter = {"left"}
        }
        item_slot.add{
            type = "sprite",
            sprite = color_sprite,
            style_mods = {
                stretch_image_to_widget_size = true
            }
        }

        ::continue::
    end

    -- If no signals, show message
    if #signals == 0 then
        scroll.add{
            type = "label",
            caption = {"", "No input signals"},
            style_mods = {
                font_color = {r = 0.6, g = 0.6, b = 0.6}
            }
        }
    end
    return scroll
end


--- Create signal grid display
--- @param parent LuaGuiElement Parent element to add signal grid to
--- @param entity LuaEntity The combinator entity
--- @return table References to created elements
local function create_signal_grid(parent, entity, signal_grid_frame)


    -- Create frame for signal grid
    local grid_frame = signal_grid_frame or parent.add{
        type = "frame",
        name = GUI_NAMES.SIGNAL_GRID_FRAME,
        direction = "vertical",
        style = "inside_shallow_frame"
    }

    grid_frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Input Signals[/font]"},
        style_mods = {
            bottom_margin = 4
        }
    }
    local signals = circuit_utils.get_input_signals(entity)
    create_signal_sub_grid(grid_frame, entity,signals.red)
    create_signal_sub_grid(grid_frame, entity,signals.green)
    return {signal_grid_frame = grid_frame, signal_grid_table = signal_table}
end


--- Create conditions panel with OR/AND selector and condition rows
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The combinator entity
local function create_conditions_panel(parent, entity)
    local frame = parent.add{
        type = "frame",
        name = GUI_NAMES.CONDITIONS_FRAME,
        direction = "vertical",
        style = "inside_deep_frame"
    }
    frame.style.padding = 8

    -- Header with label
    local header_flow = frame.add{
        type = "flow",
        direction = "horizontal",
        style_mods = {
            vertical_align = "center",
            bottom_margin = 4
        }
    }

    header_flow.add{
        type = "label",
        caption = {"", "[font=default-semibold]Conditions[/font]"}
    }

    -- Scroll pane for condition rows
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.CONDITIONS_SCROLL,
        direction = "vertical",
        style = "flib_naked_scroll_pane",
        style_mods = {
            maximal_height = 300,
            minimal_height = 100
        }
    }

    -- Table to hold condition rows
    local conditions_table = scroll.add{
        type = "table",
        name = GUI_NAMES.CONDITIONS_TABLE,
        column_count = 1,  -- One row per condition
        style_mods = {
            vertical_spacing = 2
        }
    }

    -- Load existing conditions from storage
    local combinator_data = globals.get_logistics_combinator_data(entity.unit_number)
    if combinator_data and combinator_data.conditions then
        for i, condition in ipairs(combinator_data.conditions) do
            local is_first = (i == 1)
            gui_utils.create_condition_row(conditions_table, i, condition, is_first)
        end
    end

    -- Add condition button
    frame.add{
        type = "button",
        name = GUI_NAMES.ADD_CONDITION_BUTTON,
        caption = "+ Add condition",
        style = "green_button",
        tooltip = {"gui.add-condition-tooltip"},
        style_mods = {
            top_margin = 8,
            horizontally_stretchable = true
        }
    }

    return frame
end

--- Format condition expression as human-readable string
--- @param conditions table Array of conditions
--- @return string Human-readable condition expression

--- Create actions section with rule editor
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The combinator entity
--- Create a single logistics section row
--- @param parent LuaGuiElement The parent table element
--- @param section_index number The index of this section
--- @param section_data table|nil The section data {group = "name", multiplier = 1.0}
--- @param force LuaForce The force to get logistics groups from
local function create_logistics_section_row(parent, section_index, section_data, force)
    section_data = section_data or {group = nil, multiplier = 1.0}

    local row = parent.add{
        type = "flow",
        name = GUI_NAMES.SECTION_ROW_PREFIX .. section_index,
        direction = "horizontal",
        style_mods = {
            vertical_align = "center",
            horizontal_spacing = 8,
            bottom_margin = 4
        }
    }

    -- Get logistics groups from force
    local logistic_groups = force.get_logistic_groups() or {}

    -- Create dropdown items: ["<none>", group1, group2, ...]
    local dropdown_items = {"<none>"}
    for _, group_name in ipairs(logistic_groups) do
        table.insert(dropdown_items, group_name)
    end

    -- Find selected index (1-based, 1 = "<none>")
    local selected_index = 1
    if section_data.group then
        for i, group_name in ipairs(dropdown_items) do
            if group_name == section_data.group then
                selected_index = i
                break
            end
        end
    end

    -- Group dropdown selector
    row.add{
        type = "drop-down",
        name = GUI_NAMES.GROUP_PICKER_PREFIX .. section_index,
        items = dropdown_items,
        selected_index = selected_index,
        tooltip = {"gui.select-logistics-group"},
        style_mods = {
            width = 280,
            horizontally_stretchable = false
        }
    }

    -- Multiplier label
    row.add{
        type = "label",
        caption = "×",
        style_mods = {
            font = "default-bold"
        }
    }

    -- Multiplier textfield
    row.add{
        type = "textfield",
        name = GUI_NAMES.MULTIPLIER_PREFIX .. section_index,
        text = tostring(section_data.multiplier or 1.0),
        numeric = true,
        allow_decimal = true,
        tooltip = {"gui.multiplier-tooltip"},
        style_mods = {
            width = 60,
            horizontal_align = "center"
        }
    }

    -- Delete section button
    row.add{
        type = "sprite-button",
        name = GUI_NAMES.DELETE_SECTION_PREFIX .. section_index,
        sprite = "utility/close",
        tooltip = {"gui.delete-section"},
        style = "tool_button_red",
        style_mods = {
            width = 24,
            height = 24
        }
    }

    return row
end

local function create_actions_section(parent, entity, actions_frame)
    local frame = actions_frame or parent.add{
        type = "frame",
        name = GUI_NAMES.ACTIONS_FRAME,
        direction = "vertical",
        style = "inside_deep_frame"
    }
    frame.style.padding = 8

    -- Header
    frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Logistics Sections[/font]"},
        style_mods = {
            bottom_margin = 8
        }
    }

    -- Explanation
    frame.add{
        type = "label",
        caption = "When conditions are TRUE, inject these groups. When FALSE, remove them:",
        style_mods = {
            font_color = {r = 0.7, g = 0.7, b = 0.7},
            bottom_margin = 12,
            single_line = false
        }
    }

    -- Scroll pane for sections
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.SECTIONS_SCROLL,
        vertical_scroll_policy = "auto-and-reserve-space",
        horizontal_scroll_policy = "never",
        style_mods = {
            maximal_height = 300,
            bottom_margin = 8
        }
    }

    -- Table to hold section rows
    local sections_table = scroll.add{
        type = "table",
        name = GUI_NAMES.SECTIONS_TABLE,
        column_count = 1,
        style_mods = {
            horizontally_stretchable = true,
            vertical_spacing = 4
        }
    }

    -- Get combinator data and create rows for existing sections
    local combinator_data = globals.get_logistics_combinator_data(entity.unit_number)
    if combinator_data and combinator_data.logistics_sections then
        for i, section in ipairs(combinator_data.logistics_sections) do
            create_logistics_section_row(sections_table, i, section, entity.force)
        end
    end

    -- Add section button
    frame.add{
        type = "button",
        name = GUI_NAMES.ADD_SECTION_BUTTON,
        caption = "[img=utility/add] Add Section",
        style = "tool_button",
        tooltip = {"gui.add-section-tooltip"},
        style_mods = {
            horizontally_stretchable = true,
            bottom_margin = 8
        }
    }

    -- Connected entities count
    frame.add{
        type = "label",
        name = GUI_NAMES.CONNECTED_ENTITIES_LABEL,
        caption = "Connected entities: 0",
        style_mods = {
            top_margin = 4,
            font_color = {r = 0.7, g = 0.7, b = 0.7}
        }
    }

    return frame
end

--- Create the main logistics combinator GUI
--- @param player LuaPlayer
--- @param entity LuaEntity The logistics combinator entity
function logistics_combinator_gui.create_gui(player, entity)
    -- Close any existing GUI
    logistics_combinator_gui.close_gui(player)

    -- Create main frame using FLib
    local refs = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = GUI_NAMES.MAIN_FRAME,
        direction = "vertical",
        children = {
            -- Titlebar with drag handle
            {
                type = "flow",
                name = GUI_NAMES.TITLEBAR_FLOW,
                style = "flib_titlebar_flow",
                drag_target = GUI_NAMES.MAIN_FRAME,
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = {"entity-name.logistics-combinator"},
                        ignored_by_interaction = true
                    },
                    {
                        type = "empty-widget",
                        name = GUI_NAMES.DRAG_HANDLE,
                        style = "flib_titlebar_drag_handle",
                        ignored_by_interaction = false,
                        drag_target = GUI_NAMES.MAIN_FRAME,
                    },
                    {
                        type = "sprite-button",
                        name = GUI_NAMES.CLOSE_BUTTON,
                        style = "frame_action_button",
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        tooltip = {"gui.close-instruction"},
                        handler = gui_handlers.close_button
                    }
                }
            },
            -- Content frame
            {
                type = "frame",
                style = "inside_shallow_frame",
                direction = "vertical",
                children = {
                    -- Power status
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            horizontal_spacing = 8,
                            bottom_margin = 8
                        },
                        children = {
                            {
                                type = "label",
                                caption = "Status: "
                            },
                            {
                                type = "sprite",
                                name = GUI_NAMES.POWER_LABEL .. "_sprite",
                                sprite = get_power_status(entity).sprite,
                                style_mods = {
                                    stretch_image_to_widget_size = false
                                }
                            },
                            {
                                type = "label",
                                name = GUI_NAMES.POWER_LABEL,
                                caption = get_power_status(entity).text
                            },
                        
                            {
                                type = "empty-widget",
                                name = "spacer",
                                style_mods = {
                                    horizontally_stretchable = true,
                                    vertically_stretchable = false
                                },
                                ignored_by_interaction = true
                            },
                            -- Condition indicator
                            {
                                type = "flow",
                                name = GUI_NAMES.CONDITION_INDICATOR_FLOW,
                                direction = "horizontal",
                                style_mods = {
                                    horizontal_spacing = 4,
                                    vertical_align = "center",
                                    right_margin = 8
                                },
                                children = {
                                    {
                                        type = "sprite",
                                        name = GUI_NAMES.CONDITION_INDICATOR_SPRITE,
                                        sprite = "utility/status_not_working",  -- Default: false
                                        style_mods = {
                                            stretch_image_to_widget_size = false
                                        }
                                    },
                                    {
                                        type = "label",
                                        name = GUI_NAMES.CONDITION_INDICATOR_LABEL,
                                        caption = "[color=red]False[/color]",  -- Default: false
                                        style_mods = {
                                            font = "default-semibold"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    })

    -- Add UI sections after main frame creation
    local content_frame = refs[GUI_NAMES.MAIN_FRAME].children[2]  -- The inside_shallow_frame

    -- Add conditions panel
    create_conditions_panel(content_frame, entity)

    -- Add actions section (rule editor)
    create_actions_section(content_frame, entity)

    -- Add signal grid
    create_signal_grid(content_frame, entity)

    -- Center the window
    refs[GUI_NAMES.MAIN_FRAME].auto_center = true

    -- Store entity reference in player's GUI state
    globals.set_player_gui_entity(player.index, entity, "logistics_combinator")

    -- Evaluate conditions and update indicator
    evaluate_and_update_indicator(player, entity)
end

--- Update the GUI with current combinator state
--- @param player LuaPlayer
function logistics_combinator_gui.update_gui(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return end

    -- Get the entity from player GUI state
    local gui_state = globals.get_player_gui_state(player.index)
    if not gui_state or gui_state.gui_type ~= "logistics_combinator" then return end

    local combinator_data = globals.get_logistics_combinator_data(gui_state.open_entity)
    if not combinator_data or not combinator_data.entity or not combinator_data.entity.valid then
        logistics_combinator_gui.close_gui(player)
        return
    end

    local entity = combinator_data.entity

    -- Update power status
    local power_status = get_power_status(entity)
    local power_sprite = frame[GUI_NAMES.POWER_LABEL .. "_sprite"]
    local power_label = frame[GUI_NAMES.POWER_LABEL]

    if power_sprite then
        power_sprite.sprite = power_status.sprite
    end
    if power_label then
        power_label.caption = power_status.text
    end

    -- Update signal grid
    local signal_grid_frame = frame[GUI_NAMES.SIGNAL_GRID_FRAME]
    if signal_grid_frame then
        -- Destroy and recreate signal grid for fresh data
        signal_grid_frame.clear();
        local content_frame = frame.children[2]  -- The inside_shallow_frame
        create_signal_grid(content_frame, entity, signal_grid_frame)
    end

    -- TODO: Update rule list display
    -- TODO: Update connected entities count
    -- TODO: Update rule status indicators
end

--- Close the logistics combinator GUI
--- @param player LuaPlayer
function logistics_combinator_gui.close_gui(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if frame then
        frame.destroy()
    end
    -- Clear stored entity reference
    globals.clear_player_gui_entity(player.index)
end

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function logistics_combinator_gui.on_gui_opened(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == "logistics-combinator" then
        local player = game.players[event.player_index]

        -- Ensure entity is registered (in case this is from a loaded save or the entity wasn't registered)
        if not globals.get_logistics_combinator_data(entity.unit_number) then
            game.print("[mission-control] Debug: Registering combinator " .. entity.unit_number .. " (was not found in storage)")
            globals.register_logistics_combinator(entity)
        end

        -- Close the default combinator GUI that Factorio opened
        if player.opened == entity then
            player.opened = nil
        end

        -- Open our custom GUI
        logistics_combinator_gui.create_gui(player, entity)
    end
end

--- Handle GUI closed event
--- @param event EventData.on_gui_closed
function logistics_combinator_gui.on_gui_closed(event)
    -- Check if the closed element is our GUI
    if event.element and event.element.name == GUI_NAMES.MAIN_FRAME then
        logistics_combinator_gui.close_gui(game.players[event.player_index])
    end
end

--- Handle GUI click events (delegated to FLib)
--- @param event EventData.on_gui_click
function logistics_combinator_gui.on_gui_click(event)
    -- First try FLib handlers
    flib_gui.dispatch(event)

    -- Then handle custom click events
    local element = event.element
    if not element or not element.valid then return end

    -- Handle add condition button
    if element.name == GUI_NAMES.ADD_CONDITION_BUTTON then
        gui_handlers.add_condition_button(event)
        return
    end

    -- Handle delete condition button
    if element.name:match("^cond_%d+_delete$") then
        gui_handlers.delete_condition(event)
        return
    end

    -- Handle right type toggle
    if element.name:match("^cond_%d+_right_type_toggle$") then
        gui_handlers.right_type_toggle(event)
        return
    end

    -- Handle AND/OR toggle button
    if element.name:match("^cond_%d+_and_or_toggle$") then
        gui_handlers.and_or_toggle(event)
        return
    end

    -- Handle add section button
    if element.name == GUI_NAMES.ADD_SECTION_BUTTON then
        local player = game.get_player(event.player_index)
        if not player then return end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        -- Add new section with default values
        globals.add_logistics_section(entity.unit_number, {
            group = nil,
            multiplier = 1.0
        })

        -- Refresh the actions section to show new row
        local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
        if not frame then return end

        local content_frame = frame.children[2]
        if not content_frame then return end

        local actions_frame = content_frame[GUI_NAMES.ACTIONS_FRAME]
        if actions_frame then
            actions_frame.clear()
        end
        create_actions_section(content_frame, entity, actions_frame)
        return
    end

    -- Handle delete section button
    if element.name:match("^" .. GUI_NAMES.DELETE_SECTION_PREFIX) then
        local section_index = tonumber(element.name:match("^" .. GUI_NAMES.DELETE_SECTION_PREFIX .. "(%d+)$"))
        if not section_index then return end

        local player = game.get_player(event.player_index)
        if not player then return end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then return end

        -- Remove section from storage
        globals.remove_logistics_section(entity.unit_number, section_index)

        -- Refresh the actions section to update indices
        local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
        if not frame then return end

        local content_frame = frame.children[2]
        if not content_frame then return end

        local actions_frame = content_frame[GUI_NAMES.ACTIONS_FRAME]
        if actions_frame then
            actions_frame.clear()
            create_actions_section(content_frame, entity, actions_frame)
        end

        return
    end
end

--- Handle GUI element changed events
--- @param event EventData.on_gui_elem_changed
function logistics_combinator_gui.on_gui_elem_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local combinator_data, entity = get_combinator_data_from_player(player)
    if not combinator_data then return end

    -- Handle left signal changed
    local left_signal_index = element.name:match("^cond_(%d+)_left_signal$")
    if left_signal_index then
        local condition_index = tonumber(left_signal_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            condition.left_signal = element.elem_value
            globals.update_logistics_condition(entity.unit_number, condition_index, condition)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

    -- Handle right signal changed
    local right_signal_index = element.name:match("^cond_(%d+)_right_signal$")
    if right_signal_index then
        local condition_index = tonumber(right_signal_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            condition.right_signal = element.elem_value
            globals.update_logistics_condition(entity.unit_number, condition_index, condition)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

end

--- Handle GUI text changed events
--- @param event EventData.on_gui_text_changed
function logistics_combinator_gui.on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local combinator_data, entity = get_combinator_data_from_player(player)
    if not combinator_data then return end

    -- Handle right value changed
    local value_index = element.name:match("^cond_(%d+)_right_value$")
    if value_index then
        local condition_index = tonumber(value_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            condition.right_value = tonumber(element.text) or 0
            globals.update_logistics_condition(entity.unit_number, condition_index, condition)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

    -- Handle multiplier changed
    if element.name:match("^" .. GUI_NAMES.MULTIPLIER_PREFIX) then
        local section_index = tonumber(element.name:match("^" .. GUI_NAMES.MULTIPLIER_PREFIX .. "(%d+)$"))
        if section_index then
            local sections = globals.get_logistics_sections(entity.unit_number)
            if sections and sections[section_index] then
                -- Update the multiplier in the section
                local section = sections[section_index]
                local multiplier = tonumber(element.text) or 1.0
                -- Ensure multiplier is positive
                if multiplier < 0 then multiplier = 0 end
                section.multiplier = multiplier
                globals.update_logistics_section(entity.unit_number, section_index, section)
            end
        end
        return
    end
end

--- Handle GUI selection state changed events
--- @param event EventData.on_gui_selection_state_changed
function logistics_combinator_gui.on_gui_selection_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local combinator_data, entity = get_combinator_data_from_player(player)
    if not combinator_data then return end

    -- Handle operator changed
    local operator_index = element.name:match("^cond_(%d+)_operator$")
    if operator_index then
        local condition_index = tonumber(operator_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            condition.operator = gui_utils.get_operator_from_index(element.selected_index)
            globals.update_logistics_condition(entity.unit_number, condition_index, condition)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

    -- Handle logistics group picker changed
    if element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX) then
        local section_index = tonumber(element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX .. "(%d+)$"))
        if section_index then
            local sections = globals.get_logistics_sections(entity.unit_number)
            if sections and sections[section_index] then
                -- Get selected group name from dropdown
                local selected_item = element.items[element.selected_index]
                -- Update the group in the section ("<none>" means nil)
                local section = sections[section_index]
                section.group = (selected_item == "<none>") and nil or selected_item
                globals.update_logistics_section(entity.unit_number, section_index, section)
            end
        end
        return
    end
end

--- Handle GUI checkbox state changed events
--- @param event EventData.on_gui_checked_state_changed
function logistics_combinator_gui.on_gui_checked_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local combinator_data, entity = get_combinator_data_from_player(player)
    if not combinator_data then return end

    -- Handle action radio buttons (ensure only one is selected)
    if element.name == GUI_NAMES.ACTION_RADIO_INJECT then
        local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
        if frame then
            local remove_radio = frame[GUI_NAMES.ACTION_RADIO_REMOVE]
            if remove_radio then
                remove_radio.state = not element.state
            end
        end
        return
    elseif element.name == GUI_NAMES.ACTION_RADIO_REMOVE then
        local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
        if frame then
            local inject_radio = frame[GUI_NAMES.ACTION_RADIO_INJECT]
            if inject_radio then
                inject_radio.state = not element.state
            end
        end
        return
    end

    -- Handle left wire filter checkboxes
    local left_wire_index = element.name:match("^cond_(%d+)_left_wire_(red)$") or element.name:match("^cond_(%d+)_left_wire_(green)$")
    if left_wire_index then
        local condition_index = tonumber(left_wire_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            local condition_row = get_condition_row(player, condition_index)
            if condition_row then
                -- Find checkboxes by recursively searching nested GUI structure
                local red_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_left_wire_red")
                local green_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_left_wire_green")

                if red_checkbox and green_checkbox then
                    game.print("[mission-control] Debug: Left wire filter changed for condition " .. condition_index)
                    condition.left_wire_filter = gui_utils.get_wire_filter_from_checkboxes(red_checkbox.state, green_checkbox.state)
                    globals.update_logistics_condition(entity.unit_number, condition_index, condition)
                    evaluate_and_update_indicator(player, entity)
                end
            end
        end
        return
    end

    -- Handle right wire filter checkboxes
    local right_wire_index = element.name:match("^cond_(%d+)_right_wire_(red)$") or element.name:match("^cond_(%d+)_right_wire_(green)$")
    if right_wire_index then
        local condition_index = tonumber(right_wire_index)
        local condition = get_condition_by_index(combinator_data, condition_index)
        if condition then
            local condition_row = get_condition_row(player, condition_index)
            if condition_row then
                local red_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_right_wire_red")
                local green_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_right_wire_green")

                if red_checkbox and green_checkbox then
                    condition.right_wire_filter = gui_utils.get_wire_filter_from_checkboxes(red_checkbox.state, green_checkbox.state)
                    globals.update_logistics_condition(entity.unit_number, condition_index, condition)
                    evaluate_and_update_indicator(player, entity)
                end
            end
        end
        return
    end
end

return logistics_combinator_gui
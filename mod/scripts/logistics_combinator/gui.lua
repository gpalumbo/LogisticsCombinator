-- Mission Control Mod - Logistics Combinator GUI
-- This module handles the GUI for logistics combinators

local flib_gui = require("__flib__.gui")
local gui_utils = require("lib.gui_utils")
local gui_entity = require("lib.gui.gui_entity")
local gui_circuit_inputs = require("lib.gui.gui_circuit_inputs")
local globals = require("scripts.globals")
local circuit_utils = require("lib.circuit_utils")
local logistics_combinator = require("scripts.logistics_combinator.logistics_combinator")

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
    if not gui_state or not gui_state.open_entity then return nil, nil end

    local entity = gui_state.open_entity
    if not entity.valid then return nil, nil end

    -- Get data using universal getter (works for both ghost and real)
    local combinator_data = globals.get_logistics_combinator_data(entity)
    if not combinator_data then return nil, nil end

    return combinator_data, entity
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
    local combinator_data = globals.get_logistics_combinator_data(entity)
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
            return
        end

        local combinator_data, entity = get_combinator_data_from_player(player)
        if not combinator_data then
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

        -- Add to data and write back using universal function
        if not combinator_data.conditions then
            combinator_data.conditions = {}
        end
        table.insert(combinator_data.conditions, new_condition)
        globals.update_combinator_data_universal(entity, combinator_data)

        -- Get conditions table
        local conditions_table = get_conditions_table(player)
        if not conditions_table then
            return
        end

        local condition_count = #combinator_data.conditions
        local is_first = (condition_count == 1)
        gui_utils.create_condition_row(conditions_table, condition_count, new_condition, is_first, true)

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

        -- Remove from data and write back
        if combinator_data.conditions and combinator_data.conditions[condition_index] then
            table.remove(combinator_data.conditions, condition_index)
            globals.update_combinator_data_universal(entity, combinator_data)
        end

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
                gui_utils.create_condition_row(conditions_table, i, condition, is_first, true)
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

        -- Update entire combinator data using universal function
        combinator_data.conditions[condition_index] = condition
        globals.update_combinator_data_universal(entity, combinator_data)

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

        -- Update entire combinator data using universal function
        combinator_data.conditions[condition_index] = condition
        globals.update_combinator_data_universal(entity, combinator_data)

        -- Update button appearance
        e.element.caption = condition.logical_op
        e.element.tooltip = is_or and {"gui.switch-to-and"} or {"gui.switch-to-or"}
        e.element.style = "button"

        -- Update visual layout of all condition rows
        local conditions_table = get_conditions_table(player)
        if conditions_table then
            gui_utils.update_condition_row_styles(conditions_table, combinator_data.conditions)
        end

        -- Re-evaluate conditions
        evaluate_and_update_indicator(player, entity)
    end
}

-- Register handlers with FLib
flib_gui.add_handlers(gui_handlers)

--- Create signal grid display (wrapper for shared library function)
--- @param parent LuaGuiElement Parent element to add signal grid to
--- @param entity LuaEntity The combinator entity
--- @param signal_grid_frame LuaGuiElement|nil Optional existing frame to reuse
--- @return table References to created elements
local function create_signal_grid(parent, entity, signal_grid_frame)
    return gui_circuit_inputs.create_signal_grid(parent, entity, signal_grid_frame, GUI_NAMES.SIGNAL_GRID_FRAME)
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
    frame.style.horizontally_stretchable = true

    -- Header with label
    local header_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    header_flow.style.vertical_align = "center"
    header_flow.style.bottom_margin = 4

    header_flow.add{
        type = "label",
        caption = {"", "[font=default-semibold]Conditions[/font]"}
    }

    -- Scroll pane for condition rows
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.CONDITIONS_SCROLL,
        direction = "vertical",
        style = "flib_naked_scroll_pane"
    }
    scroll.style.maximal_height = 300
    scroll.style.minimal_height = 100
    scroll.style.horizontally_stretchable = true

    -- Table to hold condition rows
    local conditions_table = scroll.add{
        type = "table",
        name = GUI_NAMES.CONDITIONS_TABLE,
        column_count = 1  -- One row per condition
    }
    conditions_table.style.vertical_spacing = 2
    conditions_table.style.horizontally_stretchable = true

    -- Load existing conditions from storage (use universal function - works for ghosts and real entities)
    local combinator_data = globals.get_logistics_combinator_data(entity)
    if combinator_data and combinator_data.conditions then
        for i, condition in ipairs(combinator_data.conditions) do
            local is_first = (i == 1)
            gui_utils.create_condition_row(conditions_table, i, condition, is_first, true)
        end
    end

    -- Add condition button
    local add_button = frame.add{
        type = "button",
        name = GUI_NAMES.ADD_CONDITION_BUTTON,
        caption = "+ Add condition",
        style = "green_button",
        tooltip = {"gui.add-condition-tooltip"}
    }
    add_button.style.top_margin = 8
    add_button.style.horizontally_stretchable = true

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
        direction = "horizontal"
    }
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 8
    row.style.bottom_margin = 4

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
    local group_dropdown = row.add{
        type = "drop-down",
        name = GUI_NAMES.GROUP_PICKER_PREFIX .. section_index,
        items = dropdown_items,
        selected_index = selected_index,
        tooltip = {"gui.select-logistics-group"}
    }
    group_dropdown.style.width = 280
    group_dropdown.style.horizontally_stretchable = false

    -- Multiplier label
    local mult_label = row.add{
        type = "label",
        caption = "×"
    }
    mult_label.style.font = "default-bold"

    -- Multiplier textfield
    local mult_textfield = row.add{
        type = "textfield",
        name = GUI_NAMES.MULTIPLIER_PREFIX .. section_index,
        text = tostring(section_data.multiplier or 1.0),
        numeric = true,
        allow_decimal = true,
        tooltip = {"gui.multiplier-tooltip"}
    }
    mult_textfield.style.width = 60
    mult_textfield.style.horizontal_align = "center"

    -- Delete section button
    local delete_button = row.add{
        type = "sprite-button",
        name = GUI_NAMES.DELETE_SECTION_PREFIX .. section_index,
        sprite = "utility/close",
        tooltip = {"gui.delete-section"},
        style = "tool_button_red"
    }
    delete_button.style.width = 24
    delete_button.style.height = 24

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
    local header_label = frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Logistics Sections[/font]"}
    }
    header_label.style.bottom_margin = 8

    -- Explanation
    local explanation_label = frame.add{
        type = "label",
        caption = "When conditions are TRUE, inject these groups. When FALSE, remove them:"
    }
    explanation_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    explanation_label.style.bottom_margin = 12
    explanation_label.style.single_line = false

    -- Scroll pane for sections
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.SECTIONS_SCROLL,
        vertical_scroll_policy = "auto-and-reserve-space",
        horizontal_scroll_policy = "never"
    }
    scroll.style.maximal_height = 300
    scroll.style.bottom_margin = 8

    -- Table to hold section rows
    local sections_table = scroll.add{
        type = "table",
        name = GUI_NAMES.SECTIONS_TABLE,
        column_count = 1
    }
    sections_table.style.horizontally_stretchable = true
    sections_table.style.vertical_spacing = 4

    -- Get combinator data and create rows for existing sections
    local combinator_data = globals.get_logistics_combinator_data(entity)
    if combinator_data and combinator_data.logistics_sections then
        for i, section in ipairs(combinator_data.logistics_sections) do
            create_logistics_section_row(sections_table, i, section, entity.force)
        end
    end

    -- Add section button
    local add_section_button = frame.add{
        type = "button",
        name = GUI_NAMES.ADD_SECTION_BUTTON,
        caption = "[img=utility/add] Add Section",
        style = "tool_button",
        tooltip = {"gui.add-section-tooltip"}
    }
    add_section_button.style.horizontally_stretchable = true
    add_section_button.style.bottom_margin = 8

    -- Connected entities count
    local connected_label = frame.add{
        type = "label",
        name = GUI_NAMES.CONNECTED_ENTITIES_LABEL,
        caption = "Connected entities: 0"
    }
    connected_label.style.top_margin = 4
    connected_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}

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
                                sprite = gui_entity.get_power_status(entity).sprite,
                                style_mods = {
                                    stretch_image_to_widget_size = false
                                }
                            },
                            {
                                type = "label",
                                name = GUI_NAMES.POWER_LABEL,
                                caption = gui_entity.get_power_status(entity).text
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

    -- Make the GUI respond to ESC key by setting it as the player's opened GUI
    player.opened = refs[GUI_NAMES.MAIN_FRAME]

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
    local power_status = gui_entity.get_power_status(entity)
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
    -- Get the entity before clearing the reference
    local gui_state = globals.get_player_gui_state(player.index)
    local entity = nil

    if gui_state and gui_state.open_entity then
        local combinator_data = globals.get_logistics_combinator_data(gui_state.open_entity)
        if combinator_data and combinator_data.entity and combinator_data.entity.valid then
            entity = combinator_data.entity
        end
    end

    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if frame then
        frame.destroy()
    end

    -- Clear stored entity reference
    globals.clear_player_gui_entity(player.index)

    -- If we had an entity, update its state immediately
    if entity and entity.valid then
        local unit_number = entity.unit_number
        if unit_number then
            -- Update connected entities in case wires changed while GUI was open
            logistics_combinator.update_connected_entities(unit_number)

            -- Immediately process rules to apply any GUI changes
            -- Pass force_update=true to update multipliers even if condition state hasn't changed
            logistics_combinator.process_rules(unit_number, true)
        end
    end
end

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function logistics_combinator_gui.on_gui_opened(event)
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end

    -- Check for both real and ghost logistics combinators
    local entity_name = entity.name
    if entity.type == "entity-ghost" then
        entity_name = entity.ghost_name
    end

    if entity_name ~= "logistics-combinator" then return end

    local player = game.players[event.player_index]

    -- For REAL entities only: ensure registered and update connections
    if entity.type ~= "entity-ghost" then
        -- Use universal function - pass entity directly
        if not globals.get_logistics_combinator_data(entity) then
            globals.register_logistics_combinator(entity)
        end

        -- Update connected entities for immediate feedback (only real entities have circuit connections)
        logistics_combinator.update_connected_entities(entity.unit_number)
    end

    -- Close the default combinator GUI that Factorio opened (works for both ghost and real)
    if player.opened == entity then
        player.opened = nil
    end

    -- Open our custom GUI (works for both ghost and real)
    logistics_combinator_gui.create_gui(player, entity)
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
        if not combinator_data.logistics_sections then
            combinator_data.logistics_sections = {}
        end
        table.insert(combinator_data.logistics_sections, {
            group = nil,
            multiplier = 1.0
        })
        globals.update_combinator_data_universal(entity, combinator_data)

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

        -- Remove section from data and write back
        if combinator_data.logistics_sections and combinator_data.logistics_sections[section_index] then
            table.remove(combinator_data.logistics_sections, section_index)
            globals.update_combinator_data_universal(entity, combinator_data)
        end

        if(entity.type ~= "entity-ghost") then
            -- Trigger reconciliation to remove any injected sections for the deleted section
            local condition_result = globals.get_condition_result(entity.unit_number)
            logistics_combinator.reconcile_sections(entity.unit_number, condition_result)
        end

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
            -- Validate signal (all types are valid on left side now)
            local error_key = gui_utils.validate_condition_signal(element.elem_value)
            if error_key then
                -- Clear the invalid selection and notify player
                element.elem_value = condition.left_signal  -- Revert to previous value
                player.create_local_flying_text{
                    text = {error_key},
                    position = player.position,
                    create_at_cursor = true
                }
                return
            end

            -- If left side changed FROM EACH to something else, and right side is EACH,
            -- we need to clear the right signal (EACH on right is only valid with EACH on left)
            local old_left_type = gui_utils.get_signal_eval_type and gui_utils.get_signal_eval_type(condition.left_signal)
            local new_left_type = gui_utils.get_signal_eval_type and gui_utils.get_signal_eval_type(element.elem_value)
            local right_type = gui_utils.get_signal_eval_type and gui_utils.get_signal_eval_type(condition.right_signal)

            if old_left_type == "each" and new_left_type ~= "each" and right_type == "each" then
                -- Clear the right signal since EACH is no longer valid there
                condition.right_signal = nil
                -- Update the GUI element if it exists
                local gui_root = player.gui.screen[GUI_NAMES.MAIN_FRAME]
                if gui_root then
                    local right_signal_elem = gui_utils.find_child_recursive(gui_root, "cond_" .. condition_index .. "_right_signal")
                    if right_signal_elem and right_signal_elem.valid then
                        right_signal_elem.elem_value = nil
                    end
                end
            end

            condition.left_signal = element.elem_value
            combinator_data.conditions[condition_index] = condition
            globals.update_combinator_data_universal(entity, combinator_data)
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
            -- Validate signal - NORMAL always allowed, EACH only if left is EACH
            local error_key = gui_utils.validate_right_signal(element.elem_value, condition.left_signal)
            if error_key then
                -- Clear the invalid selection and notify player
                element.elem_value = condition.right_signal  -- Revert to previous value
                player.create_local_flying_text{
                    text = {error_key},
                    position = player.position,
                    create_at_cursor = true
                }
                return
            end
            condition.right_signal = element.elem_value
            combinator_data.conditions[condition_index] = condition
            globals.update_combinator_data_universal(entity, combinator_data)
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
            combinator_data.conditions[condition_index] = condition
            globals.update_combinator_data_universal(entity, combinator_data)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

    -- Handle multiplier changed
    if element.name:match("^" .. GUI_NAMES.MULTIPLIER_PREFIX) then
        local section_index = tonumber(element.name:match("^" .. GUI_NAMES.MULTIPLIER_PREFIX .. "(%d+)$"))
        if section_index then
            if combinator_data.logistics_sections and combinator_data.logistics_sections[section_index] then
                -- Update the multiplier in the section
                local section = combinator_data.logistics_sections[section_index]
                local multiplier = tonumber(element.text) or 1.0
                -- Ensure multiplier is positive
                if multiplier < 0 then multiplier = 0 end
                section.multiplier = multiplier
                combinator_data.logistics_sections[section_index] = section
                globals.update_combinator_data_universal(entity, combinator_data)

                -- Trigger reconciliation to update injected sections
                -- Only call if real entity (not ghost)
                if entity.type ~= "entity-ghost" then
                    local condition_result = globals.get_condition_result(entity.unit_number)
                    logistics_combinator.reconcile_sections(entity.unit_number, condition_result)
                end
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
            combinator_data.conditions[condition_index] = condition
            globals.update_combinator_data_universal(entity, combinator_data)
            evaluate_and_update_indicator(player, entity)
        end
        return
    end

    -- Handle logistics group picker changed
    if element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX) then
        local section_index = tonumber(element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX .. "(%d+)$"))
        if section_index then
            if combinator_data.logistics_sections and combinator_data.logistics_sections[section_index] then
                -- Get selected group name from dropdown
                local selected_item = element.items[element.selected_index]
                -- Update the group in the section ("<none>" means nil)
                local section = combinator_data.logistics_sections[section_index]
                section.group = (selected_item == "<none>") and nil or selected_item
                combinator_data.logistics_sections[section_index] = section
                globals.update_combinator_data_universal(entity, combinator_data)

                -- Trigger reconciliation to update injected sections
                -- Only call if real entity (not ghost)
                if entity.type ~= "entity-ghost" then
                    local condition_result = globals.get_condition_result(entity.unit_number)
                    logistics_combinator.reconcile_sections(entity.unit_number, condition_result)
                end
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
                    condition.left_wire_filter = gui_utils.get_wire_filter_from_checkboxes(red_checkbox.state, green_checkbox.state)
                    combinator_data.conditions[condition_index] = condition
                    globals.update_combinator_data_universal(entity, combinator_data)
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
                    combinator_data.conditions[condition_index] = condition
                    globals.update_combinator_data_universal(entity, combinator_data)
                    evaluate_and_update_indicator(player, entity)
                end
            end
        end
        return
    end
end

return logistics_combinator_gui
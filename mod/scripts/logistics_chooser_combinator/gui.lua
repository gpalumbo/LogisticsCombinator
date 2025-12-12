-- Mission Control Mod - Logistics Chooser Combinator GUI
-- This module handles the GUI for logistics chooser combinators
-- The chooser allows selecting ONE logistics group from a list based on signal values

local flib_gui = require("__flib__.gui")
local gui_utils = require("lib.gui_utils")
local signal_utils = require("lib.signal_utils")
local gui_entity = require("lib.gui.gui_entity")
local gui_circuit_inputs = require("lib.gui.gui_circuit_inputs")
local circuit_utils = require("lib.circuit_utils")
local globals = require("scripts.globals")

local logistics_chooser_gui = {}

-- GUI element names
local GUI_NAMES = {
    MAIN_FRAME = "logistics_chooser_frame",
    TITLEBAR_FLOW = "logistics_chooser_titlebar_flow",
    DRAG_HANDLE = "logistics_chooser_drag_handle",
    CLOSE_BUTTON = "logistics_chooser_close",
    POWER_LABEL = "logistics_chooser_power",
    MODE_SWITCH = "logistics_chooser_mode_switch",
    SIGNAL_GRID_FRAME = "logistics_chooser_signal_grid_frame",
    SIGNAL_GRID_TABLE = "logistics_chooser_signal_grid_table",
    GROUPS_FRAME = "logistics_chooser_groups_frame",
    GROUPS_SCROLL = "logistics_chooser_groups_scroll",
    GROUPS_TABLE = "logistics_chooser_groups_table",
    ADD_GROUP_BUTTON = "logistics_chooser_add_group",
    GROUP_ROW_PREFIX = "logistics_chooser_group_row_",
    GROUP_PICKER_PREFIX = "logistics_chooser_group_picker_",
    SIGNAL_PICKER_PREFIX = "logistics_chooser_signal_picker_",
    OPERATOR_DROPDOWN_PREFIX = "logistics_chooser_operator_",
    VALUE_TEXTFIELD_PREFIX = "logistics_chooser_value_",
    MULTIPLIER_PREFIX = "logistics_chooser_multiplier_",
    STATUS_SPRITE_PREFIX = "logistics_chooser_status_",
    DELETE_GROUP_PREFIX = "logistics_chooser_delete_group_",
    CONNECTED_ENTITIES_LABEL = "logistics_chooser_connected_count"
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get chooser data from player's GUI state
--- @param player LuaPlayer
--- @return table|nil chooser_data, LuaEntity|nil entity
local function get_chooser_data_from_player(player)
    if not player then return nil, nil end

    local gui_state = globals.get_player_gui_state(player.index)
    if not gui_state or not gui_state.open_entity or not gui_state.open_entity.valid then
        return nil, nil
    end

    local entity = gui_state.open_entity

    -- Use the universal get_logistics_chooser_data (handles both ghost and real entities)
    local chooser_data = globals.get_logistics_chooser_data(entity)
    if not chooser_data then
        return nil, nil
    end

    -- For real entities, validate that entity reference is still valid
    if not gui_state.is_ghost and chooser_data.entity and not chooser_data.entity.valid then
        return nil, nil
    end

    return chooser_data, entity
end

--- Get groups table GUI element
--- @param player LuaPlayer
--- @return LuaGuiElement|nil groups_table
local function get_groups_table(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return nil end

    local content_frame = frame.children[2]  -- inside_shallow_frame
    if not content_frame then return nil end

    local groups_frame = content_frame[GUI_NAMES.GROUPS_FRAME]
    if not groups_frame then return nil end

    local scroll = groups_frame[GUI_NAMES.GROUPS_SCROLL]
    if not scroll then return nil end

    return scroll[GUI_NAMES.GROUPS_TABLE]
end

--- Evaluate all group conditions and update status indicators
--- @param player LuaPlayer
--- @param chooser_data table The chooser data
--- @param entity LuaEntity The chooser entity
local function evaluate_and_update_statuses(player, chooser_data, entity)
    if not chooser_data.groups or #chooser_data.groups == 0 then return end

    local groups_table = get_groups_table(player)
    if not groups_table then return end

    -- Get circuit signals using circuit_utils
    local input_signals = circuit_utils.get_input_signals(entity, "combinator_input")
    if not input_signals then
        input_signals = {red = {}, green = {}}
    end

    -- Convert signal arrays to tables for evaluation
    local red_signals = {}
    local green_signals = {}

    for _, sig_data in ipairs(input_signals.red or {}) do
        if sig_data.signal_id then
            local key = signal_utils.get_signal_key(sig_data.signal_id)
            red_signals[key] = sig_data.count
        end
    end

    for _, sig_data in ipairs(input_signals.green or {}) do
        if sig_data.signal_id then
            local key = signal_utils.get_signal_key(sig_data.signal_id)
            green_signals[key] = sig_data.count
        end
    end

    -- Evaluate each group's condition
    for i, group in ipairs(chooser_data.groups) do
        local is_active = false

        if group.condition then
            -- Evaluate the condition using gui_utils
            -- Note: We pass an array with a single condition since each group has one condition
            is_active = signal_utils.evaluate_complex_conditions(
                {group.condition},
                red_signals,
                green_signals
            )
        end

        -- Update the group's is_active state
        group.is_active = is_active

        -- Update the GUI sprite (navigate to correct location in hierarchy)
        -- Structure: groups_table -> row_container -> top_row (first child) -> status_sprite
        local row_container = groups_table[GUI_NAMES.GROUP_ROW_PREFIX .. i]
        if row_container and row_container.valid then
            -- The status_sprite is in the top_row, which is the first child of row_container
            local top_row = row_container.children[1]
            if top_row and top_row.valid then
                local status_sprite = top_row[GUI_NAMES.STATUS_SPRITE_PREFIX .. i]
                if status_sprite and status_sprite.valid then
                    status_sprite.sprite = is_active and "utility/status_working" or "utility/status_not_working"
                    status_sprite.tooltip = is_active and "Condition TRUE - Group active" or "Condition FALSE - Group inactive"
                end
            end
        end
    end

    -- Store updated group states
    for i, group in ipairs(chooser_data.groups) do
        globals.update_chooser_group_universal(entity, i, group)
    end
end

-- ============================================================================
-- GUI ELEMENT CREATION HELPERS (must be before handlers that use them)
-- ============================================================================

--- Create a single group selection row
--- @param parent LuaGuiElement The parent table element
--- @param group_index number The index of this group
--- @param group_data table The group data {group, condition, multiplier, is_active}
--- @param force LuaForce The force to get logistics groups from
local function create_group_row(parent, group_index, group_data, force)
    -- Ensure group_data has complete structure with defaults
    group_data = group_data or {}

    -- Ensure condition exists and has all required fields
    if not group_data.condition then
        group_data.condition = {}
    end

    -- Fill in missing condition fields with defaults
    local condition = group_data.condition
    if not condition.left_wire_filter then condition.left_wire_filter = "both" end
    if not condition.operator then condition.operator = "=" end
    if not condition.right_type then condition.right_type = "constant" end
    if not condition.right_value then condition.right_value = 0 end
    if not condition.right_wire_filter then condition.right_wire_filter = "both" end

    -- Ensure other group fields exist
    if group_data.multiplier == nil then group_data.multiplier = 1.0 end
    if group_data.is_active == nil then group_data.is_active = false end

    -- Main row container
    local row_container = parent.add{
        type = "flow",
        name = GUI_NAMES.GROUP_ROW_PREFIX .. group_index,
        direction = "vertical"
    }
    row_container.style.bottom_margin = 8

    -- Top row: Group selector and multiplier
    local top_row = row_container.add{
        type = "flow",
        direction = "horizontal"
    }
    top_row.style.vertical_align = "center"
    top_row.style.horizontal_spacing = 8

    -- Status indicator LED (shows if condition is currently true/false)
    local status_sprite = top_row.add{
        type = "sprite",
        name = GUI_NAMES.STATUS_SPRITE_PREFIX .. group_index,
        sprite = group_data.is_active and "utility/status_working" or "utility/status_not_working",
        tooltip = group_data.is_active and "Condition TRUE - Group active" or "Condition FALSE - Group inactive"
    }
    status_sprite.style.width = 16
    status_sprite.style.height = 16
    status_sprite.style.stretch_image_to_widget_size = true
    status_sprite.style.right_margin = 4

    -- Get logistics groups from force
    local logistic_groups = force.get_logistic_groups() or {}

    -- Create dropdown items: ["<none>", group1, group2, ...]
    local dropdown_items = {"<none>"}
    for _, group_name in ipairs(logistic_groups) do
        table.insert(dropdown_items, group_name)
    end

    -- Find selected index
    local selected_index = 1
    if group_data.group then
        for i, group_name in ipairs(dropdown_items) do
            if group_name == group_data.group then
                selected_index = i
                break
            end
        end
    end

    -- Group dropdown selector
    local group_dropdown = top_row.add{
        type = "drop-down",
        name = GUI_NAMES.GROUP_PICKER_PREFIX .. group_index,
        items = dropdown_items,
        selected_index = selected_index,
        tooltip = "Select logistics group to activate"
    }
    group_dropdown.style.width = 200
    group_dropdown.style.horizontally_stretchable = false

    -- Multiplier label
    local mult_label = top_row.add{
        type = "label",
        caption = "X"
    }
    mult_label.style.font = "default-bold"
    mult_label.style.left_margin = 8
    mult_label.style.right_margin = 2

    -- Multiplier textfield
    local mult_textfield = top_row.add{
        type = "textfield",
        name = GUI_NAMES.MULTIPLIER_PREFIX .. group_index,
        text = tostring(group_data.multiplier or 1.0),
        numeric = true,
        allow_decimal = true,
        tooltip = "Multiplier for group quantities"
    }
    mult_textfield.style.width = 60
    mult_textfield.style.horizontal_align = "center"

    -- Spacer
    local spacer = top_row.add{
        type = "empty-widget"
    }
    spacer.style.horizontally_stretchable = true

    -- Delete button
    local delete_button = top_row.add{
        type = "sprite-button",
        name = GUI_NAMES.DELETE_GROUP_PREFIX .. group_index,
        sprite = "utility/close",
        tooltip = "Remove this group",
        style = "tool_button_red"
    }
    delete_button.style.width = 24
    delete_button.style.height = 24

    -- Bottom row: Condition using shared component
    local condition_container = row_container.add{
        type = "flow",
        direction = "horizontal"
    }
    condition_container.style.left_padding = 60  -- Indent condition row
    condition_container.style.horizontal_spacing = 4

    -- "When" label
    condition_container.add{
        type = "label",
        caption = "when"
    }

    -- Create condition row using shared component (always treat as "first" - no AND/OR)
    -- Pass false for show_delete_button since we use the top-row delete button
    local condition_table = condition_container.add{
        type = "table",
        column_count = 1
    }
    gui_utils.create_condition_row(condition_table, group_index, group_data.condition, true, false)

    return row_container
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local gui_handlers = {
    chooser_close_button = function(e)
        local player = game.get_player(e.player_index)
        if player then
            logistics_chooser_gui.close_gui(player)
        end
    end,

    -- Add new group selection row
    chooser_add_group_button = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        local chooser_data, entity = get_chooser_data_from_player(player)
        if not chooser_data or not entity then
            return
        end

        -- Create new group selection with full condition structure
        local new_group = {
            group = nil,          -- Logistics group name
            condition = {
                left_wire_filter = "both",  -- "red", "green", "both", or "none"
                left_signal = nil,
                operator = "=",
                right_type = "constant",
                right_value = 0,
                right_signal = nil,
                right_wire_filter = "both"  -- "red", "green", "both", or "none"
            },
            multiplier = 1.0,     -- Quantity multiplier
            is_active = false     -- Condition evaluation result
        }

        -- Add to storage using universal function (handles both ghosts and real entities)
        globals.add_chooser_group_universal(entity, new_group)

        -- Refresh chooser_data after adding
        chooser_data, entity = get_chooser_data_from_player(player)

        -- Get groups table
        local groups_table = get_groups_table(player)
        if not groups_table then return end

        local group_count = #chooser_data.groups
        create_group_row(groups_table, group_count, new_group, entity.force)
    end,

    -- Delete group row
    chooser_delete_group = function(e)
        local player = game.get_player(e.player_index)
        if not player then return end

        -- Parse element name to get group index
        local element_name = e.element.name
        local group_index = tonumber(element_name:match("^" .. GUI_NAMES.DELETE_GROUP_PREFIX .. "(%d+)$"))
        if not group_index then return end

        local chooser_data, entity = get_chooser_data_from_player(player)
        if not chooser_data or not entity then
            return
        end

        -- Remove from storage using universal function (handles both ghosts and real entities)
        globals.remove_chooser_group_universal(entity, group_index)

        -- Refresh chooser_data after removing
        chooser_data, entity = get_chooser_data_from_player(player)

        -- Get groups table
        local groups_table = get_groups_table(player)
        if not groups_table then return end

        -- Clear and rebuild
        groups_table.clear()

        -- Rebuild all group rows with updated indices
        local updated_groups = chooser_data.groups
        if updated_groups then
            for i, group in ipairs(updated_groups) do
                create_group_row(groups_table, i, group, entity.force)
            end
        end
    end
}

-- Register handlers with FLib
flib_gui.add_handlers(gui_handlers)

-- ============================================================================
-- GUI CREATION FUNCTIONS
-- ============================================================================

--- Create signal grid display (wrapper for shared library function)
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The chooser entity
--- @param signal_grid_frame LuaGuiElement|nil Existing frame to reuse
--- @return table References to created elements
local function create_signal_grid(parent, entity, signal_grid_frame)
    return gui_circuit_inputs.create_signal_grid(parent, entity, signal_grid_frame, GUI_NAMES.SIGNAL_GRID_FRAME)
end

--- Create groups selection panel
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The chooser entity
local function create_groups_panel(parent, entity)
    local frame = parent.add{
        type = "frame",
        name = GUI_NAMES.GROUPS_FRAME,
        direction = "vertical",
        style = "inside_deep_frame"
    }
    frame.style.padding = 8
    frame.style.horizontally_stretchable = true

    -- Header
    local header_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    header_flow.style.vertical_align = "center"
    header_flow.style.bottom_margin = 4

    header_flow.add{
        type = "label",
        caption = {"", "[font=default-semibold]Group Selection[/font]"}
    }

    -- Explanation
    local explanation = frame.add{
        type = "label",
        caption = "Select which logistics group to activate based on signal values:"
    }
    explanation.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    explanation.style.bottom_margin = 8
    explanation.style.single_line = false

    -- Scroll pane for group rows
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.GROUPS_SCROLL,
        direction = "vertical",
        style = "flib_naked_scroll_pane"
    }
    scroll.style.maximal_height = 400
    scroll.style.minimal_height = 100
    scroll.style.horizontally_stretchable = true

    -- Table to hold group rows
    local groups_table = scroll.add{
        type = "table",
        name = GUI_NAMES.GROUPS_TABLE,
        column_count = 1
    }
    groups_table.style.vertical_spacing = 2
    groups_table.style.horizontally_stretchable = true

    -- Load existing groups from storage
    local chooser_data = globals.get_logistics_chooser_data(entity)
    if chooser_data and chooser_data.groups then
        for i, group in ipairs(chooser_data.groups) do
            create_group_row(groups_table, i, group, entity.force)
        end
    end

    -- Add group button
    local add_button = frame.add{
        type = "button",
        name = GUI_NAMES.ADD_GROUP_BUTTON,
        caption = "[img=utility/add] Add Group",
        style = "green_button",
        tooltip = {"gui.logistics-chooser-combinator-add-group"}
    }
    add_button.style.top_margin = 8
    add_button.style.horizontally_stretchable = true

    -- Connected entities count
    local connected_label = frame.add{
        type = "label",
        name = GUI_NAMES.CONNECTED_ENTITIES_LABEL,
        caption = "Connected entities: 0"
    }
    connected_label.style.top_margin = 12
    connected_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}

    return frame
end

--- Create the main logistics chooser GUI
--- @param player LuaPlayer
--- @param entity LuaEntity The logistics chooser combinator entity
function logistics_chooser_gui.create_gui(player, entity)
    -- Close any existing GUI
    logistics_chooser_gui.close_gui(player)

    -- Create main frame using FLib
    local refs = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = GUI_NAMES.MAIN_FRAME,
        direction = "vertical",
        style_mods = {
            minimal_width = 700,  -- Make window wider to prevent horizontal scrolling
            maximal_width = 900
        },
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
                        caption = {"entity-name.logistics-chooser-combinator"},
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
                        handler = gui_handlers.chooser_close_button
                    }
                }
            },
            -- Content frame
            {
                type = "frame",
                style = "inside_shallow_frame",
                direction = "vertical",
                children = {
                    -- Power status and mode switch
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
                                caption = gui_entity.get_power_status(entity).text,
                                style_mods = {
                                    right_margin = 16
                                }
                            },
                            {
                                type = "label",
                                caption = "Mode: ",
                                style_mods = {
                                    left_margin = 8
                                }
                            },
                            {
                                type = "switch",
                                name = GUI_NAMES.MODE_SWITCH,
                                left_label_caption = "Each",
                                right_label_caption = "First Only",
                                switch_state = "left",  -- Default to "Each", will be updated below
                                tooltip = {"gui.logistics-chooser-mode-tooltip"}
                            }
                        }
                    }
                }
            }
        }
    })

    -- Add UI sections after main frame creation
    local content_frame = refs[GUI_NAMES.MAIN_FRAME].children[2]  -- The inside_shallow_frame

    -- Add groups panel
    create_groups_panel(content_frame, entity)

    -- Add signal grid
    create_signal_grid(content_frame, entity)

    -- Initialize mode switch state from storage
    local chooser_data = globals.get_logistics_chooser_data(entity)
    if chooser_data then
        local mode_switch = refs[GUI_NAMES.MAIN_FRAME][GUI_NAMES.MODE_SWITCH]
        if mode_switch and mode_switch.valid then
            -- Default mode is "each"
            local mode = chooser_data.mode or "each"
            mode_switch.switch_state = (mode == "first_only") and "right" or "left"
        end
    end

    -- Center the window
    refs[GUI_NAMES.MAIN_FRAME].auto_center = true

    -- Make the GUI respond to ESC key
    player.opened = refs[GUI_NAMES.MAIN_FRAME]

    -- Store entity reference in player's GUI state
    globals.set_player_gui_entity(player.index, entity, "logistics_chooser")
end

--- Update the GUI with current chooser state
--- @param player LuaPlayer
function logistics_chooser_gui.update_gui(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return end

    local gui_state = globals.get_player_gui_state(player.index)
    if not gui_state or gui_state.gui_type ~= "logistics_chooser" then return end

    local chooser_data = globals.get_logistics_chooser_data(gui_state.open_entity)
    if not chooser_data or not chooser_data.entity or not chooser_data.entity.valid then
        logistics_chooser_gui.close_gui(player)
        return
    end

    local entity = chooser_data.entity

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
        signal_grid_frame.clear()
        local content_frame = frame.children[2]
        create_signal_grid(content_frame, entity, signal_grid_frame)
    end

    -- Evaluate conditions and update status indicators
    evaluate_and_update_statuses(player, chooser_data, entity)

    -- TODO: Update connected entities count
end

--- Close the logistics chooser GUI
--- @param player LuaPlayer
function logistics_chooser_gui.close_gui(player)
    local gui_state = globals.get_player_gui_state(player.index)
    local entity = nil

    if gui_state and gui_state.open_entity then
        local chooser_data = globals.get_logistics_chooser_data(gui_state.open_entity)
        if chooser_data and chooser_data.entity and chooser_data.entity.valid then
            entity = chooser_data.entity
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
            -- TODO: Trigger update logic when implemented
            -- logistics_chooser.update_connected_entities(unit_number)
            -- logistics_chooser.process_selection(unit_number)
        end
    end
end

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function logistics_chooser_gui.on_gui_opened(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Handle both real entities and ghosts
    local is_chooser = (entity.name == "logistics-chooser-combinator") or
                       (entity.ghost_name == "logistics-chooser-combinator")

    if is_chooser then
        local player = game.players[event.player_index]
        if not player then return end

        local is_ghost = entity.type == "entity-ghost"

        -- For real entities (not ghosts), ensure entity is registered
        if not is_ghost then
            if not globals.get_logistics_chooser_data(entity) then
                globals.register_logistics_chooser(entity)
            end
        end

        -- Close the default combinator GUI that Factorio opened
        if player.opened == entity then
            player.opened = nil
        end

        -- Open our custom GUI
        logistics_chooser_gui.create_gui(player, entity)
    end
end

--- Handle GUI closed event
--- @param event EventData.on_gui_closed
function logistics_chooser_gui.on_gui_closed(event)
    if event.element and event.element.name == GUI_NAMES.MAIN_FRAME then
        logistics_chooser_gui.close_gui(game.players[event.player_index])
    end
end

--- Handle GUI click events
--- @param event EventData.on_gui_click
function logistics_chooser_gui.on_gui_click(event)
    -- First try FLib handlers
    flib_gui.dispatch(event)

    local element = event.element
    if not element or not element.valid then return end

    -- Handle add group button
    if element.name == GUI_NAMES.ADD_GROUP_BUTTON then
        gui_handlers.chooser_add_group_button(event)
        return
    end

    -- Handle delete group button
    if element.name:match("^" .. GUI_NAMES.DELETE_GROUP_PREFIX) then
        gui_handlers.chooser_delete_group(event)
        return
    end

    -- Handle right type toggle (from condition row)
    if element.name:match("^cond_%d+_right_type_toggle$") then
        local player = game.get_player(event.player_index)
        if not player then return end

        local group_index = tonumber(element.name:match("^cond_(%d+)_right_type_toggle$"))
        if not group_index then return end

        local chooser_data, entity = get_chooser_data_from_player(player)
        if not chooser_data or not chooser_data.groups[group_index] then return end

        -- Toggle type
        local condition = chooser_data.groups[group_index].condition
        condition.right_type = (condition.right_type == "constant") and "signal" or "constant"
        globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])

        -- Update GUI visibility
        local is_signal_mode = (condition.right_type == "signal")

        -- Find the parent condition row
        local condition_row = element.parent
        if condition_row and condition_row.valid then
            -- Update toggle button sprite and tooltip
            element.sprite = is_signal_mode and "utility/custom_tag_icon" or "utility/slot"
            element.tooltip = is_signal_mode and {"gui.switch-to-constant"} or {"gui.switch-to-signal"}

            -- Update visibility of right value/signal elements
            local right_value = condition_row["cond_" .. group_index .. "_right_value"]
            local right_signal = condition_row["cond_" .. group_index .. "_right_signal"]
            local right_wire_filter = condition_row["cond_" .. group_index .. "_right_wire_"]

            if right_value and right_value.valid then
                right_value.visible = not is_signal_mode
            end
            if right_signal and right_signal.valid then
                right_signal.visible = is_signal_mode
            end
            if right_wire_filter and right_wire_filter.valid then
                right_wire_filter.visible = is_signal_mode
            end
        end

        -- Re-evaluate conditions
        evaluate_and_update_statuses(player, chooser_data, entity)

        return
    end
end

--- Handle GUI element changed events
--- @param event EventData.on_gui_elem_changed
function logistics_chooser_gui.on_gui_elem_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local chooser_data, entity = get_chooser_data_from_player(player)
    if not chooser_data then return end

    -- Handle left signal changed (from condition row)
    local left_signal_index = element.name:match("^cond_(%d+)_left_signal$")
    if left_signal_index then
        local group_index = tonumber(left_signal_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            local condition = chooser_data.groups[group_index].condition
            -- Validate signal (all types are valid on left side now)
            local error_key = gui_utils.validate_condition_signal(element.elem_value)
            if error_key then
                -- Revert to previous value and notify player
                element.elem_value = condition.left_signal
                player.create_local_flying_text{
                    text = {error_key},
                    position = player.position,
                    create_at_cursor = true
                }
                return
            end

            -- If left side changed FROM EACH to something else, and right side is EACH,
            -- we need to clear the right signal (EACH on right is only valid with EACH on left)
            local old_left_type = signal_utils.get_signal_eval_type(condition.left_signal)
            local new_left_type = signal_utils.get_signal_eval_type(element.elem_value)
            local right_type = signal_utils.get_signal_eval_type(condition.right_signal)

            if old_left_type == "each" and new_left_type ~= "each" and right_type == "each" then
                -- Clear the right signal since EACH is no longer valid there
                condition.right_signal = nil
                -- Update the GUI element if it exists
                local gui_root = player.gui.screen[GUI_NAMES.MAIN_FRAME]
                if gui_root then
                    local right_signal_elem = gui_utils.find_child_recursive(gui_root, "cond_" .. group_index .. "_right_signal")
                    if right_signal_elem and right_signal_elem.valid then
                        right_signal_elem.elem_value = nil
                    end
                end
            end

            condition.left_signal = element.elem_value
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
            -- Re-evaluate conditions
            evaluate_and_update_statuses(player, chooser_data, entity)
        end
        return
    end

    -- Handle right signal changed (from condition row)
    local right_signal_index = element.name:match("^cond_(%d+)_right_signal$")
    if right_signal_index then
        local group_index = tonumber(right_signal_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            local condition = chooser_data.groups[group_index].condition
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
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
            -- Re-evaluate conditions
            evaluate_and_update_statuses(player, chooser_data, entity)
        end
        return
    end

    -- Handle group picker changed
    local group_picker_index = element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX .. "(%d+)$")
    if group_picker_index then
        local group_index = tonumber(group_picker_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            local selected_item = element.items and element.items[element.selected_index]
            chooser_data.groups[group_index].group = (selected_item == "<none>") and nil or selected_item
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
        end
        return
    end
end

--- Handle GUI text changed events
--- @param event EventData.on_gui_text_changed
function logistics_chooser_gui.on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local chooser_data, entity = get_chooser_data_from_player(player)
    if not chooser_data then return end

    -- Handle right value changed (from condition row)
    local right_value_index = element.name:match("^cond_(%d+)_right_value$")
    if right_value_index then
        local group_index = tonumber(right_value_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            chooser_data.groups[group_index].condition.right_value = tonumber(element.text) or 0
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
            -- Re-evaluate conditions
            evaluate_and_update_statuses(player, chooser_data, entity)
        end
        return
    end

    -- Handle multiplier changed
    local mult_index = element.name:match("^" .. GUI_NAMES.MULTIPLIER_PREFIX .. "(%d+)$")
    if mult_index then
        local group_index = tonumber(mult_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            local multiplier = tonumber(element.text) or 1.0
            -- Ensure multiplier is non-negative
            if multiplier < 0 then multiplier = 0 end
            chooser_data.groups[group_index].multiplier = multiplier
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
        end
        return
    end
end

--- Handle GUI selection state changed events
--- @param event EventData.on_gui_selection_state_changed
function logistics_chooser_gui.on_gui_selection_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local chooser_data, entity = get_chooser_data_from_player(player)
    if not chooser_data then return end

    -- Handle operator dropdown changed (from condition row)
    local operator_index = element.name:match("^cond_(%d+)_operator$")
    if operator_index then
        local group_index = tonumber(operator_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            chooser_data.groups[group_index].condition.operator = gui_utils.get_operator_from_index(element.selected_index)
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
            -- Re-evaluate conditions
            evaluate_and_update_statuses(player, chooser_data, entity)
        end
        return
    end

    -- Handle group picker changed (top row dropdown)
    local group_picker_index = element.name:match("^" .. GUI_NAMES.GROUP_PICKER_PREFIX .. "(%d+)$")
    if group_picker_index then
        local group_index = tonumber(group_picker_index)
        if chooser_data.groups and chooser_data.groups[group_index] then
            local selected_item = element.items and element.items[element.selected_index]
            chooser_data.groups[group_index].group = (selected_item == "<none>") and nil or selected_item
            globals.update_chooser_group_universal(entity, group_index, chooser_data.groups[group_index])
        end
        return
    end
end

--- Handle GUI switch state changed events (for mode switch)
--- @param event EventData.on_gui_switch_state_changed
function logistics_chooser_gui.on_gui_switch_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Handle mode switch
    if element.name == GUI_NAMES.MODE_SWITCH then
        local player = game.get_player(event.player_index)
        if not player then return end

        local chooser_data, entity = get_chooser_data_from_player(player)
        if not chooser_data then return end

        -- Left = "Each" (false/left), Right = "First Only" (true/right)
        -- switch_state: "left" or "right"
        local mode = (element.switch_state == "right") and "first_only" or "each"

        -- Store mode in chooser data (this directly updates storage since chooser_data is a reference)
        chooser_data.mode = mode

        return
    end
end

--- Handle GUI checkbox state changed events
--- @param event EventData.on_gui_checked_state_changed
function logistics_chooser_gui.on_gui_checked_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local chooser_data, entity = get_chooser_data_from_player(player)
    if not chooser_data then return end

    -- Handle left wire filter checkboxes
    local left_wire_index = element.name:match("^cond_(%d+)_left_wire_(red)$") or element.name:match("^cond_(%d+)_left_wire_(green)$")
    if left_wire_index then
        local condition_index = tonumber(left_wire_index)
        local condition = chooser_data.groups[condition_index].condition
        if condition then
            local condition_row = (element.parent and element.parent.parent and element.parent.parent.parent)  or (element.parent and element.parent.parent)
            if condition_row then
                -- Find checkboxes by recursively searching nested GUI structure
                local red_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_left_wire_red")
                local green_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_left_wire_green")

                if red_checkbox and green_checkbox then
                    local filter = gui_utils.get_wire_filter_from_checkboxes(red_checkbox.state, green_checkbox.state)
                    chooser_data.groups[condition_index].condition.left_wire_filter = filter
                    globals.update_chooser_group_universal(entity, condition_index, chooser_data.groups[condition_index])
                    -- Re-evaluate conditions
                    evaluate_and_update_statuses(player, chooser_data, entity)
                end
            end
        end
        return
    end

    -- Handle right wire filter checkboxes
    local right_wire_index = element.name:match("^cond_(%d+)_right_wire_(red)$") or element.name:match("^cond_(%d+)_right_wire_(green)$")
    if right_wire_index then
        local condition_index = tonumber(right_wire_index)
        local condition = chooser_data.groups[condition_index].condition
        if condition then
            local condition_row = (element.parent and element.parent.parent and element.parent.parent.parent)  or (element.parent and element.parent.parent)
            if condition_row then
                local red_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_right_wire_red")
                local green_checkbox = find_child_recursive(condition_row, "cond_" .. condition_index .. "_right_wire_green")

                if red_checkbox and green_checkbox then
                    local filter = gui_utils.get_wire_filter_from_checkboxes(red_checkbox.state, green_checkbox.state)
                    chooser_data.groups[condition_index].condition.right_wire_filter = filter
                    globals.update_chooser_group_universal(entity, condition_index, chooser_data.groups[condition_index])
                    -- Re-evaluate conditions
                    evaluate_and_update_statuses(player, chooser_data, entity)
                end
            end
        end
        return
    end
end

return logistics_chooser_gui

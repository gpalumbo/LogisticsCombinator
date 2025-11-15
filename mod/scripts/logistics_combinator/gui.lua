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
    POWER_LABEL = "logistics_combinator_power",
    SIGNAL_GRID_FRAME = "logistics_combinator_signal_grid_frame",
    SIGNAL_GRID_TABLE = "logistics_combinator_signal_grid_table",
    ADD_RULE_BUTTON = "logistics_combinator_add_rule",
    RULE_LIST = "logistics_combinator_rule_list",
    GROUP_SELECTOR = "logistics_combinator_group_selector",
    SIGNAL_SELECTOR = "logistics_combinator_signal_selector",
    OPERATOR_DROPDOWN = "logistics_combinator_operator",
    VALUE_TEXTFIELD = "logistics_combinator_value",
    ACTION_RADIO_INJECT = "logistics_combinator_action_inject",
    ACTION_RADIO_REMOVE = "logistics_combinator_action_remove",
    DELETE_RULE_BUTTON = "logistics_combinator_delete_rule",
    SAVE_RULE_BUTTON = "logistics_combinator_save_rule",
    CONNECTED_ENTITIES_LABEL = "logistics_combinator_connected_count"
}

-- Event handlers for GUI
local gui_handlers = {
    close_button = function(e)
        local player = game.get_player(e.player_index)
        if player then
            logistics_combinator_gui.close_gui(player)
        end
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
                sprite = "utility/health_bar_green_pip",
                text = "Working"
            }
        elseif energy_ratio > 0 then
            -- Yellow: Low Power (1-50% energy)
            return {
                sprite = "utility/health_bar_yellow_pip",
                text = "Low Power"
            }
        else
            -- Red: No Power (0% energy)
            return {
                sprite = "utility/health_bar_red_pip",
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

        -- Create a flow to hold the color indicator and button
        local signal_flow = signal_table.add{
            type = "flow",
            direction = "vertical",
            style_mods = {
                vertical_spacing = 0,
                padding = 0
            }
        }

        -- Determine color indicator sprite based on wire color
        local color_sprite
        if sig_data.wire_color == "red" then
            color_sprite = "mission-control-wire-indicator-red"
        elseif sig_data.wire_color == "green" then
            color_sprite = "mission-control-wire-indicator-green"
        elseif sig_data.wire_color == "both" then
            color_sprite = "mission-control-wire-indicator-both"
        end



        -- Create sprite button for signal (keep it clickable)
        local item_slot = signal_flow.add{
            type = "sprite-button",
            sprite = sprite_path,
            number = sig_data.count,
            tooltip = {"", "[font=default-semibold]", sig_data.signal_id.name, "[/font]\n",
                      "Count: ", sig_data.count, "\n",
                      "Wire: ", sig_data.wire_color},
            style = "slot_button",
            mouse_button_filter = {"left"}
        }

        -- Add colored indicator overlay sprite behind button
        if color_sprite then
            item_slot.add{
                type = "sprite",
                sprite = color_sprite,
                style_mods = {
                    stretch_image_to_widget_size = true
                }
            }
        end


        ::continue::
    end

    -- If no signals, show message
    if #signals == 0 then
        grid_frame.add{
            type = "label",
            caption = {"", "[font=default-italic]No input signals[/font]"},
            style_mods = {
                font_color = {r = 0.6, g = 0.6, b = 0.6}
            }
        }
    end

    
end


--- Create signal grid display
--- @param parent LuaGuiElement Parent element to add signal grid to
--- @param entity LuaEntity The combinator entity
--- @return table References to created elements
local function create_signal_grid(parent, entity)


    -- Create frame for signal grid
    local grid_frame = parent.add{
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
                        ignored_by_interaction = false
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
                            }
                        }
                    }
                }
            }
        }
    })

    -- Add signal grid after main frame creation
    local content_frame = refs[GUI_NAMES.MAIN_FRAME].children[2]  -- The inside_shallow_frame
   -- Add label

    create_signal_grid(content_frame, entity)

    -- Center the window
    refs[GUI_NAMES.MAIN_FRAME].auto_center = true

    -- Store entity reference in player's GUI state
    globals.set_player_gui_entity(player.index, entity, "logistics_combinator")
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
        signal_grid_frame.destroy()
        local content_frame = frame.children[2]  -- The inside_shallow_frame
        create_signal_grid(content_frame, entity)
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
    flib_gui.dispatch(event)
end

--- Handle GUI element changed events
--- @param event EventData.on_gui_elem_changed
function logistics_combinator_gui.on_gui_elem_changed(event)
    -- TODO: Implement element changed handler
    -- For group selector, signal selector, etc.
end

--- Handle GUI text changed events
--- @param event EventData.on_gui_text_changed
function logistics_combinator_gui.on_gui_text_changed(event)
    -- TODO: Implement text changed handler
    -- For value textfield
end

--- Handle GUI selection state changed events
--- @param event EventData.on_gui_selection_state_changed
function logistics_combinator_gui.on_gui_selection_state_changed(event)
    -- TODO: Implement selection changed handler
    -- For operator dropdown
end

return logistics_combinator_gui
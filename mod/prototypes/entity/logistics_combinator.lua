-- Mission Control Mod - Logistics Combinator Entity Prototype
-- This file defines the logistics combinator entity

-- Create the logistics combinator entity based on decider combinator
local logistics_combinator = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])

-- Basic properties
logistics_combinator.name = "logistics-combinator"
logistics_combinator.minable = {
    mining_time = 0.2,
    result = "logistics-combinator"
}

-- Size and collision
-- Size: 2x1 (standard combinator size)
logistics_combinator.collision_box = {{-0.35, -0.85}, {0.35, 0.85}}
logistics_combinator.selection_box = {{-0.5, -1}, {0.5, 1}}

-- Health and resistance (scales with quality)
logistics_combinator.max_health = 150
logistics_combinator.corpse = "decider-combinator-remnants"
logistics_combinator.dying_explosion = "decider-combinator-explosion"

-- Power consumption
logistics_combinator.energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
}
logistics_combinator.active_energy_usage = "1kW"

-- Circuit connections (3 terminals: red_in, green_in, output)
-- Note: input_connection_points and output_connection_points are inherited from decider-combinator deepcopy
-- Split bounding boxes so they don't overlap - input on bottom half, output on top half
logistics_combinator.input_connection_bounding_box =  {{-0.5, 0}, {0.5, 1}}   -- Bottom half
logistics_combinator.output_connection_bounding_box = {{-0.5, -1}, {0.5, 0}} -- Top half

-- Graphics and sprites
-- TODO: Replace with custom graphics
-- For now, tint the decider combinator sprites
if logistics_combinator.sprites then
    -- Apply a slight blue tint to differentiate
    logistics_combinator.sprites.tint = {r = 0.7, g = 0.7, b = 1, a = 0.5}
end

-- Fast replaceable group
logistics_combinator.fast_replaceable_group = "combinator"

-- Flags
logistics_combinator.flags = {"placeable-neutral", "player-creation"}

-- Custom properties for GUI
logistics_combinator.open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 }
logistics_combinator.close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 }

-- TODO: LED indicators for active rules
-- This will require custom sprite definitions

-- Register the entity
data:extend({logistics_combinator})
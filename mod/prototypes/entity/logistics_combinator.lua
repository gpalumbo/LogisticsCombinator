-- Logistics Combinator - Entity Prototype
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
-- Custom logistics combinator sprite with embedded display
-- Following base game combinator format (sprite sheet: 624x132, 4 frames of 156x132 each)
logistics_combinator.sprites = make_4way_animation_from_spritesheet({
    layers = {
        {
            scale = 0.5,
            filename = "__logistics-combinator__/graphics/entities/logistics-combinator.png",
            width = 156,
            height = 132,
            shift = util.by_pixel(0.5, 7.5)
        },
        {
            scale = 0.5,
            filename = "__base__/graphics/entity/combinator/decider-combinator-shadow.png",
            width = 156,
            height = 158,
            shift = util.by_pixel(12, 24),
            draw_as_shadow = true
        }
    }
})

-- Activity LED sprites (shows when combinator is active)
logistics_combinator.activity_led_sprites = {
    north = util.draw_as_glow {
        scale = 0.5,
        filename = "__base__/graphics/entity/combinator/activity-leds/decider-combinator-LED-N.png",
        width = 16,
        height = 14,
        shift = util.by_pixel(8.5, -13)
    },
    east = util.draw_as_glow {
        scale = 0.5,
        filename = "__base__/graphics/entity/combinator/activity-leds/decider-combinator-LED-E.png",
        width = 16,
        height = 16,
        shift = util.by_pixel(16, -4)
    },
    south = util.draw_as_glow {
        scale = 0.5,
        filename = "__base__/graphics/entity/combinator/activity-leds/decider-combinator-LED-S.png",
        width = 16,
        height = 14,
        shift = util.by_pixel(-8, 4.5)
    },
    west = util.draw_as_glow {
        scale = 0.5,
        filename = "__base__/graphics/entity/combinator/activity-leds/decider-combinator-LED-W.png",
        width = 16,
        height = 16,
        shift = util.by_pixel(-15, -18.5)
    }
}

-- Clear symbol sprites since display is embedded in main sprite
logistics_combinator.greater_symbol_sprites = nil
logistics_combinator.less_symbol_sprites = nil
logistics_combinator.equal_symbol_sprites = nil
logistics_combinator.not_equal_symbol_sprites = nil

-- Fast replaceable group
logistics_combinator.fast_replaceable_group = "combinator"

-- Flags
logistics_combinator.flags = {"placeable-neutral", "player-creation"}

-- Custom properties for GUI
logistics_combinator.open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 }
logistics_combinator.close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 }

-- Note: Display grid and indicators are embedded in the sprite

-- Register the entity
data:extend({logistics_combinator})
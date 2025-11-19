-- Mission Control Mod - Logistics Combinator Item
-- This file defines the logistics combinator item

data:extend({
    {
        type = "item",
        name = "logistics-combinator",
        icon = "__mission-control__/graphics/entities/logistocs_combinator_icon.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "circuit-network",
        order = "d[other]-d[logistics-combinator]",
        place_result = "logistics-combinator",
        stack_size = 50,
        rocket_capacity = 50
    }
})
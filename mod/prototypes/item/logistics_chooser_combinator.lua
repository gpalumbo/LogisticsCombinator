-- Logistics Chooser Combinator - Item Prototype
-- This file defines the logistics chooser combinator item

data:extend({
    {
        type = "item",
        name = "logistics-chooser-combinator",
        icon = "__logistics-combinator__/graphics/entities/logistics_chooser_combinator_icon.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "circuit-network",
        order = "d[other]-e[logistics-chooser-combinator]",
        place_result = "logistics-chooser-combinator",
        stack_size = 50,
        rocket_capacity = 50
    }
})

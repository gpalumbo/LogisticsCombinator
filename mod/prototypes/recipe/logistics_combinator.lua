-- Mission Control Mod - Logistics Combinator Recipe
-- This file defines the logistics combinator recipe

data:extend({
    {
        type = "recipe",
        name = "logistics-combinator",
        enabled = false, -- Unlocked by logistics-circuit-control technology
        energy_required = 5,
        ingredients = {
            {type = "item", name = "electronic-circuit", amount = 5},
            {type = "item", name = "decider-combinator", amount = 1},
            {type = "item", name = "constant-combinator", amount = 1}
        },
        results = {
            {type = "item", name = "logistics-combinator", amount = 1}
        }
    }
})
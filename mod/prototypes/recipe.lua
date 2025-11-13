-- recipe.lua
-- Recipe definitions for Mission Control mod

data:extend({
  -- ============================================================================
  -- LOGISTICS COMBINATOR RECIPE
  -- ============================================================================
  {
    type = "recipe",
    name = "logistics-combinator",
    enabled = false,  -- Unlocked by technology
    ingredients = {
      {type = "item", name = "electronic-circuit", amount = 5},
      {type = "item", name = "decider-combinator", amount = 1},
      {type = "item", name = "constant-combinator", amount = 1}
    },
    results = {{type = "item", name = "logistics-combinator", amount = 1}},
    energy_required = 5  -- 5 seconds crafting time
  }
})

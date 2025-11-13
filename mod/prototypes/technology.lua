-- technology.lua
-- Technology definitions for Mission Control mod

data:extend({
  -- ============================================================================
  -- LOGISTICS CIRCUIT CONTROL TECHNOLOGY
  -- ============================================================================
  {
    type = "technology",
    name = "logistics-circuit-control",
    icon = "__base__/graphics/technology/logistic-system.png",  -- Placeholder icon
    icon_size = 256,
    icon_mipmaps = 4,

    -- Prerequisites: Logistic system
    prerequisites = {"logistic-system"},

    -- Research cost: 500x automation, logistic, chemical, utility science packs
    unit = {
      count = 500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1}
      },
      time = 30
    },

    -- Unlocks: Logistics Combinator recipe
    effects = {
      {
        type = "unlock-recipe",
        recipe = "logistics-combinator"
      }
    },

    order = "c-k-d"
  }
})

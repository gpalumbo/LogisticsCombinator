-- item.lua
-- Item definitions for Mission Control mod

data:extend({
  -- ============================================================================
  -- LOGISTICS COMBINATOR ITEM
  -- ============================================================================
  {
    type = "item",
    name = "logistics-combinator",
    icon = "__base__/graphics/icons/decider-combinator.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "circuit-network",
    order = "d[other]-d[logistics-combinator]",
    place_result = "logistics-combinator",
    stack_size = 50,
    -- Rocket capacity (how many can fit in a rocket)
    rocket_launch_products = {{type = "item", name = "logistics-combinator", amount = 1}}
  }
})

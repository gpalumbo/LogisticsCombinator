-- Logistics Combinator - Technology Definitions
-- This file contains all technology definitions for the mod

-- Mission Control Technology (not included in this release)
-- Unlocks: Mission Control building, Receiver Combinator
data:extend({
    -- {
    --     type = "technology",
    --     name = "mission-control",
    --     -- Using radar icon as placeholder until custom graphics are created
    --     icon = "__base__/graphics/technology/radar.png",
    --     icon_size = 256,
    --     icon_mipmaps = 4,
    --     prerequisites = {
    --         "space-platform",
    --         "radar",
    --         "processing-unit"
    --     },
    --     unit = {
    --         count = 1000,
    --         time = 60,
    --         ingredients = {
    --             {"automation-science-pack", 1},
    --             {"logistic-science-pack", 1},
    --             {"military-science-pack", 1},
    --             {"chemical-science-pack", 1},
    --             {"production-science-pack", 1},
    --             {"utility-science-pack", 1},
    --             {"space-science-pack", 1}
    --         }
    --     },
    --     effects = {
    --         {
    --             type = "unlock-recipe",
    --             recipe = "mission-control-building"
    --         },
    --         {
    --             type = "unlock-recipe",
    --             recipe = "receiver-combinator"
    --         }
    --     },
    --     order = "a-h-f"
    -- },

    -- Logistics Circuit Control Technology
    -- Unlocks: Logistics Combinator
    {
        type = "technology",
        name = "logistics-circuit-control",
        -- Using logistic system icon as placeholder until custom graphics are created
        icon = "__base__/graphics/technology/logistic-system.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {
            "logistic-system"
        },
        unit = {
            count = 500,
            time = 30,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"utility-science-pack", 1}
            }
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "logistics-combinator"
            },
            {
                type = "unlock-recipe",
                recipe = "logistics-chooser-combinator"
            }
        },
        order = "a-h-g"
    }
})
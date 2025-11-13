-- data.lua
-- Mission Control Mod - Data Phase Loading
--
-- This file is loaded during Factorio's data phase and is responsible for
-- defining all prototypes (entities, items, recipes, technologies).
--
-- LOAD ORDER:
-- 1. Technology (may reference items/recipes)
-- 2. Entity prototypes
-- 3. Item prototypes
-- 4. Recipe prototypes

-- ==============================================================================
-- LOAD PROTOTYPES IN CORRECT ORDER
-- ==============================================================================

-- Technology definitions
require("prototypes.technology")

-- Entity definitions (one file per entity type)
require("prototypes.entity.logistics_combinator")

-- Item definitions (all items in one file)
require("prototypes.item")

-- Recipe definitions (all recipes in one file)
require("prototypes.recipe")

-- ==============================================================================
-- DATA PHASE COMPLETE
-- ==============================================================================

log("Mission Control mod: Data phase loaded successfully")

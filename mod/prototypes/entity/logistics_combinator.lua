-- logistics_combinator.lua
-- Logistics Combinator entity prototype for Mission Control mod
--
-- Based on decider-combinator but with custom behavior for controlling
-- logistics groups via circuit conditions

-- Get base decider combinator prototype to copy from
local decider_combinator = data.raw["decider-combinator"]["decider-combinator"]

if not decider_combinator then
  error("Base decider-combinator prototype not found!")
end

-- Create logistics combinator by copying decider combinator
local logistics_combinator = table.deepcopy(decider_combinator)

-- ==============================================================================
-- BASIC PROPERTIES
-- ==============================================================================

logistics_combinator.name = "logistics-combinator"
logistics_combinator.type = "decider-combinator"
logistics_combinator.minable = {
  mining_time = 0.1,
  result = "logistics-combinator"
}

-- Icon (will use placeholder, should be replaced with custom graphics later)
logistics_combinator.icon = "__base__/graphics/icons/decider-combinator.png"
logistics_combinator.icon_size = 64
logistics_combinator.icon_mipmaps = 4

-- ==============================================================================
-- SPECIFICATIONS FROM SPEC.MD
-- ==============================================================================

-- Health: 150 (same as decider combinator, scales with quality)
logistics_combinator.max_health = 150

-- Size: 2x1 (standard combinator size) - inherited from decider-combinator
-- collision_box and selection_box already correct from base

-- Fast replace group (allows upgrading between combinators)
logistics_combinator.fast_replaceable_group = "combinator"
logistics_combinator.next_upgrade = nil

-- ==============================================================================
-- POWER CONSUMPTION
-- ==============================================================================

-- Power: 1kW (lower than other combinators)
logistics_combinator.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  drain = "1kW"
}
logistics_combinator.active_energy_usage = "1kW"

-- ==============================================================================
-- CIRCUIT CONNECTIONS
-- ==============================================================================

-- Circuit connections: 3 terminals (red in, green in, output)
-- The decider combinator base already has this configuration
-- We keep the standard circuit connection points

-- Circuit wire max distance (standard)
logistics_combinator.circuit_wire_max_distance = decider_combinator.circuit_wire_max_distance or 9

-- ==============================================================================
-- GRAPHICS
-- ==============================================================================

-- Use base decider combinator graphics with a tint to differentiate
-- In production, this should be replaced with custom graphics
-- For now, we'll use the base graphics with a slight green tint to suggest logistics

-- Apply tint to sprites if available
if logistics_combinator.sprites then
  -- Apply a subtle green tint to differentiate from standard combinators
  local function apply_tint_to_sprite(sprite)
    if sprite then
      sprite.tint = {r = 0.8, g = 1.0, b = 0.8, a = 1.0}
    end
  end

  if logistics_combinator.sprites.north then
    apply_tint_to_sprite(logistics_combinator.sprites.north)
  end
  if logistics_combinator.sprites.east then
    apply_tint_to_sprite(logistics_combinator.sprites.east)
  end
  if logistics_combinator.sprites.south then
    apply_tint_to_sprite(logistics_combinator.sprites.south)
  end
  if logistics_combinator.sprites.west then
    apply_tint_to_sprite(logistics_combinator.sprites.west)
  end
end

-- ==============================================================================
-- FLAGS
-- ==============================================================================

-- Standard combinator flags
logistics_combinator.flags = {
  "placeable-neutral",
  "placeable-player",
  "player-creation"
}

-- Placeable on any surface (planets and platforms)
logistics_combinator.surface_conditions = nil  -- No restrictions

-- ==============================================================================
-- QUALITY SCALING
-- ==============================================================================

-- Health scales with quality automatically via Factorio's quality system
-- Quality bonuses apply to:
-- - max_health (automatic)
-- - energy usage (would need quality-based variants, skip for now)

-- ==============================================================================
-- ADDITIONAL PROPERTIES
-- ==============================================================================

-- Corpse when destroyed (use base decider combinator corpse)
logistics_combinator.corpse = decider_combinator.corpse
logistics_combinator.dying_explosion = decider_combinator.dying_explosion

-- Damaged trigger effects
logistics_combinator.damaged_trigger_effect = decider_combinator.damaged_trigger_effect

-- Circuit light (LED indicators)
-- The decider combinator already has activity lights
-- We'll keep those for showing when the combinator is processing

-- Working visualization (inherited from decider)
logistics_combinator.working_visualisations = decider_combinator.working_visualisations

-- ==============================================================================
-- SOUNDS
-- ==============================================================================

logistics_combinator.vehicle_impact_sound = decider_combinator.vehicle_impact_sound
logistics_combinator.open_sound = decider_combinator.open_sound
logistics_combinator.close_sound = decider_combinator.close_sound

-- ==============================================================================
-- EXPORT
-- ==============================================================================

data:extend({logistics_combinator})

-- Mission Control Mod - Custom Sprite Definitions
-- Wire color indicator sprites for GUI overlays

data:extend({
  -- Red wire indicator - semi-transparent red overlay
  {
    type = "sprite",
    name = "mission-control-wire-indicator-red",
    filename = "__core__/graphics/editor-selection.png",  -- Use core graphic as base
    priority = "extra-high-no-scale",
    width = 1,
    height = 1,
    scale = 40,  -- Scale to button size
    tint = {r = 1.0, g = 0.2, b = 0.2, a = 0.7}  -- Semi-transparent red
  },

  -- Green wire indicator - semi-transparent green overlay
  {
    type = "sprite",
    name = "mission-control-wire-indicator-green",
    filename = "__core__/graphics/editor-selection.png",
    priority = "extra-high-no-scale",
    width = 1,
    height = 1,
    scale = 40,
    tint = {r = 0.2, g = 1.0, b = 0.2, a = 0.7}  -- Semi-transparent green
  },

  -- Both wires indicator - semi-transparent yellow overlay
  {
    type = "sprite",
    name = "mission-control-wire-indicator-both",
    filename = "__core__/graphics/editor-selection.png",
    priority = "extra-high-no-scale",
    width = 1,
    height = 1,
    scale = 40,
    tint = {r = 1.0, g = 1.0, b = 0.3, a = 0.7}  -- Semi-transparent yellow
  }
})
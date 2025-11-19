-- Mission Control Mod - Custom Input Definitions
-- Defines custom input handlers for enhanced GUI interactions

data:extend({
  {
    type = "custom-input",
    name = "logistics-combinator-pipette-signal",
    key_sequence = "Q",
    linked_game_control = "pipette",  -- Links to the pipette control (default: 'Q' key)
    consuming = "none",  -- Allow the event to pass through if not handled
    action = "lua"
  }
})

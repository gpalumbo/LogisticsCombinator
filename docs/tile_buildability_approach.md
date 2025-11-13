# Placement Validation Strategy: TileBuildabilityRule

## Architectural Decision

**Date:** 2025-11-13
**Decision:** Use Factorio's native `TileBuildabilityRule` system for entity placement restrictions instead of runtime Lua validation.

## Rationale

### Why TileBuildabilityRule is Superior

**Performance Benefits:**
- ✅ Zero Lua runtime overhead (engine-level validation)
- ✅ No event handlers needed for placement checking
- ✅ No refund logic required
- ✅ Instant feedback (no tick delay)

**Game Integration:**
- ✅ Native visual feedback (red placement outline)
- ✅ Blueprint system automatically respects rules
- ✅ Construction robots won't place on invalid tiles
- ✅ Deconstruction planners work correctly
- ✅ Copy/paste respects tile constraints

**Code Simplicity:**
- ✅ Defined once in entity prototype
- ✅ No complex validation logic needed
- ✅ No player notification code required
- ✅ No edge case handling for robots vs players

**Maintainability:**
- ✅ Centralized in prototype definitions
- ✅ Easy to modify tile requirements
- ✅ Self-documenting (clear from prototype)

## Implementation

### Mission Control Building (Planet-Only)

```lua
-- prototypes/entity/mission_control.lua
{
  type = "radar",
  name = "mission-control-building",
  -- ... other properties ...

  tile_buildability_rules = {
    {
      area = {{-2.4, -2.4}, {2.4, 2.4}},
      colliding_tiles = {"space-platform-foundation"},
      remove_on_collision = false
    }
  }
}
```

**Behavior:** Cannot be placed on space-platform-foundation tiles, effectively restricting to planets.

### Receiver Combinator (Platform-Only)

```lua
-- prototypes/entity/receiver_combinator.lua
{
  type = "arithmetic-combinator",
  name = "receiver-combinator",
  -- ... other properties ...

  tile_buildability_rules = {
    {
      area = {{-0.9, -0.9}, {0.9, 0.9}},
      required_tiles = {"space-platform-foundation"},
      remove_on_collision = false
    }
  }
}
```

**Behavior:** Can ONLY be placed on space-platform-foundation tiles, restricting to platforms.

### Logistics Combinator (Anywhere)

```lua
-- prototypes/entity/logistics_combinator.lua
{
  type = "decider-combinator",
  name = "logistics-combinator",
  -- ... other properties ...

  -- NO tile_buildability_rules = can be placed anywhere
}
```

**Behavior:** No restrictions, can be placed on any surface.

## validation.lua Status

**Current Status:** Implemented but SUPERSEDED by tile buildability rules.

**Options:**

### Option 1: Remove validation.lua (RECOMMENDED)
- Delete `mod/lib/validation.lua`
- Remove from module responsibility matrix
- Simplify architecture
- Rely entirely on native Factorio system

### Option 2: Keep as Optional Enhancement
- Mark as optional/deprecated in documentation
- Use only for custom error messages (future enhancement)
- Not imported by any scripts unless needed
- Provides more detailed feedback than engine default

**Recommendation:** Remove validation.lua for simplicity. If custom error messages are needed later, implement them as a small addition to entity build event handlers.

## Trade-offs

### Lost Capabilities

**Custom Error Messages:**
- Can't show "Mission Control buildings can only be placed on planets"
- Default Factorio feedback is "Can't build here" (generic)
- **Mitigation:** Entity description can mention placement requirements

**Mod Compatibility:**
- If other mods add new planetary tile types, need to update colliding_tiles
- **Mitigation:** Most planetary surfaces use standard Factorio tiles

### Gained Benefits

**Simplicity:**
- Eliminates entire validation module
- No event handlers for placement
- No refund logic complexity
- ~365 lines of code removed from consideration

**Performance:**
- Zero Lua overhead for placement validation
- Engine-level checking is faster
- No global state needed for tracking

**Correctness:**
- Impossible to place incorrectly (engine prevents it)
- Blueprint system respects rules automatically
- No edge cases with robot construction

## Testing Strategy

### Manual Testing
1. Try placing Mission Control on planet → should succeed
2. Try placing Mission Control on platform → red outline, can't place
3. Try placing Receiver on platform → should succeed
4. Try placing Receiver on planet → red outline, can't place
5. Try placing Logistics Combinator anywhere → should succeed

### Blueprint Testing
1. Create blueprint with Mission Control on planet
2. Try placing blueprint on platform → ghost should fail to place
3. Create blueprint with Receiver on platform
4. Try placing blueprint on planet → ghost should fail to place

### Robot Testing
1. Give construction robots Mission Control blueprint
2. Try building on platform → robots should not place
3. Give construction robots Receiver blueprint
4. Try building on planet → robots should not place

## Future Considerations

### If Custom Messages Needed

If players request better error messages, implement minimal feedback:

```lua
-- In control.lua entity build handler
script.on_event(defines.events.on_built_entity, function(event)
  local entity = event.created_entity
  local player = game.get_player(event.player_index)

  -- Note: This will never fire because tile rules prevent placement
  -- Only useful if we want to show messages BEFORE placement attempt
  -- Would need on_pre_build or similar event
end)
```

**Better approach:** Add placement hints to entity descriptions in locale files.

### Mod Compatibility

If other mods add new surfaces or tile types:

**Planetary mod compatibility:**
- Most planet mods use standard Factorio tile types
- If new tile types added, Mission Control will already work (no colliding_tiles restriction)

**Platform mod compatibility:**
- If other mods add alternative platform systems with different tiles
- Would need to add those tiles to receiver combinator's required_tiles list
- Or use colliding_tiles approach instead

## Conclusion

**TileBuildabilityRule is the correct architectural choice.** It leverages Factorio's native systems, eliminates complexity, improves performance, and provides better game integration.

**Action Items:**
1. ✅ Document this decision (this file)
2. ⏳ Update module_responsibility_matrix.md to remove/deprecate validation.lua
3. ⏳ Update code_architecture.md to reflect tile buildability approach
4. ⏳ Update todo.md Phase 2 prototype specs to include tile rules
5. ⏳ Consider removing validation.lua from codebase
6. ⏳ Add placement requirements to entity descriptions in locale

**validation.lua Recommendation:** Remove from codebase. Not needed with tile buildability rules.

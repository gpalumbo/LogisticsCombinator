# Logistics Combinator Mod - Code Architecture

## File Structure (Actual Implementation)

```
mod/
├── info.json                          # Mod metadata
├── thumbnail.png                      # Mod portal thumbnail (144x144)
├── data.lua                           # Main data phase loader
├── control.lua                        # Main control phase entry point
│
├── lib/                               # Shared utility libraries (pure functions)
│   ├── signal_utils.lua               # Signal manipulation (add, merge, copy, compare)
│   ├── circuit_utils.lua              # Circuit network I/O operations
│   ├── platform_utils.lua             # Platform detection (for future use)
│   ├── validation.lua                 # Placement validation (currently unused)
│   ├── logistics_utils.lua            # Logistics group injection/removal
│   ├── logistics_injection.lua        # Advanced injection tracking
│   ├── gui_utils.lua                  # Common GUI creation helpers
│   └── gui/                           # Specialized GUI utilities
│       ├── gui_circuit_inputs.lua     # Circuit input GUI components
│       └── gui_entity.lua             # Entity GUI utilities
│
├── scripts/                           # Entity-specific control logic
│   ├── globals.lua                    # Global state initialization and accessors
│   ├── migrations.lua                 # Save migration support
│   ├── logistics_combinator/          # Logistics Combinator implementation
│   │   ├── logistics_combinator.lua   # Core logic (rule processing, state management)
│   │   ├── gui.lua                    # GUI creation and event handling
│   │   └── control.lua                # Entity lifecycle events
│   └── logistics_chooser_combinator/  # Chooser Combinator implementation
│       ├── logistics_chooser_combinator.lua  # Core logic (simple rules, evaluation modes)
│       ├── gui.lua                    # GUI creation with LED indicators
│       └── control.lua                # Entity lifecycle events
│
├── prototypes/                        # Data phase definitions
│   ├── custom-input.lua               # Custom input bindings
│   ├── technology/
│   │   └── technologies.lua           # All technology definitions
│   ├── entity/
│   │   ├── logistics_combinator.lua   # Logistics Combinator entity
│   │   └── logistics_chooser_combinator.lua  # Chooser Combinator entity
│   ├── item/
│   │   ├── logistics_combinator.lua   # Item definitions
│   │   └── logistics_chooser_combinator.lua
│   └── recipe/
│       ├── logistics_combinator.lua   # Recipe definitions
│       └── logistics_chooser_combinator.lua
│
├── locale/                            # Localization
│   └── en/
│       └── mission-control.cfg        # English strings (name to be updated)
│
└── graphics/                          # Visual assets
    └── entities/                      # Entity sprites (using tinted vanilla)
        ├── logistics-combinator.png
        ├── logistocs_combinator_icon.png
        ├── logistics-chooser-combinator.png
        └── logistics_chooser_combinator_icon.png
```

---

## Architecture Principles

### 1. Separation of Concerns

**lib/** - Pure utility functions
- No global state access
- Reusable across entity types
- Focus on generic operations
- No side effects (except GUI creation)

**scripts/** - Stateful entity logic
- Access global state for entity tracking
- Entity-specific business logic
- Organized by entity type in subdirectories
- Each subdirectory contains:
  - `<entity>.lua` - Core functionality
  - `gui.lua` - GUI management
  - `control.lua` - Event handling

**prototypes/** - Data phase definitions
- Entity, item, recipe, technology definitions
- One file per entity type
- No runtime logic

### 2. Entity Organization Pattern

Each entity type follows the same structure:

```
scripts/<entity_name>/
├── <entity_name>.lua  # Core logic
│   ├── Rule processing
│   ├── State management
│   ├── Connected entity tracking
│   └── Business logic
├── gui.lua            # GUI layer
│   ├── GUI creation
│   ├── Event handlers
│   └── GUI updates
└── control.lua        # Lifecycle
    ├── on_built
    ├── on_removed
    └── Event registration
```

This pattern is used for:
- logistics_combinator
- logistics_chooser_combinator

### 3. Global State Management

**scripts/globals.lua** manages all global state:

```lua
storage = {
  -- Logistics Combinator
  logistics_combinators = {
    [unit_number] = {
      rules = {},
      connected_entities = {},
      injected_groups = {}
    }
  },

  -- Chooser Combinator
  chooser_combinators = {
    [unit_number] = {
      rules = {},
      evaluation_mode = "all_matching",
      connected_entities = {},
      injected_groups = {}
    }
  },

  -- Injection tracking (shared)
  injected_groups = {
    [entity_unit_number] = {
      [group_name] = {
        combinator_id = number,
        section_index = number
      }
    }
  },

  -- GUI state
  player_gui_entity = {
    [player_index] = {
      entity = entity_reference,
      entity_type = "logistics_combinator" | "logistics_chooser_combinator"
    }
  }
}
```

### 4. Event Flow

**Lifecycle Events:**
```
Player places entity
  ↓
control.lua (dispatches to entity control.lua)
  ↓
<entity>/control.lua on_built()
  ↓
globals.register_<entity>(entity)
  ↓
<entity>/<entity>.lua initialization
  ↓
<entity>/gui.lua create_gui() (if player-placed)
```

**Periodic Updates:**
```
on_nth_tick(15)
  ↓
logistics_combinator.process_all_combinators()
  ↓
For each combinator:
  - Read circuit inputs
  - Evaluate conditions
  - Inject/remove groups (edge-triggered)
```

**Wire Events:**
```
Player connects/disconnects wire
  ↓
on_wire_added / on_wire_removed
  ↓
<entity>/<entity>.lua update_connected_entities()
  ↓
Invalidate cache, rescan on next update
```

### 5. Circuit Network Integration

**Input Signal Flow:**
```
Circuit Network (red/green)
  ↓
circuit_utils.get_input_signals()
  ↓
Merged signal table
  ↓
Condition evaluation
  ↓
Rule processing
```

**Output Network:**
```
Combinator output connector
  ↓
circuit_utils.find_logistics_entities_on_output()
  ↓
Cached list of controllable entities
  ↓
logistics_utils.inject/remove_logistics_group()
```

### 6. Logistics Group Management

**Injection Process:**
```
Rule condition becomes TRUE
  ↓
Edge detection (state changed)
  ↓
logistics_utils.inject_logistics_group(entity, group, combinator_id)
  ↓
entity.logistic_sections.add_section(group_template)
  ↓
Track injection in storage.injected_groups
```

**Removal Process:**
```
Rule condition becomes TRUE (for removal action)
  ↓
Edge detection (state changed)
  ↓
logistics_utils.remove_logistics_group(entity, group, combinator_id)
  ↓
Find section by group name
  ↓
section.remove()
  ↓
Clear from storage.injected_groups
```

**Cleanup Process:**
```
Combinator destroyed
  ↓
<entity>/control.lua on_removed()
  ↓
logistics_utils.cleanup_combinator_groups(combinator_id)
  ↓
Remove all injected groups from all entities
  ↓
Clear from global storage
```

---

## Module Responsibilities

### Core Utilities (lib/)

**signal_utils.lua**
- Signal table manipulation
- No external dependencies

**circuit_utils.lua**
- Circuit network I/O
- Depends on: signal_utils

**logistics_utils.lua**
- Logistics section manipulation
- Core injection/removal logic
- No dependencies on entity-specific code

**logistics_injection.lua**
- Advanced tracking and reconciliation
- Depends on: logistics_utils

**gui_utils.lua**
- Reusable GUI components
- Titlebar, buttons, condition selectors
- No entity-specific logic

**gui/gui_circuit_inputs.lua**
- Circuit input GUI components
- Signal display grids

**gui/gui_entity.lua**
- Entity GUI utilities
- Window management

**platform_utils.lua**
- Platform detection functions
- Currently unused but kept for future features

**validation.lua**
- Placement validation (deprecated)
- Superseded by tile buildability rules

### Entity Scripts (scripts/)

**globals.lua**
- State initialization
- Entity registration/unregistration
- State accessor functions
- No business logic

**migrations.lua**
- Save file migration support
- Version compatibility

**logistics_combinator/**
- Complex multi-condition logic
- AND/OR precedence evaluation
- Advanced circuit integration

**logistics_chooser_combinator/**
- Simple single-condition rules
- Priority-based evaluation
- "All matching" vs "First match only" modes
- LED indicator management

---

## GUI Architecture

### GUI Creation Pattern

```lua
function create_gui(player, entity)
  -- 1. Close any existing GUI
  close_gui(player)

  -- 2. Create main window using flib_gui
  local refs = flib_gui.add(player.gui.screen, {
    -- GUI definition table
  })

  -- 3. Build content
  create_titlebar(refs.frame, "Title", "close_button_name")
  create_content_section(refs.content, entity)

  -- 4. Center and open
  refs.main_frame.auto_center = true
  player.opened = refs.main_frame

  -- 5. Store state
  globals.set_player_gui_entity(player.index, entity, "entity_type")
end
```

### GUI Event Handling

```lua
-- Pattern: Dispatch based on element name
function on_gui_event(event)
  local element = event.element
  local player = game.players[event.player_index]

  -- Get entity from stored state
  local gui_state = globals.get_player_gui_entity(player.index)
  if not gui_state then return end

  -- Dispatch to specific handler
  if element.name == "add_rule_button" then
    handle_add_rule(player, gui_state.entity)
    rebuild_gui(player, gui_state.entity)
  elseif element.name:match("^delete_rule_") then
    local index = tonumber(element.name:match("%d+$"))
    handle_delete_rule(player, gui_state.entity, index)
    rebuild_gui(player, gui_state.entity)
  -- ... more handlers
  end
end
```

---

## Performance Considerations

### Update Frequency

- **Rule Evaluation:** Every 15 ticks (on_nth_tick)
- **Wire Connection Scan:** On-demand with caching
- **GUI Updates:** Only when GUI is open

### Caching Strategy

**Connected Entities Cache:**
```lua
-- Cache invalidation on wire events
on_wire_added/removed → mark cache dirty
next update cycle → rescan if dirty
store results → reuse until next wire event
```

**Rule State Cache:**
```lua
-- Edge detection requires state tracking
rule.last_state = previous_evaluation_result
current_state = evaluate_condition(...)
if current_state ~= rule.last_state then
  -- State changed, perform action
  rule.last_state = current_state
end
```

### Batch Processing

```lua
-- Process all combinators in single tick handler
on_nth_tick(15, function()
  for unit_number, data in pairs(storage.logistics_combinators) do
    process_combinator_rules(unit_number)
  end
  for unit_number, data in pairs(storage.chooser_combinators) do
    process_chooser_rules(unit_number)
  end
end)
```

---

## Testing Strategy

### Unit Testing (In Comments)

Each lib/ function includes usage examples in comments:

```lua
--- Add signals from source to target (modifies target)
-- @param target table Signal table to modify
-- @param source table Signal table to add from
-- @return table Modified target table
--
-- Example:
--   local t = {["item/iron-plate"] = 10}
--   local s = {["item/iron-plate"] = 5, ["item/copper-plate"] = 3}
--   add_signals(t, s)
--   -- t = {["item/iron-plate"] = 15, ["item/copper-plate"] = 3}
function add_signals(target, source)
  -- implementation
end
```

### Integration Testing

Test scenarios:
1. Place combinator → verify registration
2. Connect wires → verify entity cache updates
3. Set conditions → verify rule processing
4. Trigger condition → verify group injection
5. Destroy combinator → verify cleanup
6. Save/load → verify state persistence

---

## Migration Support

### Version Compatibility

**migrations.lua** handles save file updates:

```lua
-- Example migration
script.on_configuration_changed(function(data)
  local mod_changes = data.mod_changes["logistics-combinator"]
  if not mod_changes then return end

  local old_version = mod_changes.old_version
  if old_version and old_version < "0.2.0" then
    -- Migrate from 0.1.x to 0.2.0
    migrate_to_0_2_0()
  end
end)
```

### State Validation

On load, validate and repair global state:

```lua
function validate_global_state()
  -- Ensure all required tables exist
  storage.logistics_combinators = storage.logistics_combinators or {}
  storage.chooser_combinators = storage.chooser_combinators or {}
  storage.injected_groups = storage.injected_groups or {}

  -- Remove stale references
  for unit_number, data in pairs(storage.logistics_combinators) do
    if not data.entity or not data.entity.valid then
      storage.logistics_combinators[unit_number] = nil
    end
  end
end
```

---

## Future Extensions

The architecture supports future additions:

1. **New Combinator Types:** Follow the established pattern (scripts/<name>/, gui/, control.lua)
2. **Cross-Surface Communication:** Add network_manager.lua for signal transmission between surfaces
3. **Additional GUI Features:** Extend gui_utils.lua with new components
4. **Advanced Logistics Control:** Extend logistics_utils.lua with new capabilities

---

## References

- **spec.md** - Feature requirements
- **module_responsibility_matrix.md** - Code organization rules
- **todo.md** - Development roadmap
- **CLAUDE.md** - Project conventions

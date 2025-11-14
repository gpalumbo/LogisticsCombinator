# Mission Control Mod - Code Architecture Plan

## File Structure

```
mod/
├── info.json                          # Mod metadata
├── changelog.txt                      # Version history
├── thumbnail.png                      # Mod portal thumbnail (144x144)
│
├── data.lua                           # Main data phase loader
├── control.lua                        # Main control phase entry point
│
├── lib/                               # Shared utility libraries (pure functions)
│   ├── signal_utils.lua               # Signal manipulation (add, merge, copy, compare)
│   ├── circuit_utils.lua              # Circuit network I/O operations
│   ├── platform_utils.lua             # Platform detection and orbit checking
│   ├── validation.lua                 # Placement validation and refund logic
│   ├── logistics_utils.lua            # Logistics group injection/removal
│   └── gui_utils.lua                  # Common GUI creation helpers
│
├── scripts/                           # Entity-specific control logic
│   ├── globals.lua                    # Global state initialization and accessors
│   ├── mission_control.lua            # MC building lifecycle and signal aggregation
│   ├── receiver_combinator.lua        # Receiver lifecycle and orbit detection
│   ├── logistics_combinator.lua       # Logistics combinator logic and rules
│   ├── network_manager.lua            # Cross-surface signal transmission coordinator
│   └── gui_handlers.lua               # GUI event handlers for all entities
│
├── prototypes/                        # Data phase definitions
│   ├── technology.lua                 # Tech tree additions
│   ├── entity/                        # Entity prototypes (one per entity type)
│   │   ├── mission_control.lua        # MC building entity definition
│   │   ├── receiver_combinator.lua    # Receiver entity definition
│   │   └── logistics_combinator.lua   # Logistics combinator entity definition
│   ├── item.lua                       # All item definitions
│   └── recipe.lua                     # All recipe definitions
│
├── locale/                            # Localization
│   └── en/
│       └── mission-control.cfg        # English strings
│
└── graphics/                          # Visual assets (placeholders initially)
    ├── icons/                         # Item and entity icons (64x64)
    │   ├── mission-control-building.png
    │   ├── receiver-combinator.png
    │   └── logistics-combinator.png
    ├── technology/                    # Technology icons (256x256)
    │   ├── mission-control.png
    │   └── logistics-circuit-control.png
    └── entity/                        # Entity sprites (deferred)
        ├── mission-control/
        ├── receiver-combinator/
        └── logistics-combinator/
```

---

## Placement Validation Strategy

**IMPORTANT:** This mod uses Factorio's native **TileBuildabilityRule** system for entity placement restrictions instead of runtime Lua validation.

### Tile Buildability Rules

Defined in entity prototypes for native engine-level validation:

**Mission Control Building (Planet-Only):**
```lua
-- prototypes/entity/mission_control.lua
tile_buildability_rules = {
  {
    area = {{-2.4, -2.4}, {2.4, 2.4}},
    colliding_tiles = {"space-platform-foundation"},
    remove_on_collision = false
  }
}
```
Effect: Cannot be placed on space-platform-foundation tiles.

**Receiver Combinator (Platform-Only):**
```lua
-- prototypes/entity/receiver_combinator.lua
tile_buildability_rules = {
  {
    area = {{-0.9, -0.9}, {0.9, 0.9}},
    required_tiles = {"space-platform-foundation"},
    remove_on_collision = false
  }
}
```
Effect: Can ONLY be placed on space-platform-foundation tiles.

**Logistics Combinator (Anywhere):**
```lua
-- prototypes/entity/logistics_combinator.lua
-- No tile_buildability_rules = can be placed anywhere
```

### Why TileBuildabilityRule?

**Performance:**
- Zero Lua overhead (engine validates at placement time)
- No event handlers needed
- Instant visual feedback (red outline)

**Game Integration:**
- Blueprints respect rules automatically
- Construction robots obey restrictions
- Native Factorio UX (no custom error messages needed)

**Code Simplicity:**
- No refund logic required
- No runtime validation checks
- No global state tracking for placement

**Note:** `lib/validation.lua` is retained for reference but is NOT used by the mod. See `docs/tile_buildability_approach.md` for full details.

---

## Library Module Specifications

### 1. `lib/signal_utils.lua`
**Purpose:** Pure functions for signal table manipulation
**Dependencies:** None
**Complexity:** ~150 lines

```lua
-- Add source signals into target (mutating target)
-- @param target table: Signal table to add into
-- @param source table: Signal table to add from
function add_signals(target, source)

-- Merge red and green signals for condition evaluation
-- @param red_signals table: Red wire signals
-- @param green_signals table: Green wire signals
-- @return table: Merged signal table (max value wins per signal)
function merge_signals(red_signals, green_signals)

-- Deep copy signal table
-- @param source table: Signal table to copy
-- @return table: New independent signal table
function copy_signals(source)

-- Compare two signal tables for equality
-- @param a table: First signal table
-- @param b table: Second signal table
-- @return boolean: True if identical
function signals_equal(a, b)

-- Reset signal table to empty
-- @param signals table: Signal table to clear
function clear_signals(signals)

-- Get signal count (for debugging/display)
-- @param signals table: Signal table
-- @return number: Count of unique signals
function count_signals(signals)
```

**Testing Strategy:** Include commented test cases showing expected behavior

---

### 2. `lib/circuit_utils.lua`
**Purpose:** Read/write circuit signals from entity connectors
**Dependencies:** None
**Complexity:** ~200 lines

```lua
-- Read signals from entity circuit connector
-- @param entity LuaEntity: Entity to read from
-- @param wire_type defines.wire_type: RED or GREEN
-- @param connector_id defines.circuit_connector_id: Which connector
-- @return table|nil: Signal table or nil if no connection
function get_circuit_signals(entity, wire_type, connector_id)

-- Write signals to entity circuit output (combinator behavior)
-- @param entity LuaEntity: Entity to write to
-- @param wire_type defines.wire_type: RED or GREEN
-- @param signals table: Signal table to output
-- @return boolean: Success status
function set_circuit_signals(entity, wire_type, signals)

-- Get merged input signals from both wire colors
-- @param entity LuaEntity: Entity to read from
-- @return table: Merged signals (red and green combined)
function get_merged_input_signals(entity)

-- Check if entity has circuit connection
-- @param entity LuaEntity: Entity to check
-- @param wire_type defines.wire_type: RED or GREEN
-- @return boolean: True if connected
function has_circuit_connection(entity, wire_type)

-- Get all entities connected to circuit network
-- @param circuit_network LuaCircuitNetwork: Network to scan
-- @return array: Array of connected entities
function get_connected_entities(circuit_network)

-- Validate entity can be used for circuit operations
-- @param entity LuaEntity: Entity to validate
-- @return boolean: True if valid and has circuit connections
function is_valid_circuit_entity(entity)
```

**Key Implementation Notes:**
- Always validate entity.valid before operations
- Handle nil circuit networks gracefully
- Use entity.get_circuit_network() API
- Respect circuit connector IDs for multi-connector entities

---

### 3. `lib/platform_utils.lua`
**Purpose:** Platform detection, orbit status, and space location queries
**Dependencies:** None
**Complexity:** ~200 lines

```lua
-- Check if surface is a space platform
-- @param surface LuaSurface: Surface to check
-- @return boolean: True if surface is a platform
function is_platform_surface(surface)

-- Get platform object from surface
-- @param surface LuaSurface: Platform surface
-- @return LuaSpacePlatform|nil: Platform object or nil
function get_platform_for_surface(surface)

-- Check if platform is orbiting specific surface
-- @param platform_id number: Platform unit number
-- @param surface_index number: Target surface index
-- @return boolean: True if orbiting AND stationary
function is_platform_orbiting(platform_id, surface_index)

-- Check if platform is stationary (not traveling)
-- @param platform LuaSpacePlatform: Platform to check
-- @return boolean: True if not in transit
function is_platform_stationary(platform)

-- Get surface being orbited by platform
-- @param platform LuaSpacePlatform: Platform to query
-- @return LuaSurface|nil: Orbited surface or nil
function get_orbited_surface(platform)

-- Find all platforms in game
-- @return array: Array of LuaSpacePlatform objects
function find_all_platforms()

-- Get platform from entity's surface
-- @param entity LuaEntity: Entity on platform
-- @return LuaSpacePlatform|nil: Platform or nil
function get_platform_from_entity(entity)

-- Check if two entities are on same platform
-- @param entity_a LuaEntity
-- @param entity_b LuaEntity
-- @return boolean: True if same platform
function on_same_platform(entity_a, entity_b)
```

**Key Implementation Notes:**
- Use `surface.platform` property to detect platforms
- Check `platform.space_location` for orbit status
- Check `platform.speed == 0` for stationary detection
- Handle destroyed platforms gracefully

---

### 4. `lib/validation.lua`
**Purpose:** Entity placement validation and player feedback
**Dependencies:** None
**Complexity:** ~150 lines

```lua
-- Validate Mission Control placement (planet-only)
-- @param entity LuaEntity: MC building
-- @param player LuaPlayer|nil: Player who placed (nil if robot)
-- @return boolean: True if valid placement
function validate_mission_control_placement(entity, player)

-- Validate Receiver Combinator placement (platform-only)
-- @param entity LuaEntity: Receiver combinator
-- @param player LuaPlayer|nil: Player who placed
-- @return boolean: True if valid placement
function validate_receiver_placement(entity, player)

-- Refund entity items and destroy entity
-- @param entity LuaEntity: Entity to refund
-- @param player LuaPlayer|nil: Player to refund to (nil if robot)
-- @param inventory LuaInventory|nil: Robot inventory to return items
function refund_entity(entity, player, inventory)

-- Show placement error message to player
-- @param player LuaPlayer: Player to notify
-- @param message_key string: Locale key for message
-- @param position MapPosition: Where to show message
function show_placement_error(player, message_key, position)

-- Check if surface allows entity type
-- @param surface LuaSurface: Surface to check
-- @param entity_name string: Entity name
-- @return boolean, string: Valid status and reason
function can_place_on_surface(surface, entity_name)
```

**Locale Keys Required:**
- `message.mc-planet-only`
- `message.receiver-platform-only`
- `message.placement-invalid`

---

### 5. `lib/logistics_utils.lua`
**Purpose:** Logistics group injection, removal, and tracking
**Dependencies:** None
**Complexity:** ~300 lines

```lua
-- Find all logistics-enabled entities on circuit network
-- @param circuit_network LuaCircuitNetwork: Network to scan
-- @return array: Array of entities with logistic_sections
function find_logistics_entities_on_network(circuit_network)

-- Check if entity has specific logistics group
-- @param entity LuaEntity: Entity to check
-- @param group_name string: Group name to find
-- @return boolean: True if group exists
function has_logistics_group(entity, group_name)

-- Inject logistics group into entity
-- @param entity LuaEntity: Target entity
-- @param group_template table: Group definition
-- @param combinator_id number: Combinator unit_number for tracking
-- @return boolean: Success status
function inject_logistics_group(entity, group_template, combinator_id)

-- Remove logistics group from entity
-- @param entity LuaEntity: Target entity
-- @param group_name string: Group to remove
-- @param combinator_id number: Only remove if injected by this combinator
-- @return boolean: Success status
function remove_logistics_group(entity, group_name, combinator_id)

-- Get logistics group definition by name
-- @param group_name string: Name of group
-- @return table|nil: Group template or nil
function get_logistics_group_template(group_name)

-- Track injected group for cleanup
-- @param entity_id number: Entity unit_number
-- @param section_index number: Logistic section index
-- @param combinator_id number: Combinator that injected it
function track_injected_group(entity_id, section_index, combinator_id)

-- Remove all groups injected by combinator
-- @param combinator_id number: Combinator unit_number
function cleanup_combinator_groups(combinator_id)

-- Remove all groups injected into entity
-- @param entity_id number: Entity unit_number
function cleanup_entity_groups(entity_id)

-- Check if entity supports logistics control
-- @param entity LuaEntity: Entity to check
-- @return boolean: True if has logistic_sections
function supports_logistics_control(entity)
```

**Global Structure:**
```lua
global.injected_groups = {
  [entity_unit_number] = {
    [section_index] = combinator_unit_number
  }
}
```

---

### 6. `lib/gui_utils.lua`
**Purpose:** Common GUI creation patterns and helpers
**Dependencies:** None
**Complexity:** ~250 lines

```lua
-- Create standard titlebar with close button
-- @param parent LuaGuiElement: Parent container
-- @param title LocalisedString: Window title
-- @param close_button_name string: Name for close button
-- @return LuaGuiElement: Created titlebar
function create_titlebar(parent, title, close_button_name)

-- Create row of buttons
-- @param parent LuaGuiElement: Parent container
-- @param buttons array: Array of {name, caption, tooltip}
-- @return LuaGuiElement: Created button flow
function create_button_row(parent, buttons)

-- Close GUI for player by name
-- @param player LuaPlayer: Player whose GUI to close
-- @param gui_name string: Name of root GUI element
function close_gui_for_player(player, gui_name)

-- Center GUI element on screen
-- @param gui_element LuaGuiElement: Root GUI element to center
function center_gui(gui_element)

-- Create condition selector (signal + operator + value)
-- @param parent LuaGuiElement: Parent container
-- @param name_prefix string: Prefix for child element names
-- @return table: {signal_chooser, operator_dropdown, value_field}
function create_condition_selector(parent, name_prefix)

-- Create status label with icon
-- @param parent LuaGuiElement: Parent container
-- @param status_text LocalisedString: Status message
-- @param icon_type string: "connected", "disconnected", "warning"
-- @return LuaGuiElement: Created label
function create_status_label(parent, status_text, icon_type)

-- Populate dropdown with standard operators
-- @param dropdown LuaGuiElement: Dropdown element
function populate_operator_dropdown(dropdown)

-- Get operator symbol from dropdown index
-- @param index number: Dropdown selected index
-- @return string: Operator symbol (<, >, =, etc.)
function get_operator_from_index(index)

-- Get dropdown index from operator symbol
-- @param operator string: Operator symbol
-- @return number: Dropdown index
function get_index_from_operator(operator)

-- Evaluate circuit condition
-- @param signals table: Current signal values
-- @param condition table: {signal, operator, value}
-- @return boolean: True if condition met
function evaluate_condition(signals, condition)
```

**Standard GUI Style Constants:**
```lua
local GUI_CONSTANTS = {
  TITLEBAR_HEIGHT = 28,
  BUTTON_HEIGHT = 28,
  SPACING = 8,
  PADDING = 12,
  MIN_WIDTH = 300,
  MAX_WIDTH = 600
}
```

---

## Script Module Specifications

### 7. `scripts/globals.lua`
**Purpose:** Centralized global state management
**Dependencies:** None
**Complexity:** ~300 lines

```lua
-- Initialize all global tables
function init_globals()
  global.mc_networks = global.mc_networks or {}
  global.platform_receivers = global.platform_receivers or {}
  global.logistics_combinators = global.logistics_combinators or {}
  global.injected_groups = global.injected_groups or {}
  global.gui_state = global.gui_state or {}
end

-- Get or create MC network for surface
-- @param surface_index number
-- @return table: Network state
function get_mc_network(surface_index)

-- Register Mission Control building
-- @param entity LuaEntity
function register_mc_building(entity)

-- Unregister Mission Control building
-- @param entity LuaEntity
function unregister_mc_building(entity)

-- Register receiver combinator
-- @param entity LuaEntity
-- @return number: Assigned receiver ID
function register_receiver(entity)

-- Unregister receiver combinator
-- @param unit_number number
function unregister_receiver(unit_number)

-- Register logistics combinator
-- @param entity LuaEntity
function register_logistics_combinator(entity)

-- Unregister logistics combinator
-- @param unit_number number
function unregister_logistics_combinator(unit_number)

-- Get receiver data
-- @param unit_number number
-- @return table|nil: Receiver state
function get_receiver_data(unit_number)

-- Get logistics combinator data
-- @param unit_number number
-- @return table|nil: Combinator state
function get_logistics_combinator_data(unit_number)

-- Update receiver configured surfaces
-- @param unit_number number
-- @param surface_indices array
function update_receiver_surfaces(unit_number, surface_indices)

-- Add rule to logistics combinator
-- @param unit_number number
-- @param rule table
function add_logistics_rule(unit_number, rule)

-- Remove rule from logistics combinator
-- @param unit_number number
-- @param rule_index number
function remove_logistics_rule(unit_number, rule_index)
```

**Global Structure:**
```lua
global = {
  mc_networks = {
    [surface_index] = {
      buildings = {[unit_number] = LuaEntity},
      red_signals = {},
      green_signals = {},
      last_update = tick
    }
  },

  platform_receivers = {
    [unit_number] = {
      entity = LuaEntity,
      configured_surfaces = {surface_index = true},
      connected_surface = surface_index | nil,
      last_check = tick
    }
  },

  logistics_combinators = {
    [unit_number] = {
      entity = LuaEntity,
      rules = {
        {group_name = "...", condition = {...}, action = "inject"|"remove", last_state = false}
      },
      connected_entities = {[unit_number] = LuaEntity},
      last_update = tick
    }
  },

  injected_groups = {
    [entity_unit_number] = {
      [section_index] = combinator_unit_number
    }
  },

  gui_state = {
    [player_index] = {
      open_entity = unit_number,
      gui_type = "receiver"|"logistics"
    }
  }
}
```

---

### 8. `scripts/mission_control.lua`
**Purpose:** Mission Control building lifecycle and signal aggregation
**Dependencies:** lib/*, scripts/globals.lua
**Complexity:** ~400 lines

```lua
-- Handle MC building placement
-- @param entity LuaEntity
-- @param player LuaPlayer|nil
function on_mc_built(entity, player)

-- Handle MC building removal
-- @param entity LuaEntity
function on_mc_removed(entity)

-- Update MC network for surface (aggregate inputs)
-- @param surface_index number
function update_mc_network(surface_index)

-- Get aggregated signals from all MCs on surface
-- @param surface_index number
-- @return table, table: red_signals, green_signals
function get_mc_aggregated_signals(surface_index)

-- Set output signals for all MCs on surface
-- @param surface_index number
-- @param red_signals table
-- @param green_signals table
function set_mc_outputs(surface_index, red_signals, green_signals)

-- Cleanup MC network if no buildings remain
-- @param surface_index number
function cleanup_mc_network(surface_index)
```

**Key Behaviors:**
- All MCs on surface aggregate inputs (SUM)
- All MCs output same signals (broadcast from platforms)
- Red and green networks separate
- Validate planet-only placement
- Auto-cleanup empty networks

---

### 9. `scripts/receiver_combinator.lua`
**Purpose:** Receiver combinator lifecycle and orbit detection
**Dependencies:** lib/*, scripts/globals.lua
**Complexity:** ~350 lines

```lua
-- Handle receiver placement
-- @param entity LuaEntity
-- @param player LuaPlayer|nil
function on_receiver_built(entity, player)

-- Handle receiver removal
-- @param entity LuaEntity
function on_receiver_removed(entity)

-- Check and update receiver connection status
-- @param unit_number number
-- @return boolean: Currently connected
function check_receiver_connection(unit_number)

-- Relay signals from planet to platform
-- @param unit_number number
-- @param red_signals table
-- @param green_signals table
function relay_to_platform(unit_number, red_signals, green_signals)

-- Relay signals from platform to planet
-- @param unit_number number
-- @return table, table: red_signals, green_signals to send to planet
function relay_from_platform(unit_number)

-- Get connection status string
-- @param unit_number number
-- @return LocalisedString: Status message
function get_receiver_status(unit_number)

-- Update all receiver connections (called every 60 ticks)
function update_all_receivers()
```

**Key Behaviors:**
- Platform-only placement
- Open GUI on placement
- Only active when orbiting + stationary
- Bidirectional signal relay
- Connection status tracking

---

### 10. `scripts/logistics_combinator.lua`
**Purpose:** Logistics combinator logic and rule processing
**Dependencies:** lib/*, scripts/globals.lua
**Complexity:** ~450 lines

```lua
-- Handle logistics combinator placement
-- @param entity LuaEntity
-- @param player LuaPlayer|nil
function on_logistics_combinator_built(entity, player)

-- Handle logistics combinator removal
-- @param entity LuaEntity
function on_logistics_combinator_removed(entity)

-- Process all rules for combinator
-- @param unit_number number
function process_logistics_rules(unit_number)

-- Update connected entity cache
-- @param unit_number number
function update_connected_entities(unit_number)

-- Process single rule
-- @param rule table
-- @param input_signals table
-- @param connected_entities array
function process_rule(rule, input_signals, connected_entities)

-- Check if rule condition changed state
-- @param rule table
-- @param current_signals table
-- @return boolean: State changed
function rule_state_changed(rule, current_signals)

-- Execute rule action (inject/remove)
-- @param rule table
-- @param entity LuaEntity
-- @param condition_met boolean
function execute_rule_action(rule, entity, condition_met)

-- Get rule status for display
-- @param rule table
-- @param current_signals table
-- @return string: "active"|"inactive"
function get_rule_status(rule, current_signals)

-- Validate rule configuration
-- @param rule table
-- @return boolean, string: Valid status and error message
function validate_rule(rule)
```

**Key Behaviors:**
- Open GUI on placement
- Edge-triggered rule execution
- Track injected groups
- Cache connected entities
- Update on wire changes

---

### 11. `scripts/network_manager.lua`
**Purpose:** Coordinate cross-surface signal transmission
**Dependencies:** scripts/*, lib/*
**Complexity:** ~400 lines

```lua
-- Main transmission update (every 15 ticks)
function update_transmissions()

-- Process ground-to-space signals
-- @param surface_index number
function process_ground_to_space(surface_index)

-- Process space-to-ground signals
-- @param surface_index number
function process_space_to_ground(surface_index)

-- Find receivers orbiting surface
-- @param surface_index number
-- @return array: Array of receiver unit_numbers
function find_receivers_for_surface(surface_index)

-- Aggregate platform signals for surface
-- @param surface_index number
-- @return table, table: red_signals, green_signals
function aggregate_platform_signals(surface_index)

-- Update platform connection states (every 60 ticks)
function update_platform_connections()

-- Handle platform arrival at destination
-- @param platform LuaSpacePlatform
function on_platform_arrived(platform)

-- Handle platform departure
-- @param platform LuaSpacePlatform
function on_platform_departed(platform)
```

**Key Behaviors:**
- 15-tick update cycle for signals
- 60-tick update cycle for connections
- Aggregate before transmission
- Preserve wire separation
- Handle platform movement

---

### 12. `scripts/gui_handlers.lua`
**Purpose:** GUI event handlers for all entity types
**Dependencies:** lib/gui_utils.lua, scripts/globals.lua
**Complexity:** ~600 lines

```lua
-- === Receiver Combinator GUI ===

-- Create receiver configuration GUI
-- @param player LuaPlayer
-- @param entity LuaEntity
function create_receiver_gui(player, entity)

-- Update receiver GUI display
-- @param player LuaPlayer
function update_receiver_gui(player)

-- Handle surface checkbox changed
-- @param event EventData
function on_receiver_surface_changed(event)

-- Handle Select All button
-- @param event EventData
function on_receiver_select_all(event)

-- Handle Clear All button
-- @param event EventData
function on_receiver_clear_all(event)

-- === Logistics Combinator GUI ===

-- Create logistics combinator GUI
-- @param player LuaPlayer
-- @param entity LuaEntity
function create_logistics_gui(player, entity)

-- Update logistics GUI display
-- @param player LuaPlayer
function update_logistics_gui(player)

-- Handle Add Rule button
-- @param event EventData
function on_logistics_add_rule(event)

-- Handle Delete Rule button
-- @param event EventData
function on_logistics_delete_rule(event)

-- Handle group selection changed
-- @param event EventData
function on_logistics_group_changed(event)

-- Handle condition signal changed
-- @param event EventData
function on_logistics_signal_changed(event)

-- Handle operator changed
-- @param event EventData
function on_logistics_operator_changed(event)

-- Handle value changed
-- @param event EventData
function on_logistics_value_changed(event)

-- Handle action radio button
-- @param event EventData
function on_logistics_action_changed(event)

-- === Common Handlers ===

-- Route GUI opened event
-- @param event EventData
function on_gui_opened(event)

-- Route GUI closed event
-- @param event EventData
function on_gui_closed(event)

-- Clean up player GUI state
-- @param player_index number
function cleanup_player_gui(player_index)
```

**GUI Element Naming Convention:**
```
mc_gui_<entity_type>_<element_purpose>_<index>

Examples:
- mc_gui_receiver_surface_checkbox_1
- mc_gui_receiver_select_all_button
- mc_gui_logistics_rule_flow_3
- mc_gui_logistics_add_rule_button
```

---

## Control.lua Event Registration

```lua
-- control.lua (main entry point)

-- Import all modules
require("scripts.mc_globals")
require("scripts.mission_control")
require("scripts.receiver_combinator")
require("scripts.logistics_combinator")
require("scripts.network_manager")
require("scripts.gui_handlers")

-- Initialization
script.on_init(function()
  init_globals()
end)

script.on_configuration_changed(function(data)
  init_globals()
  -- Handle migrations
end)

-- Entity lifecycle
local function on_entity_built(event)
  local entity = event.created_entity or event.entity
  if not entity.valid then return end

  local player = event.player_index and game.get_player(event.player_index)

  if entity.name == "mission-control-building" then
    on_mc_built(entity, player)
  elseif entity.name == "receiver-combinator" then
    on_receiver_built(entity, player)
  elseif entity.name == "logistics-combinator" then
    on_logistics_combinator_built(entity, player)
  end
end

local function on_entity_removed(event)
  local entity = event.entity
  if not entity.valid then return end

  if entity.name == "mission-control-building" then
    on_mc_removed(entity)
  elseif entity.name == "receiver-combinator" then
    on_receiver_removed(entity)
  elseif entity.name == "logistics-combinator" then
    on_logistics_combinator_removed(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)
script.on_event(defines.events.script_raised_destroy, on_entity_removed)

-- Circuit events
script.on_event(defines.events.on_wire_added, function(event)
  -- Update connected entity caches for logistics combinators
end)

script.on_event(defines.events.on_wire_removed, function(event)
  -- Update connected entity caches for logistics combinators
end)

-- GUI events
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_changed, on_gui_checked_changed)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

-- Periodic updates
script.on_nth_tick(15, update_transmissions)
script.on_nth_tick(60, update_platform_connections)

-- Platform events
script.on_event(defines.events.on_space_platform_built, function(event)
  -- Initialize platform tracking
end)

script.on_event(defines.events.on_space_platform_destroyed, function(event)
  -- Cleanup platform receivers
end)
```

---

## Data.lua Loading Order

```lua
-- data.lua (main data phase entry point)

-- Load prototypes in dependency order
require("prototypes.technology")

require("prototypes.entity.mission_control")
require("prototypes.entity.receiver_combinator")
require("prototypes.entity.logistics_combinator")

require("prototypes.item")
require("prototypes.recipe")
```

---

## Development Workflow

### Phase 1: Libraries First
1. Implement all `lib/` modules with inline test cases
2. Test each utility function independently
3. Document edge cases and limitations
4. Code review for correctness

### Phase 2: Global State
1. Implement `scripts/globals.lua`
2. Define complete data structures
3. Test initialization and cleanup
4. Verify serialization/deserialization

### Phase 3: Prototypes
1. Create all entity definitions
2. Test in-game placement
3. Verify circuit connections work
4. Check graphics appear (placeholders)

### Phase 4: Entity Logic
1. Implement one entity type at a time
2. Test lifecycle (build, operate, destroy)
3. Verify state management
4. Test save/load

### Phase 5: Integration
1. Connect entities via network_manager
2. Test cross-surface communication
3. Verify signal flow end-to-end
4. Performance profiling

### Phase 6: GUI
1. Implement GUI creation
2. Wire up event handlers
3. Test user interactions
4. Polish UX

### Phase 7: Polish
1. Edge case handling
2. Error messages
3. Visual feedback
4. Performance optimization

---

## Testing Strategy

### Unit Testing (per module)
- Test each function with various inputs
- Test edge cases (nil, invalid entities, etc.)
- Document expected behavior in comments
- Manual verification in-game

### Integration Testing
- Test entity interactions
- Test signal flow across surfaces
- Test platform movement scenarios
- Test multiplayer synchronization

### Performance Testing
- Large base scenarios (50+ MCs, 20+ platforms)
- Profile update functions
- Monitor tick time impact
- Optimize hot paths

### Compatibility Testing
- Test with popular mods
- Test migration from earlier versions
- Test with existing saves
- Test multiplayer desync prevention

---

## Coding Standards

### Naming Conventions
- Functions: `snake_case`
- Local variables: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Global tables: `snake_case`
- GUI elements: `mc_gui_<type>_<purpose>`

### Documentation
- Module header with purpose and dependencies
- Function documentation with @param and @return
- Complex logic explained with inline comments
- Edge cases documented

### Error Handling
- Validate entity.valid before operations
- Handle nil gracefully
- Log errors to player console
- Never crash the game

### Performance
- Cache expensive lookups
- Use locals for frequently accessed globals
- Minimize table allocations
- Profile before optimizing
- Comment performance-critical sections

---

## File Size Guidelines

Target line counts (excluding comments):
- Library modules: 100-300 lines each
- Script modules: 300-600 lines each
- Prototype files: 100-200 lines each
- control.lua: 200-300 lines (mostly event registration)
- data.lua: 20-30 lines (just requires)

If any file exceeds 750 lines, split into sub-modules.

---

## Next Steps

1. Create directory structure under `mod/`
2. Implement `lib/signal_utils.lua` first (foundation)
3. Implement remaining lib modules
4. Create `scripts/globals.lua`
5. Create prototype files with placeholders
6. Test mod loads without errors
7. Begin entity-specific implementation

**Ready to start implementation!**

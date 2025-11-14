# Module Responsibility Matrix
## Single Source of Truth for Code Organization

This document defines EXACTLY what belongs in each module, what doesn't belong, and how to make decisions when it's ambiguous.

---

## Decision Framework

### The Golden Rules

1. **Stateless vs Stateful**
   - `lib/` modules = Pure functions, NO global state access
   - `scripts/` modules = Stateful logic, CAN access global tables

2. **Data vs Behavior**
   - `prototypes/` = Static definitions (data phase)
   - `lib/` & `scripts/` = Runtime behavior (control phase)

3. **Generic vs Specific**
   - `lib/` = Generic utilities usable by any entity type
   - `scripts/` = Entity-specific or cross-entity coordination logic

4. **Single Responsibility Principle**
   - Each module owns ONE domain concept
   - If a function needs data from 2+ modules, it belongs in the coordination layer

---

## 🚨 CRITICAL: Factorio 2.0 API Migration Guide 🚨

### Wire Events DO NOT EXIST
**IMPORTANT:** The following events **NEVER EXISTED** in Factorio's API and were mistakenly referenced in our code:
- `defines.events.on_wire_created` ❌ DOES NOT EXIST
- `defines.events.on_wire_removed` ❌ DOES NOT EXIST
- `defines.events.on_wire_added` ❌ DOES NOT EXIST
- `defines.events.on_wire_disconnected` ❌ DOES NOT EXIST

**Why no wire events?** Factorio developers rejected this feature request because connecting/disconnecting networks destroys and recreates networks, which would trigger cascading events for every entity on the network.

**Solution:** Use **POLLING** instead:
- Connection discovery: `on_nth_tick(60)` checks for new wire connections
- Rule processing: `on_tick` processes rules and checks connections when conditions change

See: https://forums.factorio.com/viewtopic.php?t=46375

### Persistent Storage: `global` → `storage`

**CRITICAL CHANGE:** In Factorio 2.0, the persistent mod data table was renamed from `global` to `storage`.

**Factorio 1.1 (OLD):**
```lua
global.my_data = {}
global.logistics_combinators[unit_number] = {...}
```

**Factorio 2.0 (NEW):**
```lua
storage.my_data = {}
storage.logistics_combinators[unit_number] = {...}
```

**Why the change?** The name "global" was confusing because:
1. It collided with Lua's `_G` global namespace concept
2. It wasn't clear that this was persistent storage (survives save/load)
3. "storage" better describes its purpose: persistent mod data

**Reference:** https://lua-api.factorio.com/latest/auxiliary/storage.html

**In our mod:**
- ✅ `storage.logistics_combinators` - Persistent combinator data
- ✅ `storage.injected_groups` - Track which groups we injected
- ✅ `mc_globals` module manages the `storage` table

**DO NOT confuse with:**
- `settings.global` - Runtime mod settings (different system entirely)
- `_G` - Lua's global namespace (not persistent, not recommended)

### Circuit Network API Changes (1.1 → 2.0)

Factorio 2.0 introduced `wire_connector_id` to replace separate `wire_type` and `circuit_connector_id` parameters.

#### API Migration Table

| Factorio 1.1 (OLD) | Factorio 2.0 (NEW) |
|--------------------|--------------------|
| `entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)` | `entity.get_circuit_network(defines.wire_connector_id.combinator_input_red)` |
| `entity.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)` | `entity.get_circuit_network(defines.wire_connector_id.combinator_input_green)` |
| `entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)` | `entity.get_circuit_network(defines.wire_connector_id.combinator_output_red)` |
| `entity.circuit_connected_entities` | `entity.get_wire_connectors()` → iterate `wire_connector.real_connections` |

#### Wire Connector IDs (2.0)

```lua
defines.wire_connector_id.circuit_red             -- Generic red circuit connector
defines.wire_connector_id.circuit_green           -- Generic green circuit connector
defines.wire_connector_id.combinator_input_red    -- Combinator red input
defines.wire_connector_id.combinator_input_green  -- Combinator green input
defines.wire_connector_id.combinator_output_red   -- Combinator red output
defines.wire_connector_id.combinator_output_green -- Combinator green output
```

#### Finding Connected Entities (2.0)

**OLD (1.1):**
```lua
local connected = entity.circuit_connected_entities
for _, e in pairs(connected.red or {}) do
  -- Process entities on red network
end
for _, e in pairs(connected.green or {}) do
  -- Process entities on green network
end
```

**NEW (2.0):**
```lua
local wire_connectors = entity.get_wire_connectors(false)
for connector_id, wire_connector in pairs(wire_connectors) do
  for _, connected_connector in pairs(wire_connector.real_connections) do
    local connected_entity = connected_connector.owner
    -- Process connected entity
  end
end
```

#### Reading Circuit Signals (2.0)

**OLD (1.1):**
```lua
local network = entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
```

**NEW (2.0):**
```lua
local network = entity.get_circuit_network(defines.wire_connector_id.combinator_input_red)
```

### control_behavior and Circuit Networks

**Q: Does `control_behavior` help with circuit network operations?**

**A: Partially, but not significantly:**

`control_behavior.get_circuit_network(wire_connector_id)` provides the same functionality as `entity.get_circuit_network(wire_connector_id)` - they're just different API paths to the same data.

**What control_behavior CAN do:**
- Access circuit networks (same as entity API)
- Read combinator output history (`signals_last_tick`)
- Configure vanilla combinator parameters

**What control_behavior CANNOT do:**
- Detect when circuit connections change (requires polling)
- Detect when input signals change (requires polling)
- Provide any events or callbacks (no events exist!)

**Recommendation:** Use `entity.get_circuit_network()` directly unless you're already using `control_behavior` for other purposes.

---

## LIB Modules (Pure Utilities)

### lib/signal_utils.lua

**OWNS:**
- Signal table manipulation (add, merge, copy, compare, clear)
- Signal counting and statistics
- Signal table validation
- Signal formatting for display

**DOES NOT OWN:**
- Reading signals from entities (that's circuit_utils)
- Storing signals in global (that's entity scripts)
- Evaluating conditions (that's gui_utils)
- Entity-specific signal logic

**Decision Criteria:**
- ✅ "Does this operate on signal tables without knowing where they came from?" → signal_utils
- ❌ "Does this need to know about entities or circuit networks?" → circuit_utils
- ❌ "Does this need to store state?" → scripts/

**Examples:**
```lua
-- ✅ BELONGS HERE
function add_signals(target, source)  -- Pure table operation
function count_signals(signals)        -- Pure computation
function format_signal_for_display(signal_id, count)  -- Pure formatting

-- ❌ DOES NOT BELONG
function get_entity_signals(entity)    -- Uses entity → circuit_utils
function store_signals_for_later(...)  -- Stores state → scripts/
function evaluate_signal_condition(...) -- Business logic → gui_utils or entity script
```

---

### lib/circuit_utils.lua

**OWNS:**
- Reading signals from entity circuit connectors
- Writing signals to entity outputs
- Checking if entity has circuit connections
- Finding entities on circuit networks
- Circuit connector enumeration
- Entity circuit capability validation

**DOES NOT OWN:**
- Signal table operations (that's signal_utils)
- Entity placement validation (that's validation)
- Platform-specific logic (that's platform_utils)
- Global state access (that's scripts/)

**Decision Criteria:**
- ✅ "Does this interact with Factorio's circuit network API?" → circuit_utils
- ✅ "Does this query/modify entity circuit connections?" → circuit_utils
- ❌ "Does this manipulate signal tables after reading them?" → signal_utils
- ❌ "Does this validate entity placement?" → validation

**Examples:**
```lua
-- ✅ BELONGS HERE
function get_circuit_signals(entity, wire_type, connector_id)
function has_circuit_connection(entity, wire_type)
function get_connected_entities(circuit_network)

-- ❌ DOES NOT BELONG
function add_signals(target, source)   -- Pure table op → signal_utils
function validate_placement(entity)    -- Placement logic → validation
function is_platform_surface(surface)  -- Platform logic → platform_utils
```

---

### lib/platform_utils.lua

**OWNS:**
- Platform detection (is surface a platform?)
- Platform object retrieval
- Orbit status checking
- Platform movement state (stationary/traveling)
- Surface-platform relationship queries
- Platform enumeration

**DOES NOT OWN:**
- Receiver-specific logic (that's scripts/receiver_combinator)
- Signal transmission (that's scripts/network_manager)
- Global platform state storage (that's scripts/globals)
- Entity validation beyond platform checks

**Decision Criteria:**
- ✅ "Is this a query about platforms or space locations?" → platform_utils
- ✅ "Does this determine platform state without side effects?" → platform_utils
- ❌ "Does this act on platform state (send signals, update entities)?" → scripts/network_manager
- ❌ "Does this store platform data?" → scripts/globals

**Examples:**
```lua
-- ✅ BELONGS HERE
function is_platform_surface(surface)
function is_platform_orbiting(platform_id, surface_index)
function is_platform_stationary(platform)
function get_orbited_surface(platform)

-- ❌ DOES NOT BELONG
function update_receiver_connection(receiver_id)  -- State update → scripts/receiver_combinator
function send_signals_to_platform(...)            -- Action → scripts/network_manager
function register_receiver(entity)                 -- State storage → scripts/globals
```

---

### lib/validation.lua ⚠️ **DEPRECATED - OPTIONAL MODULE**

**⚠️ ARCHITECTURAL NOTE:** This module is **SUPERSEDED** by Factorio's native `TileBuildabilityRule` system (see `docs/tile_buildability_approach.md`). Tile buildability rules are defined in entity prototypes and provide superior performance, game integration, and simplicity.

**RECOMMENDED APPROACH:**
- Mission Control: Use `colliding_tiles = {"space-platform-foundation"}` in prototype
- Receiver Combinator: Use `required_tiles = {"space-platform-foundation"}` in prototype
- Logistics Combinator: No restrictions needed

**Current Status:** Module implemented but NOT imported by any scripts. Retained only for reference or optional custom error messages.

**ORIGINALLY OWNED (NOW HANDLED BY TILE RULES):**
- Entity placement validation (planet-only, platform-only)
- Placement error messages
- Entity refund logic
- Surface capability checking
- Player notification for placement errors

**DOES NOT OWN:**
- Entity registration after successful placement (that's scripts/globals)
- Circuit connection validation (that's circuit_utils)
- Rule/configuration validation (that's entity scripts)
- General error handling

**Decision Criteria (IF CUSTOM MESSAGES NEEDED):**
- ✅ "Is this about providing enhanced error feedback?" → validation (optional)
- ❌ "Is this about primary placement enforcement?" → Use tile_buildability_rules
- ❌ "Is this about what happens AFTER successful placement?" → scripts/
- ❌ "Is this about runtime behavior validation?" → entity scripts

**Examples:**
```lua
-- ✅ BELONGS HERE (if module is used)
function validate_mission_control_placement(entity, player)
function validate_receiver_placement(entity, player)
function refund_entity(entity, player, inventory)
function show_placement_error(player, message_key, position)

-- ❌ DOES NOT BELONG
function register_mc_building(entity)              -- Post-placement → scripts/globals
function validate_rule_condition(rule)             -- Runtime validation → scripts/logistics_combinator
function check_circuit_connection(entity)          -- Circuit check → circuit_utils
```

**NOTE:** In Phase 2+ implementation, tile_buildability_rules should be used instead of importing this module.

---

### lib/logistics_utils.lua

**OWNS:**
- Finding logistics-enabled entities on networks
- Checking if entity has specific logistics group
- Injecting logistics groups (the act of injection)
- Removing logistics groups (the act of removal)
- Logistics group capability detection
- Logistics section manipulation

**DOES NOT OWN:**
- Rule storage and evaluation (that's scripts/logistics_combinator)
- Tracking which combinator injected what (that's scripts/globals)
- Deciding WHEN to inject/remove (that's scripts/logistics_combinator)
- Connected entity caching (that's scripts/logistics_combinator)

**Decision Criteria:**
- ✅ "Is this a low-level logistics section operation?" → logistics_utils
- ✅ "Does this directly manipulate LuaLogisticSection?" → logistics_utils
- ❌ "Does this decide when/why to inject?" → scripts/logistics_combinator
- ❌ "Does this track injection history?" → scripts/globals

**Examples:**
```lua
-- ✅ BELONGS HERE
function inject_logistics_group(entity, group_template, combinator_id)
function remove_logistics_group(entity, group_name, combinator_id)
function has_logistics_group(entity, group_name)
function supports_logistics_control(entity)

-- ❌ DOES NOT BELONG
function process_logistics_rules(combinator_id)    -- Business logic → scripts/logistics_combinator
function track_injected_group(entity_id, ...)      -- State tracking → scripts/globals
function evaluate_condition(signals, condition)    -- Rule evaluation → scripts/logistics_combinator
```

**CRITICAL BOUNDARY:**
This module performs injections but doesn't track them in global. The entity script calls this module and then updates global state.

---

### lib/gui_utils.lua

**OWNS:**
- Generic GUI element creation (titlebar, buttons, flows)
- GUI layout helpers
- GUI positioning (centering, etc.)
- Condition selector UI creation (signal + operator + value)
- Operator dropdown population
- Condition evaluation (signal comparison logic)
- Operator conversion (symbol ↔ index)

**DOES NOT OWN:**
- Entity-specific GUI layouts (that's scripts/gui_handlers)
- GUI state storage (that's scripts/globals)
- GUI event handling (that's scripts/gui_handlers)
- Opening/closing GUIs for specific entities

**Decision Criteria:**
- ✅ "Is this a reusable GUI pattern used by multiple entity types?" → gui_utils
- ✅ "Is this GUI logic with no entity-specific knowledge?" → gui_utils
- ❌ "Is this specific to receiver/logistics combinator GUI?" → scripts/gui_handlers
- ❌ "Does this store GUI state?" → scripts/globals

**Examples:**
```lua
-- ✅ BELONGS HERE
function create_titlebar(parent, title, close_button_name)
function create_condition_selector(parent, name_prefix)
function evaluate_condition(signals, condition)    -- Generic signal comparison
function populate_operator_dropdown(dropdown)

-- ❌ DOES NOT BELONG
function create_receiver_gui(player, entity)       -- Entity-specific → scripts/gui_handlers
function on_gui_opened(event)                      -- Event handling → scripts/gui_handlers
function get_gui_state(player_index)               -- State access → scripts/globals
```

**SPECIAL NOTE:** `evaluate_condition` belongs here because it's generic signal comparison logic used by logistics combinators. It doesn't know about combinator-specific rules or state.

---

## SCRIPTS Modules (Stateful Logic)

### scripts/globals.lua

**OWNS:**
- Global table initialization
- Global state accessors (get/set)
- Entity registration/unregistration in global
- Global data structure management
- Migration support functions
- Global state validation

**DOES NOT OWN:**
- Business logic (what to do with the data)
- Entity lifecycle hooks
- Signal processing
- GUI creation
- Any game logic

**Decision Criteria:**
- ✅ "Is this about storing or retrieving from global?" → globals.lua
- ✅ "Is this initializing global structure?" → globals.lua
- ❌ "Is this processing the data?" → entity script
- ❌ "Is this responding to events?" → entity script

**Examples:**
```lua
-- ✅ BELONGS HERE
function init_globals()
function register_mc_building(entity)
function get_mc_network(surface_index)
function unregister_receiver(unit_number)

-- ❌ DOES NOT BELONG
function update_mc_network(surface_index)         -- Processing → scripts/mission_control
function process_logistics_rules(combinator_id)   -- Business logic → scripts/logistics_combinator
function on_mc_built(entity, player)              -- Event handler → scripts/mission_control
```

**CRITICAL PATTERN:**
```lua
-- This module provides:
global.mc_networks[surface_index] = {...}  -- STRUCTURE
function get_mc_network(surface_index)     -- ACCESSOR

-- Other modules provide:
function update_mc_network(surface_index)  -- LOGIC
```

---

### scripts/mission_control.lua

**OWNS:**
- Mission Control entity lifecycle (build/remove)
- MC network signal aggregation
- MC output signal distribution
- MC-specific validation
- MC network cleanup
- All logic specific to the MC building

**DOES NOT OWN:**
- Platform detection (that's lib/platform_utils)
- Signal table operations (that's lib/signal_utils)
- Circuit I/O (that's lib/circuit_utils)
- Cross-surface transmission coordination (that's scripts/network_manager)
- Global registration (calls scripts/globals)

**Decision Criteria:**
- ✅ "Is this about what the MC building does?" → mission_control.lua
- ✅ "Is this MC-specific business logic?" → mission_control.lua
- ❌ "Is this about coordinating MC + receivers?" → scripts/network_manager
- ❌ "Is this a generic circuit operation?" → lib/circuit_utils

**Examples:**
```lua
-- ✅ BELONGS HERE
function on_mc_built(entity, player)
function on_mc_removed(entity)
function update_mc_network(surface_index)         -- Aggregate MC inputs
function set_mc_outputs(surface_index, red, green) -- Distribute to all MCs

-- ❌ DOES NOT BELONG
function get_circuit_signals(entity, wire_type)    -- Generic → lib/circuit_utils
function is_platform_orbiting(platform_id, ...)    -- Platform → lib/platform_utils
function update_transmissions()                    -- Coordination → scripts/network_manager
function register_mc_building(entity)              -- Registration → scripts/globals
```

**BOUNDARY WITH network_manager:**
- mission_control.lua: "What should the MC network output be?" (aggregation)
- network_manager.lua: "Send MC network to receivers" (transmission)

---

### scripts/receiver_combinator.lua

**OWNS:**
- Receiver entity lifecycle (build/remove)
- Receiver connection status checking
- Receiver-specific orbit detection logic
- Receiver configuration storage access
- Receiver status queries
- All logic specific to receiver combinators

**DOES NOT OWN:**
- Generic platform queries (that's lib/platform_utils)
- Signal transmission (that's scripts/network_manager)
- GUI creation (that's scripts/gui_handlers)
- Global registration (calls scripts/globals)

**Decision Criteria:**
- ✅ "Is this about what a receiver does?" → receiver_combinator.lua
- ✅ "Is this receiver-specific business logic?" → receiver_combinator.lua
- ❌ "Is this a generic platform query?" → lib/platform_utils
- ❌ "Is this about transmitting signals?" → scripts/network_manager

**Examples:**
```lua
-- ✅ BELONGS HERE
function on_receiver_built(entity, player)
function on_receiver_removed(entity)
function check_receiver_connection(unit_number)   -- Business logic using platform_utils
function get_receiver_status(unit_number)

-- ❌ DOES NOT BELONG
function is_platform_orbiting(platform_id, ...)   -- Generic → lib/platform_utils
function relay_to_platform(unit_number, signals)  -- Transmission → scripts/network_manager
function create_receiver_gui(player, entity)      -- GUI → scripts/gui_handlers
function register_receiver(entity)                 -- Registration → scripts/globals
```

**BOUNDARY WITH network_manager:**
- receiver_combinator.lua: "Is this receiver connected to planet X?" (status)
- network_manager.lua: "Send these signals through this receiver" (transmission)

---

### scripts/logistics_combinator.lua

**OWNS:**
- Logistics combinator lifecycle (build/remove)
- Rule processing and evaluation
- Connected entity cache management
- Rule state tracking (edge detection)
- Rule execution coordination
- All logic specific to logistics combinators

**DOES NOT OWN:**
- Actual logistics injection/removal (calls lib/logistics_utils)
- GUI creation (that's scripts/gui_handlers)
- Condition evaluation algorithm (that's lib/gui_utils)
- Global state storage (calls scripts/globals)

**Decision Criteria:**
- ✅ "Is this about how logistics combinators work?" → logistics_combinator.lua
- ✅ "Is this about when/why to inject groups?" → logistics_combinator.lua
- ❌ "Is this the low-level injection mechanism?" → lib/logistics_utils
- ❌ "Is this GUI event handling?" → scripts/gui_handlers

**Examples:**
```lua
-- ✅ BELONGS HERE
function on_logistics_combinator_built(entity, player)
function process_logistics_rules(unit_number)
function update_connected_entities(unit_number)
function rule_state_changed(rule, current_signals)

-- ❌ DOES NOT BELONG
function inject_logistics_group(entity, template)  -- Low-level → lib/logistics_utils
function create_logistics_gui(player, entity)      -- GUI → scripts/gui_handlers
function evaluate_condition(signals, condition)    -- Generic → lib/gui_utils
function register_logistics_combinator(entity)     -- Registration → scripts/globals
```

**CRITICAL PATTERN:**
```lua
-- This module decides WHEN:
if rule_state_changed(rule, signals) then
  -- This module decides WHAT:
  if rule.action == "inject" then
    -- But delegates HOW to lib:
    logistics_utils.inject_logistics_group(entity, template, combinator_id)
    -- Then updates state:
    globals.track_injected_group(...)
  end
end
```

---

### scripts/network_manager.lua

**OWNS:**
- Cross-surface signal transmission coordination
- Ground-to-space signal flow
- Space-to-ground signal flow
- Platform connection state updates
- Transmission timing (15-tick, 60-tick cycles)
- Finding receivers for surfaces
- Signal aggregation for transmission
- Platform arrival/departure handling

**DOES NOT OWN:**
- Entity-specific logic (that's entity scripts)
- Low-level circuit I/O (that's lib/circuit_utils)
- Platform queries (that's lib/platform_utils)
- Signal operations (that's lib/signal_utils)

**Decision Criteria:**
- ✅ "Is this about coordinating signals between surfaces?" → network_manager.lua
- ✅ "Is this about the transmission system as a whole?" → network_manager.lua
- ❌ "Is this about one entity type's behavior?" → entity script
- ❌ "Is this a generic utility?" → lib/

**Examples:**
```lua
-- ✅ BELONGS HERE
function update_transmissions()                    -- Main coordination
function process_ground_to_space(surface_index)
function process_space_to_ground(surface_index)
function update_platform_connections()
function find_receivers_for_surface(surface_index)

-- ❌ DOES NOT BELONG
function update_mc_network(surface_index)         -- MC-specific → scripts/mission_control
function check_receiver_connection(unit_number)   // Receiver-specific → scripts/receiver_combinator
function add_signals(target, source)              -- Generic → lib/signal_utils
```

**COORDINATION ROLE:**
This module orchestrates entity scripts. It calls:
- `mission_control.get_mc_aggregated_signals()`
- `receiver_combinator.check_receiver_connection()`
- Then performs transmission between them

---

### scripts/gui_handlers.lua

**OWNS:**
- Entity-specific GUI creation (receiver, logistics)
- GUI event routing and handling
- GUI state updates
- GUI open/close logic
- Player GUI cleanup
- All GUI event callbacks

**DOES NOT OWN:**
- Generic GUI elements (that's lib/gui_utils)
- GUI state storage (that's scripts/globals)
- Entity business logic (that's entity scripts)
- Condition evaluation (that's lib/gui_utils)

**Decision Criteria:**
- ✅ "Is this creating a specific entity's GUI?" → gui_handlers.lua
- ✅ "Is this handling a GUI event?" → gui_handlers.lua
- ❌ "Is this a reusable GUI component?" → lib/gui_utils
- ❌ "Is this storing GUI state?" → scripts/globals
- ❌ "Is this non-GUI entity logic?" → entity script

**Examples:**
```lua
-- ✅ BELONGS HERE
function create_receiver_gui(player, entity)
function on_gui_opened(event)
function on_receiver_surface_changed(event)
function on_logistics_add_rule(event)

-- ❌ DOES NOT BELONG
function create_titlebar(parent, title)           // Generic → lib/gui_utils
function evaluate_condition(signals, condition)   -- Generic → lib/gui_utils
function add_logistics_rule(unit_number, rule)    -- State → scripts/globals
function process_logistics_rules(unit_number)     -- Logic → scripts/logistics_combinator
```

**PATTERN:**
```lua
-- This module handles events:
function on_logistics_add_rule(event)
  local rule = build_rule_from_gui(event)
  -- Delegates to globals for storage:
  globals.add_logistics_rule(unit_number, rule)
  -- Delegates to entity script for immediate processing:
  logistics_combinator.process_logistics_rules(unit_number)
  -- Updates GUI:
  update_logistics_gui(player)
end
```

---

## PROTOTYPES Modules (Data Phase)

### prototypes/technology.lua

**OWNS:**
- Technology definitions only
- Tech prerequisites
- Tech costs
- Tech effects (recipe unlocks)

**DOES NOT OWN:**
- Items, entities, recipes (separate files)
- Control logic
- Anything runtime

---

### prototypes/entity/*.lua (one file per entity)

**OWNS:**
- Single entity prototype definition
- Entity properties (health, size, power, etc.)
- Graphics references
- Circuit connection points
- Entity-specific flags

**DOES NOT OWN:**
- Multiple entity types in one file
- Item definitions (that's item.lua)
- Recipe definitions (that's recipe.lua)
- Runtime logic

**FILE NAMING:**
- `mission_control.lua` - Mission Control building prototype
- `receiver_combinator.lua` - Receiver combinator prototype
- `logistics_combinator.lua` - Logistics combinator prototype

---

### prototypes/item.lua

**OWNS:**
- ALL item definitions for the mod
- Item properties (stack size, icons, etc.)

**DOES NOT OWN:**
- Entity definitions
- Recipe definitions

---

### prototypes/recipe.lua

**OWNS:**
- ALL recipe definitions for the mod
- Recipe ingredients and results
- Crafting times

**DOES NOT OWN:**
- Entity or item definitions

---

## Ambiguity Resolution Guide

### Q: Signal-related function - signal_utils or circuit_utils?
**A:** Does it touch entities/circuit networks?
- ✅ YES → `circuit_utils`
- ❌ NO (pure table operations) → `signal_utils`

### Q: Platform-related function - platform_utils or receiver_combinator?
**A:** Is it a generic platform query?
- ✅ YES (any code could use it) → `platform_utils`
- ❌ NO (receiver-specific logic) → `receiver_combinator`

### Q: Logistics function - logistics_utils or logistics_combinator?
**A:** Is it low-level section manipulation?
- ✅ YES (inject/remove/check) → `logistics_utils`
- ❌ NO (rules/decisions/timing) → `logistics_combinator`

### Q: GUI function - gui_utils or gui_handlers?
**A:** Is it reusable by multiple GUIs?
- ✅ YES (generic component) → `gui_utils`
- ❌ NO (entity-specific) → `gui_handlers`

### Q: State function - globals or entity script?
**A:** Is it just storing/retrieving?
- ✅ YES (data access) → `globals`
- ❌ NO (processing data) → entity script

### Q: Cross-entity function - where does it go?
**A:** Which entities does it coordinate?
- Multiple entity types → `network_manager`
- Single entity type behavior → that entity's script
- Generic operation → appropriate lib

### Q: Validation function - validation or entity script?
**A:** When does it run?
- At placement time → `validation`
- During runtime → entity script

---

## Function Placement Checklist

Before adding a new function, ask:

1. **Does it access global state?**
   - NO → Consider `lib/`
   - YES → Must be in `scripts/`

2. **Does it operate on entities?**
   - YES, generic operations → `lib/circuit_utils` or `lib/platform_utils`
   - YES, entity-specific → appropriate entity script
   - NO → Other criteria

3. **Does it coordinate multiple systems?**
   - YES → `scripts/network_manager` or `scripts/gui_handlers`
   - NO → Single-responsibility module

4. **Is it reusable?**
   - YES → `lib/`
   - NO → `scripts/`

5. **Is it about data structure or business logic?**
   - Data structure → `scripts/globals`
   - Business logic → entity script

---

## Examples of Correct Placement

### Example 1: Adding a new signal formatting function
```lua
-- QUESTION: Format signal for tooltip display - where does it go?

-- ANALYSIS:
-- - Does it access global? NO
-- - Does it operate on entities? NO
-- - Is it reusable? YES
-- - Pure computation? YES

-- ANSWER: lib/signal_utils.lua
function format_signal_tooltip(signal_id, count)
  return string.format("%s: %d", signal_id.name, count)
end
```

### Example 2: Adding platform travel time estimation
```lua
-- QUESTION: Estimate travel time between surfaces - where does it go?

-- ANALYSIS:
-- - Does it access global? NO
// - Does it operate on platforms? YES, generic query
-- - Is it reusable? YES
-- - Pure computation using platform API? YES

-- ANSWER: lib/platform_utils.lua
function estimate_travel_time(platform, target_surface)
  -- Uses platform.space_location API
end
```

### Example 3: Adding rule priority system
```lua
-- QUESTION: Process rules in priority order - where does it go?

-- ANALYSIS:
-- - Does it access global? YES (reads rules)
-- - Specific to logistics combinator? YES
-- - Business logic? YES

-- ANSWER: scripts/logistics_combinator.lua
function process_rules_by_priority(unit_number)
  local data = globals.get_logistics_combinator_data(unit_number)
  -- Sort and process rules
end
```

### Example 4: Adding "Export Configuration" button
```lua
-- QUESTION: GUI button to export config to string - where does it go?

-- ANALYSIS:
-- - Is it a reusable GUI component? NO (specific to one entity)
-- - Is it event handling? YES
-- - Is it entity-specific? YES (logistics combinator)

-- ANSWER: scripts/gui_handlers.lua
function on_logistics_export_config(event)
  local config = build_config_from_combinator(...)
  -- Show export dialog
end
```

---

## Anti-Patterns to Avoid

### ❌ WRONG: Accessing global directly from lib/
```lua
-- lib/circuit_utils.lua
function get_all_mc_signals()
  for surface_index, network in pairs(global.mc_networks) do  -- NO!
    -- ...
  end
end
```
**WHY:** lib/ modules must be pure, no global access

**FIX:** Move to scripts/ or pass data as parameter

---

### ❌ WRONG: Entity-specific logic in generic util
```lua
-- lib/signal_utils.lua
function get_mission_control_signals(entity)  -- NO!
  -- This is entity-specific
end
```
**WHY:** signal_utils is for generic signal operations

**FIX:** Move to scripts/mission_control.lua

---

### ❌ WRONG: Business logic in globals
```lua
-- scripts/globals.lua
function register_mc_building(entity)
  -- ... registration ...
  update_mc_network(entity.surface.index)  -- NO! This is business logic
end
```
**WHY:** globals is for data access only, not processing

**FIX:** Caller handles registration AND update separately

---

### ❌ WRONG: Storing state in lib/
```lua
-- lib/platform_utils.lua
local platform_cache = {}  -- NO! State storage
```
**WHY:** lib/ modules must be stateless

**FIX:** Pass data as parameters or use scripts/globals

---

### ❌ WRONG: Low-level operations in high-level module
```lua
-- scripts/logistics_combinator.lua
function inject_group_directly(entity, template)
  local section = entity.logistic_sections.add_section(template)  -- NO!
  -- This is low-level, belongs in logistics_utils
end
```
**WHY:** Violates separation of concerns

**FIX:** Call lib/logistics_utils.inject_logistics_group()

---

## Module Dependency Graph

```
ALLOWED DEPENDENCIES:

control.lua
  ├─> scripts/globals
  ├─> scripts/mission_control
  ├─> scripts/receiver_combinator
  ├─> scripts/logistics_combinator
  ├─> scripts/network_manager
  └─> scripts/gui_handlers

scripts/* (any script module)
  ├─> lib/* (any lib module)
  ├─> scripts/globals (only for state access)
  └─> other scripts/* (for coordination only)

lib/* (any lib module)
  ├─> other lib/* (sparingly)
  └─> NEVER scripts/* or global

prototypes/*
  └─> NEVER lib/* or scripts/*
```

**FORBIDDEN:**
- lib/ → scripts/ (would create coupling)
- lib/ → global (would break purity)
- prototypes/ → control phase (different loading phases)
- Circular dependencies between scripts/

---

## Summary Decision Tree

```
New function to add?
│
├─ Does it access global?
│  ├─ YES → scripts/
│  └─ NO → Could be lib/, continue...
│
├─ Does it perform I/O (entities, circuit networks)?
│  ├─ YES, generic → lib/circuit_utils or lib/platform_utils
│  ├─ YES, entity-specific → scripts/<entity_type>
│  └─ NO → continue...
│
├─ Is it pure computation?
│  ├─ YES, signals → lib/signal_utils
│  ├─ YES, other → lib/gui_utils or new lib/ if needed
│  └─ NO → continue...
│
├─ Is it business logic?
│  ├─ YES, single entity → scripts/<entity_type>
│  ├─ YES, coordination → scripts/network_manager or scripts/gui_handlers
│  └─ NO → continue...
│
└─ Is it data structure management?
   ├─ YES → scripts/globals
   └─ NO → Re-evaluate or ask for guidance
```

---

## When to Create a NEW Module

Create a new lib/ module when:
1. You have 5+ related pure functions
2. They form a cohesive domain concept
3. They're reusable across multiple entity types
4. Existing modules would exceed 750 lines

Create a new scripts/ module when:
1. A new entity type is added
2. An existing module exceeds 750 lines
3. A distinct coordination responsibility emerges

**DO NOT create modules for:**
- Single functions (add to existing module)
- Temporary utilities (refactor later)
- Entity variations (extend existing entity module)

---

## Enforcement

**Code Review Checklist:**
- [ ] Function is in correct module per decision tree
- [ ] lib/ functions don't access global
- [ ] scripts/ functions use lib/ for generic operations
- [ ] No circular dependencies
- [ ] Module stays under 750 lines
- [ ] Function documented with module rationale

**Naming Convention:**
- Module name clearly indicates responsibility
- Function names indicate domain (e.g., `signal_*`, `platform_*`)
- No generic names like `utils.lua` or `helpers.lua`

---

**This document is the SINGLE SOURCE OF TRUTH for code organization. When in doubt, consult this guide. If this guide doesn't cover your case, update this document FIRST, then write code.**

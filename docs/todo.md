# Mission Control Mod - Development TODO

## Project Status: Phase 0 - Planning Complete ✓

---

## Phase 0: Project Setup & Planning ✓
- [x] Review spec.md and requirements
- [x] Review implementation_hints.md
- [x] Create todo.md (this file)
- [x] Plan shared library structure
- [x] Plan target file organization
- [x] Create module_responsibility_matrix.md (defines module boundaries)

---

## Phase 1: Foundation & Shared Libraries
**Goal:** Create all utility libraries and base infrastructure before entity implementation

### 1.1 Core Directory Structure
- [ ] Create `mod/lib/` directory for shared utilities
- [ ] Create `mod/scripts/` directory for entity logic
- [ ] Create `mod/prototypes/entity/` directory
- [ ] Create `mod/locale/en/` directory
- [ ] Create placeholder `mod/graphics/` directories (icons, technology, entity)

### 1.2 Shared Utility Libraries (`mod/lib/`)
- [ ] **`signal_utils.lua`** - Signal manipulation functions
  - [ ] `add_signals(target, source)` - Sum signals into target table
  - [ ] `merge_signals(red_signals, green_signals)` - Merge for condition evaluation
  - [ ] `signals_equal(a, b)` - Compare signal tables
  - [ ] `copy_signals(source)` - Deep copy signal table
  - [ ] `clear_signals(table)` - Reset signal table
  - [ ] Unit tests in comments

- [ ] **`circuit_utils.lua`** - Circuit network interaction
  - [ ] `get_circuit_signals(entity, wire_type, connector_id)` - Read signals from entity
  - [ ] `set_circuit_signals(entity, wire_type, signals)` - Write signals to entity
  - [ ] `get_merged_input_signals(entity)` - Get combined red+green inputs
  - [ ] `has_circuit_connection(entity, wire_type)` - Check if wired
  - [ ] Handle invalid entities gracefully
  - [ ] Unit tests in comments

- [ ] **`platform_utils.lua`** - Platform detection and orbit logic
  - [ ] `is_platform_surface(surface)` - Check if surface is a platform
  - [ ] `get_platform_for_surface(surface)` - Get platform object from surface
  - [ ] `is_platform_orbiting(platform_id, surface_index)` - Check orbit status
  - [ ] `is_platform_stationary(platform)` - Check if not traveling
  - [ ] `get_orbited_surface(platform)` - Get surface being orbited
  - [ ] `find_all_platforms()` - Enumerate all platforms
  - [ ] Unit tests in comments

- [ ] **`validation.lua`** - Entity placement validation
  - [ ] `validate_mission_control_placement(entity)` - Planet-only check
  - [ ] `validate_receiver_placement(entity)` - Platform-only check
  - [ ] `refund_entity(entity, player)` - Return items and destroy
  - [ ] `show_placement_error(player, message, position)` - User feedback
  - [ ] Handle robot placement (no player)
  - [ ] Unit tests in comments

- [ ] **`logistics_utils.lua`** - Logistics group management
  - [ ] `find_logistics_entities_on_network(circuit_network)` - Find controllable entities
  - [ ] `has_logistics_group(entity, group_name)` - Check if group exists
  - [ ] `inject_logistics_group(entity, group_template)` - Add new group
  - [ ] `remove_logistics_group(entity, group_name)` - Remove specific group
  - [ ] `get_logistics_group_template(group_name)` - Retrieve group definition
  - [ ] `track_injected_group(entity_id, group_id, combinator_id)` - Record injection
  - [ ] `cleanup_injected_groups(entity_id)` - Remove all tracked groups
  - [ ] Unit tests in comments

- [ ] **`gui_utils.lua`** - Common GUI helpers
  - [ ] `create_titlebar(parent, title, close_button_name)` - Standard titlebar
  - [ ] `create_button_row(parent, buttons)` - Row of buttons
  - [ ] `close_gui_for_player(player, gui_name)` - Safe GUI destruction
  - [ ] `center_gui(gui_element)` - Center on screen
  - [ ] `create_condition_selector(parent)` - Condition builder UI
  - [ ] Unit tests in comments

### 1.3 Global State Management (`mod/scripts/globals.lua`)
- [ ] Create `globals.lua` - Global state initialization and access
  - [ ] `init_globals()` - Initialize all global tables
  - [ ] `get_mc_network(surface_index)` - Get or create MC network state
  - [ ] `register_mc_building(entity)` - Add MC to network
  - [ ] `unregister_mc_building(entity)` - Remove MC from network
  - [ ] `register_receiver(entity)` - Add receiver to tracking
  - [ ] `unregister_receiver(entity)` - Remove receiver
  - [ ] `register_logistics_combinator(entity)` - Add logistics combinator
  - [ ] `unregister_logistics_combinator(entity)` - Remove logistics combinator
  - [ ] Proper cleanup on entity removal
  - [ ] Migration support functions

### 1.4 Locale Strings (`mod/locale/en/mission-control.cfg`)
- [ ] Entity names and descriptions
- [ ] Technology names and descriptions
- [ ] GUI labels and tooltips
- [ ] Error messages
- [ ] Status messages

---

## Phase 2: Data Phase - Prototypes
**Goal:** Define all items, recipes, technologies, and entity prototypes

### 2.1 Technology Definitions (`mod/prototypes/technology.lua`)
- [ ] Mission Control technology
  - [ ] Icon reference (placeholder)
  - [ ] Prerequisites: space-platform, radar, advanced-electronics-2
  - [ ] Science pack costs: 1000x all (auto, logistic, chemical, production, utility, space)
  - [ ] Unlocks: mission-control-building, receiver-combinator recipes
- [ ] Logistics Circuit Control technology
  - [ ] Icon reference (placeholder)
  - [ ] Prerequisites: logistic-system
  - [ ] Science pack costs: 500x (auto, logistic, chemical, utility)
  - [ ] Unlocks: logistics-combinator recipe

### 2.2 Entity Prototypes
- [ ] **Mission Control Building** (`mod/prototypes/entity/mission_control.lua`)
  - [ ] Base type: "radar" (to inherit radar behavior but disable exploration)
  - [ ] Size: 5x5, collision/selection boxes
  - [ ] Health: 250 (scales with quality)
  - [ ] Power: 300kW constant
  - [ ] Circuit connections: 4 terminals (red_in, green_in, red_out, green_out)
  - [ ] Graphics: Copy radar sprites as placeholder
  - [ ] Max exploration distance: 0 (disable radar functionality)
  - [ ] Fast replaceable group
  - [ ] Minable properties

- [ ] **Receiver Combinator** (`mod/prototypes/entity/receiver_combinator.lua`)
  - [ ] Base type: "arithmetic-combinator"
  - [ ] Size: 1x1, collision/selection boxes
  - [ ] Health: 150 (scales with quality)
  - [ ] Power: 50kW (quality scaling: uncommon 40kW, rare 30kW, epic 15kW, legendary 5kW)
  - [ ] Circuit connections: 4 terminals
  - [ ] Graphics: Copy arithmetic combinator as placeholder
  - [ ] Custom GUI opening behavior
  - [ ] Fast replaceable group
  - [ ] Minable properties

- [ ] **Logistics Combinator** (`mod/prototypes/entity/logistics_combinator.lua`)
  - [ ] Base type: "decider-combinator"
  - [ ] Size: 2x1, collision/selection boxes
  - [ ] Health: 150 (scales with quality)
  - [ ] Power: 1kW
  - [ ] Circuit connections: 3 terminals (red_in, green_in, output)
  - [ ] Graphics: Copy decider combinator with tint
  - [ ] LED indicators for active rules
  - [ ] Custom GUI opening behavior
  - [ ] Fast replaceable group
  - [ ] Minable properties

### 2.3 Item Definitions (`mod/prototypes/item.lua`)
- [ ] Mission Control Building item
  - [ ] Icon reference, stack size: 10, rocket capacity: 1
  - [ ] Subgroup: circuit-network, order: d[other]-b[mission-control]
- [ ] Receiver Combinator item
  - [ ] Icon reference, stack size: 50, rocket capacity: 50
  - [ ] Subgroup: circuit-network, order: d[other]-c[receiver-combinator]
- [ ] Logistics Combinator item
  - [ ] Icon reference, stack size: 50, rocket capacity: 50
  - [ ] Subgroup: circuit-network, order: d[other]-d[logistics-combinator]

### 2.4 Recipe Definitions (`mod/prototypes/recipe.lua`)
- [ ] Mission Control Building recipe
  - [ ] Ingredients: 5 radar + 100 processing units
  - [ ] Crafting time: 30s, enabled: false
- [ ] Receiver Combinator recipe
  - [ ] Ingredients: 10 advanced circuits + 5 radar + 1 arithmetic combinator
  - [ ] Crafting time: 10s, enabled: false
- [ ] Logistics Combinator recipe
  - [ ] Ingredients: 5 electronic circuits + 1 decider combinator + 1 constant combinator
  - [ ] Crafting time: 5s, enabled: false

### 2.5 Data Loading (`mod/data.lua`)
- [ ] Require all prototype files in correct order
- [ ] Ensure dependencies loaded properly
- [ ] Test loading with --check-unused-prototype-data

---

## Phase 3: Mission Control Building Implementation
**Goal:** Planet-side communication hub that aggregates and broadcasts signals

### 3.1 Core Logic (`mod/scripts/mission_control.lua`)
- [ ] **Entity lifecycle**
  - [ ] `on_mc_built(entity)` - Register in global.mc_networks
  - [ ] `on_mc_removed(entity)` - Cleanup from network
  - [ ] Validate planet-only placement

- [ ] **Signal aggregation**
  - [ ] `update_mc_network(surface_index)` - Sum all MC inputs on surface
  - [ ] Separate red and green signal processing
  - [ ] Use signal_utils for aggregation

- [ ] **Signal broadcasting**
  - [ ] `broadcast_to_platforms(surface_index, red_signals, green_signals)` - Send to receivers
  - [ ] Find all orbiting platforms configured for this surface
  - [ ] Write signals to receiver output terminals

- [ ] **Receive from platforms**
  - [ ] `receive_from_platforms(surface_index)` - Aggregate platform signals
  - [ ] Sum signals from all receivers on orbiting platforms
  - [ ] Output summed signals to all MC buildings on surface

- [ ] **Update cycle**
  - [ ] Integrate with network_manager update_transmissions()
  - [ ] 15-tick update interval
  - [ ] Performance: batch process per surface

### 3.2 Testing
- [ ] Single MC building sends/receives correctly
- [ ] Multiple MCs on same surface aggregate properly
- [ ] Red/green wire separation maintained
- [ ] Removal cleanup works
- [ ] Save/load preserves state

---

## Phase 4: Receiver Combinator Implementation
**Goal:** Platform-side bidirectional signal relay with orbit detection

### 4.1 Core Logic (`mod/scripts/receiver_combinator.lua`)
- [ ] **Entity lifecycle**
  - [ ] `on_receiver_built(entity)` - Register in global.platform_receivers
  - [ ] `on_receiver_removed(entity)` - Cleanup from tracking
  - [ ] Validate platform-only placement
  - [ ] Auto-open GUI on placement

- [ ] **Orbit detection**
  - [ ] `check_receiver_connection(receiver_id)` - Update connection status
  - [ ] Check if platform is orbiting configured surface
  - [ ] Check if platform is stationary (speed == 0)
  - [ ] Update connection state in global

- [ ] **Signal relay**
  - [ ] `relay_to_platform(receiver_entity, red_signals, green_signals)` - Output to platform
  - [ ] `relay_from_platform(receiver_entity)` - Read platform signals, send to ground
  - [ ] Only active when orbiting AND stationary
  - [ ] Preserve red/green separation

- [ ] **Configuration storage**
  - [ ] Store configured surface indices per receiver
  - [ ] Persist across save/load
  - [ ] Apply changes immediately

### 4.2 GUI Implementation (`mod/scripts/gui_handlers.lua` - Receiver section)
- [ ] **Surface Configuration GUI**
  - [ ] Create GUI on entity opened
  - [ ] Title: "Surface Communication Settings"
  - [ ] Multi-select checkboxes for all discovered planets
  - [ ] "Select All" / "Clear All" buttons
  - [ ] Connection status display
  - [ ] Only show planets (not space surfaces)
  - [ ] Disable when platform in transit

- [ ] **GUI Events**
  - [ ] on_gui_opened - Create receiver GUI
  - [ ] on_gui_closed - Save and destroy GUI
  - [ ] on_gui_checked_changed - Update configured surfaces
  - [ ] on_gui_click - Handle Select All/Clear All buttons

### 4.3 Testing
- [ ] Platform-only placement enforced
- [ ] GUI shows all planets correctly
- [ ] Connection only active when orbiting + stationary
- [ ] Signals relay bidirectionally
- [ ] Configuration persists across save/load
- [ ] Multiple receivers on same platform work independently

---

## Phase 5: Signal Transmission System
**Goal:** Cross-surface signal passing with proper aggregation

### 5.1 Network Manager (`mod/scripts/network_manager.lua`)
- [ ] **Main update cycle**
  - [ ] `update_transmissions()` - Called every 15 ticks
  - [ ] Process all MC networks
  - [ ] Update all receiver connections
  - [ ] Coordinate signal flow

- [ ] **Ground-to-space flow**
  - [ ] For each planet surface with MCs:
    - [ ] Aggregate all MC red inputs → sum
    - [ ] Aggregate all MC green inputs → sum
    - [ ] Find all platforms orbiting this surface
    - [ ] Send summed signals to connected receivers

- [ ] **Space-to-ground flow**
  - [ ] For each platform with receivers:
    - [ ] Check if receiver connected to planet
    - [ ] Read receiver's input signals
    - [ ] Send to planet's MC network for aggregation
  - [ ] For each planet MC network:
    - [ ] Sum all incoming platform signals
    - [ ] Output to all MCs on that surface

- [ ] **Transmission delay**
  - [ ] Implement 15-tick delay using signal queue (optional)
  - [ ] OR implement instant transmission for simplicity
  - [ ] Document choice in code

### 5.2 Platform Connection Management
- [ ] **Orbit tracking** (`update_platform_connections()` - every 60 ticks)
  - [ ] Enumerate all receivers
  - [ ] Check platform orbit status
  - [ ] Update connection state
  - [ ] Handle platform arrival/departure

- [ ] **Connection state**
  - [ ] Track last_connected_surface per receiver
  - [ ] Detect connection state changes
  - [ ] Clear signals when disconnecting

### 5.3 Testing
- [ ] Single MC to single receiver works
- [ ] Multiple MCs aggregate before sending
- [ ] Multiple platforms aggregate when sending to ground
- [ ] Platform travel disconnects/reconnects properly
- [ ] Red/green separation maintained end-to-end
- [ ] Performance acceptable with 10+ MCs, 5+ platforms

---

## Phase 6: Logistics Combinator Implementation
**Goal:** Circuit-controlled logistics group injection/removal

### 6.1 Core Logic (`mod/scripts/logistics_combinator.lua`)
- [ ] **Entity lifecycle**
  - [ ] `on_logistics_combinator_built(entity)` - Register in global
  - [ ] `on_logistics_combinator_removed(entity)` - Cleanup injected groups
  - [ ] Initialize rule storage
  - [ ] Open GUI on placement

- [ ] **Connected entity detection**
  - [ ] `find_connected_logistics_entities(combinator)` - Scan output network
  - [ ] Cache connected entity list
  - [ ] Update cache on wire add/remove events
  - [ ] Filter for entities with logistic_sections property

- [ ] **Rule processing** (`process_logistics_rules()`)
  - [ ] Read input signals (red + green merged)
  - [ ] Evaluate each rule condition
  - [ ] Edge-triggered: only act on state changes
  - [ ] For each connected entity:
    - [ ] If inject + condition met: inject group if not present
    - [ ] If remove + condition met: remove group if present
  - [ ] Track rule states (last_condition_value)

- [ ] **Group management**
  - [ ] Use logistics_utils for injection/removal
  - [ ] Tag injected groups with combinator unit_number
  - [ ] Track all injections in global.injected_groups
  - [ ] Never modify existing user-created groups

- [ ] **Cleanup on removal**
  - [ ] Remove all groups injected by this combinator
  - [ ] Clear from global tracking
  - [ ] Handle invalid entity references gracefully

### 6.2 GUI Implementation (`mod/scripts/gui_handlers.lua` - Logistics section)
- [ ] **Main GUI**
  - [ ] Title: "Logistics Combinator"
  - [ ] "Add Controlled Group" button
  - [ ] List of active rules
  - [ ] Connected entities count display

- [ ] **Rule configuration**
  - [ ] Group selector: choose-elem-button with elem_type = "logistic-groups"
  - [ ] Condition builder:
    - [ ] Signal picker (choose-elem-button, elem_type = "signal")
    - [ ] Operator dropdown (<, >, =, ≠, ≤, ≥)
    - [ ] Value textfield or signal picker
  - [ ] Action radio buttons: Inject / Remove
  - [ ] Delete rule button

- [ ] **Rule display**
  - [ ] Show each rule with status indicator (✓ active / ○ inactive)
  - [ ] Human-readable format: "Inject 'Fuel Request' when Coal < 100"
  - [ ] Edit button (opens rule editor)
  - [ ] Delete button (removes rule)

- [ ] **GUI Events**
  - [ ] on_gui_opened - Create logistics GUI
  - [ ] on_gui_closed - Save and destroy GUI
  - [ ] on_gui_click - Add/delete rules, change actions
  - [ ] on_gui_elem_changed - Update group/signal selections
  - [ ] on_gui_text_changed - Update condition values

### 6.3 Condition Evaluation
- [ ] `evaluate_condition(signals, condition)` - Check if condition met
  - [ ] Support operators: <, >, =, ≠, ≤, ≥
  - [ ] Handle missing signals (treat as 0)
  - [ ] Handle signal-to-signal comparison
  - [ ] Handle constant value comparison

### 6.4 Testing
- [ ] Single rule injects group correctly
- [ ] Multiple rules on same combinator work independently
- [ ] Edge triggering prevents repeated injection
- [ ] Removal only affects injected groups
- [ ] Multiple entities controlled by one combinator
- [ ] Wire disconnection stops control
- [ ] Combinator removal cleans up all injected groups
- [ ] Save/load preserves rules and state

---

## Phase 7: Control Script Integration
**Goal:** Wire everything together in control.lua

### 7.1 Main Control File (`mod/control.lua`)
- [ ] **Imports**
  - [ ] Require all lib files
  - [ ] Require all script files
  - [ ] Require globals.lua

- [ ] **Initialization**
  - [ ] on_init: call init_globals()
  - [ ] on_configuration_changed: call init_globals() + migration
  - [ ] on_load: restore any runtime state

- [ ] **Entity lifecycle events**
  - [ ] on_built_entity: dispatch to appropriate handler
  - [ ] on_robot_built_entity: dispatch to appropriate handler
  - [ ] script_raised_built: dispatch to appropriate handler
  - [ ] on_player_mined_entity: dispatch to appropriate handler
  - [ ] on_robot_mined_entity: dispatch to appropriate handler
  - [ ] on_entity_died: dispatch to appropriate handler
  - [ ] script_raised_destroy: dispatch to appropriate handler

- [ ] **Platform events**
  - [ ] on_space_platform_built: initialize platform tracking
  - [ ] on_space_platform_destroyed: cleanup platform receivers

- [ ] **Circuit events**
  - [ ] on_wire_added: update connected entity caches
  - [ ] on_wire_removed: update connected entity caches

- [ ] **GUI events**
  - [ ] on_gui_opened: dispatch to appropriate GUI handler
  - [ ] on_gui_closed: dispatch to appropriate GUI handler
  - [ ] on_gui_click: dispatch to appropriate GUI handler
  - [ ] on_gui_checked_changed: dispatch to appropriate GUI handler
  - [ ] on_gui_elem_changed: dispatch to appropriate GUI handler
  - [ ] on_gui_text_changed: dispatch to appropriate GUI handler

- [ ] **Periodic updates**
  - [ ] on_nth_tick(15): call update_transmissions()
  - [ ] on_nth_tick(60): call update_platform_connections()

- [ ] **Remote interface** (optional)
  - [ ] Expose API for debugging/integration

### 7.2 Event Dispatcher
- [ ] Create centralized event dispatcher
- [ ] Route events to appropriate entity handlers
- [ ] Handle multiple entity types in single event
- [ ] Proper error handling and logging

---

## Phase 8: Polish & Optimization

### 8.1 Performance Optimization
- [ ] Profile with large bases (50+ MCs, 20+ platforms)
- [ ] Optimize signal aggregation algorithm
- [ ] Cache entity lookups
- [ ] Minimize table allocations
- [ ] Batch process where possible
- [ ] Consider using sparse update cycles for idle entities

### 8.2 Visual Feedback
- [ ] LED indicators on entities showing activity
- [ ] Rich text tooltips showing connection status
- [ ] Flying text for placement errors
- [ ] Circuit network color coding consistency
- [ ] GUI status messages

### 8.3 Edge Cases
- [ ] Entity destroyed during signal transmission
- [ ] Platform undocking mid-transmission
- [ ] Rapid wire connection/disconnection
- [ ] Save during transmission
- [ ] Quality upgrades on existing entities
- [ ] Multiplayer sync edge cases
- [ ] Mod incompatibility detection

### 8.4 User Experience
- [ ] Clear tooltips explaining mechanics
- [ ] GUI keyboard shortcuts
- [ ] Blueprint support verification
- [ ] Copy/paste settings preservation
- [ ] Undo support (vanilla handles this)
- [ ] Fast replace functionality

---

## Phase 9: Documentation & Release Prep

### 9.1 In-Game Documentation
- [ ] Comprehensive entity descriptions
- [ ] Technology descriptions
- [ ] Tutorial hints (optional)
- [ ] Example configurations in description

### 9.2 External Documentation
- [ ] README.md with mod overview
- [ ] Usage guide with examples
- [ ] Technical documentation for modders
- [ ] Changelog.txt

### 9.3 Graphics Assets
- [ ] Commission or create custom sprites (deferred to later)
- [ ] Create technology icons
- [ ] Create entity icons
- [ ] Create entity sprites (base, shadow, overlay)
- [ ] Create GUI graphics if needed

### 9.4 Testing & QA
- [ ] Full playthrough from early to late game
- [ ] Multiplayer testing
- [ ] Mod compatibility testing (major mods)
- [ ] Performance testing with large saves
- [ ] Load existing saves (migration testing)

### 9.5 Release
- [ ] Version 0.1.0 alpha release
- [ ] Gather community feedback
- [ ] Address critical bugs
- [ ] Version 0.2.0 beta release
- [ ] Final polish
- [ ] Version 1.0.0 release

---

## Feature Tracking Files

### Detailed Feature Todos (To be created as needed)
- `docs/mission_control_todo.md` - Detailed MC building implementation
- `docs/receiver_combinator_todo.md` - Detailed receiver implementation
- `docs/logistics_combinator_todo.md` - Detailed logistics combinator implementation
- `docs/signal_transmission_todo.md` - Detailed transmission system
- `docs/gui_system_todo.md` - Detailed GUI implementation

---

## Development Guidelines

### Module Responsibilities (CRITICAL - READ FIRST!)
**📖 Before writing ANY code, consult `docs/module_responsibility_matrix.md`**

This document defines:
- What each module OWNS and DOESN'T OWN
- Decision criteria for where new functions belong
- Examples of correct/incorrect placement
- Anti-patterns to avoid
- Dependency rules

**When adding a new function, use the decision tree in the matrix to determine correct placement.**

### Code Organization
- Keep individual .lua files under 750-900 lines
- Break large modules into sub-modules
- Use meaningful function and variable names
- Document all functions with inline comments
- Group related functions together

### Performance
- Prefer on_nth_tick over on_tick
- Cache expensive lookups
- Minimize global table traversals
- Use local variables for frequently accessed data
- Profile before optimizing

### Testing Strategy
- Test each phase independently before moving to next
- Create test scenarios in new game
- Test with existing saves
- Test multiplayer scenarios
- Test mod compatibility

### Version Control
- Commit after each completed phase
- Write descriptive commit messages
- Tag releases with version numbers
- Maintain changelog

---

## Current Focus: Phase 1 - Foundation & Shared Libraries
**Next Steps:**
1. Create directory structure under mod/
2. Implement signal_utils.lua
3. Implement circuit_utils.lua
4. Implement platform_utils.lua
5. Implement validation.lua
6. Implement logistics_utils.lua
7. Implement gui_utils.lua
8. Create globals.lua for state management
9. Write locale strings

**Estimated Time:** 2-3 days for complete Phase 1

---

## Notes
- Graphics are placeholders using tinted vanilla sprites initially
- Focus on functionality first, polish later
- Follow Factorio modding best practices
- Refer to spec.md for detailed requirements
- Refer to implementation_hints.md for code examples
- Keep CLAUDE.md updated with any process changes

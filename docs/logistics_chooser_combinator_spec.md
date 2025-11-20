# Logistics Chooser Combinator - Specification

## Vision Statement

The Logistics Chooser Combinator is a simplified alternative to the Logistics Combinator, designed for straightforward threshold-based logistics automation. Where the Logistics Combinator excels at complex boolean logic with AND/OR conditions, the Chooser Combinator provides a clean, intuitive interface for simple "IF signal THEN inject/remove group" rules. It's designed for general players who want powerful logistics automation without the complexity of multi-condition expressions.

Think of it as a **switch/case statement** or **priority list** for logistics groups - each row represents one clear condition leading to one clear action.

---

## Core Concept

### Design Philosophy

1. **One Condition Per Rule**: Each rule has exactly one signal comparison (no AND/OR logic)
2. **Visual Priority**: Rules can be reordered via drag handles for explicit priority
3. **Immediate Feedback**: Per-row LED indicators show which rules are active
4. **Flexible Evaluation**: Choose between "all matching" or "first match only" modes
5. **Familiar Interface**: Follows vanilla Factorio combinator design patterns

### When to Use This vs Logistics Combinator

| Use Logistics Chooser When | Use Logistics Combinator When |
|---------------------------|-------------------------------|
| Simple threshold monitoring | Complex multi-condition logic needed |
| Progressive state changes (low/critical/emergency) | Boolean expressions required |
| Priority-based rule selection | AND/OR combinations necessary |
| Quick setup and clear visualization | Advanced circuit network integration |
| Single-signal decision making | Multiple signals must be evaluated together |

---

## Entity Specifications

### Basic Properties

```lua
-- Entity prototype
type = "decider-combinator"
name = "logistics-chooser-combinator"
size = "2x1"  -- Same as logistics combinator
collision_box = {{-0.9, -0.4}, {0.9, 0.4}}
selection_box = {{-1.0, -0.5}, {1.0, 0.5}}

-- Stats
health = 150  -- Same as logistics combinator, scales with quality
max_health = 150

-- Power
energy_usage = "1kW"  -- Same as logistics combinator
energy_source = {
  type = "electric",
  usage_priority = "secondary-input"
}

-- Circuit connections
circuit_wire_max_distance = 9
circuit_connector_sprites = {
  -- 4 connection points (red_in, green_in, red_out, green_out)
}

-- Flags
flags = {"placeable-neutral", "player-creation"}
minable = {mining_time = 0.2, result = "logistics-chooser-combinator"}
fast_replaceable_group = "combinators"
```

### Recipe

```lua
{
  type = "recipe",
  name = "logistics-chooser-combinator",
  enabled = false,
  ingredients = {
    {"electronic-circuit", 5},
    {"decider-combinator", 1},
    {"constant-combinator", 1}
  },
  result = "logistics-chooser-combinator"
}
```

**Reasoning**: Same as logistics combinator recipe to maintain parity.

### Technology Unlock

Unlocked by the existing `logistics-circuit-control` technology (same as Logistics Combinator).

### Graphics

- **Icon**: Combinator with logistics chest icon overlay and numbered list indicator
- **Entity Sprite**: Based on decider combinator with distinct color tint (suggest blue-green)
- **LED Indicators**: Displayed in GUI, not on entity sprite
- **Stack Size**: 50
- **Rocket Capacity**: 50

---

## GUI Design

### Complete Layout

```
[Logistics Chooser Combinator]
┌──────────────────────────────────────────────────────────┐
│ Logistics Group Rules                                    │
├──────────────────────────────────────────────────────────┤
│ [+] Add Rule                                             │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ ●  ↑↓  When [Iron Plate ▼] [< ▼] [100]            │  │
│ │        Then ◉ Inject ○ Remove  [Low Iron Suppl. ▼]│  │
│ │                                          [×] Delete│  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ ●  ↑↓  When [Coal ▼] [< ▼] [50]                   │  │
│ │        Then ◉ Inject ○ Remove  [Low Coal Group ▼] │  │
│ │                                          [×] Delete│  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ ○  ↑↓  When [Rocket Fuel ▼] [= ▼] [0]             │  │
│ │        Then ◉ Inject ○ Remove  [Emergency Fuel ▼] │  │
│ │                                          [×] Delete│  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ ●  ↑↓  When [Space-science-pack ▼] [> ▼] [1000]   │  │
│ │        Then ○ Inject ◉ Remove  [Science Packs ▼]  │  │
│ │                                          [×] Delete│  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ Connected Entities: 4                                    │
│ Evaluation Mode: ◉ All matching  ○ First match only     │
└──────────────────────────────────────────────────────────┘

Legend:
● = Green LED (rule active - condition true, action executing)
○ = Dark/off LED (rule inactive - condition false)
```

### GUI Elements

#### Rule Row Components

| Element | Type | Description |
|---------|------|-------------|
| **● / ○** | Indicator LED | Green when rule active, dark when inactive |
| **↑↓** | Drag handle | Reorder rules (changes evaluation priority) |
| **When** | Label | Condition prefix |
| **[Signal ▼]** | `choose-elem-button` | Signal picker (elem_type = "signal") |
| **[Operator ▼]** | Dropdown | Operators: `<`, `>`, `=`, `≠`, `≤`, `≥` |
| **[Value]** | Textfield or signal picker | Constant value or signal comparison |
| **Then** | Label | Action prefix |
| **◉ Inject / ○ Remove** | Radio buttons | Action type selection |
| **[Group ▼]** | `choose-elem-button` | Logistics group picker (elem_type = "logistic-groups") |
| **[×] Delete** | Button | Remove this rule |

#### Global Controls

| Element | Type | Description |
|---------|------|-------------|
| **[+] Add Rule** | Button | Append new rule at bottom of list |
| **Connected Entities: N** | Label | Count of logistics-enabled entities on output network |
| **Evaluation Mode** | Radio buttons | Toggle between "All matching" and "First match only" |

### LED Indicator Behavior

**LED States:**

- **● Green/Lit**:
  - Condition evaluates to TRUE, AND
  - For "Inject" rules: Group is currently injected
  - For "Remove" rules: Group was removed (or already absent)

- **○ Dark/Off**:
  - Condition evaluates to FALSE (no action taken)

**Update Frequency**: Every 15 ticks (matches rule evaluation cycle)

**Visual Design**: Small circular LED on far left of each rule row for easy scanning

---

## Operation Logic

### Rule Structure

Each rule is stored with the following data:

```lua
-- Global storage per combinator
storage.chooser_combinators[unit_number] = {
  rules = {
    {
      -- Rule identification
      rule_id = 1,  -- Unique within this combinator

      -- Condition
      signal = {type = "item", name = "iron-plate"},
      operator = "<",  -- One of: "<", ">", "=", "≠", "≤", "≥"
      value = 100,     -- Can be constant or signal reference

      -- Action
      action = "inject",  -- "inject" or "remove"
      group_name = "Low Iron Supplies",
      group_template = {...},  -- Cached logistics group definition

      -- State tracking
      last_state = false,  -- Previous condition evaluation result
      last_tick_active = 0  -- Last tick this rule was active
    },
    -- ... more rules
  },

  -- Configuration
  evaluation_mode = "all_matching",  -- or "first_match_only"

  -- Connection cache
  connected_entities = {},  -- unit_numbers of logistics-enabled entities
  last_wire_update = 0      -- Tick when connections were last scanned
}
```

### Evaluation Cycle (Every 15 Ticks)

```lua
function process_chooser_combinator(combinator_unit_number)
  local data = storage.chooser_combinators[combinator_unit_number]
  local entity = -- get entity from unit_number

  -- 1. Read input signals (merge red + green)
  local input_signals = circuit_utils.get_merged_input_signals(entity)

  -- 2. Get connected entities (from cache)
  local connected_entities = get_connected_logistics_entities(combinator_unit_number)

  -- 3. Evaluate rules based on mode
  if data.evaluation_mode == "all_matching" then
    -- Process all rules, apply all that match
    for _, rule in ipairs(data.rules) do
      process_single_rule(rule, input_signals, connected_entities, combinator_unit_number)
    end

  elseif data.evaluation_mode == "first_match_only" then
    -- Process in order, stop at first match
    for _, rule in ipairs(data.rules) do
      local condition_met = evaluate_condition(rule, input_signals)
      if condition_met then
        process_single_rule(rule, input_signals, connected_entities, combinator_unit_number)
        break  -- Stop at first match
      else
        -- Update state for non-matching rules
        rule.last_state = false
      end
    end
  end
end
```

### Single Rule Processing

```lua
function process_single_rule(rule, input_signals, connected_entities, combinator_id)
  -- Evaluate condition
  local condition_met = evaluate_condition(rule, input_signals)

  -- Edge detection: only act on state change
  local state_changed = (condition_met ~= rule.last_state)

  if state_changed then
    rule.last_state = condition_met

    if condition_met then
      -- Condition became TRUE
      rule.last_tick_active = game.tick

      for _, entity_unit_number in ipairs(connected_entities) do
        local entity = -- get entity from unit_number

        if entity and entity.valid and entity.logistic_sections then
          if rule.action == "inject" then
            -- Inject group if not already present
            if not logistics_utils.has_logistics_group(entity, rule.group_name) then
              logistics_utils.inject_logistics_group(
                entity,
                rule.group_template,
                combinator_id
              )
              -- Track injection for cleanup
              track_injection(entity_unit_number, rule.group_name, combinator_id)
            end

          elseif rule.action == "remove" then
            -- Remove group if present
            logistics_utils.remove_logistics_group(
              entity,
              rule.group_name,
              combinator_id
            )
            -- Update tracking
            untrack_injection(entity_unit_number, rule.group_name, combinator_id)
          end
        end
      end
    else
      -- Condition became FALSE
      -- No action needed (edge-triggered only acts on TRUE)
      -- Groups remain until explicitly removed by another rule or combinator destruction
    end
  end
end
```

### Condition Evaluation

```lua
function evaluate_condition(rule, input_signals)
  -- Get signal value from input
  local signal_value = 0
  if rule.signal then
    signal_value = input_signals[rule.signal.type .. "/" .. rule.signal.name] or 0
  end

  -- Get comparison value (constant or signal)
  local compare_value = rule.value
  if type(rule.value) == "table" then
    -- Value is a signal reference
    compare_value = input_signals[rule.value.type .. "/" .. rule.value.name] or 0
  end

  -- Perform comparison
  if rule.operator == "<" then
    return signal_value < compare_value
  elseif rule.operator == ">" then
    return signal_value > compare_value
  elseif rule.operator == "=" then
    return signal_value == compare_value
  elseif rule.operator == "≠" then
    return signal_value ~= compare_value
  elseif rule.operator == "≤" then
    return signal_value <= compare_value
  elseif rule.operator == "≥" then
    return signal_value >= compare_value
  else
    return false
  end
end
```

---

## Evaluation Modes

### All Matching Mode (Default)

**Behavior**: Process all rules, apply every rule whose condition is TRUE.

**Use Cases**:
- Multiple independent alerts/warnings
- Layered logistics (different groups for different thresholds)
- Parallel state monitoring

**Example**: Resource monitoring
```
Rule 1: Iron < 1000 → Inject "Low Iron"      ✓ Active
Rule 2: Iron < 500  → Inject "Critical Iron" ✓ Active
Rule 3: Iron < 100  → Inject "Emergency Iron" ✓ Active
Result: All three groups injected when Iron = 50
```

### First Match Only Mode

**Behavior**: Process rules in order (top to bottom), stop at first TRUE condition.

**Use Cases**:
- Mutually exclusive states (only one mode active)
- Priority-based selection
- Switch/case style logic

**Example**: Platform operational modes
```
Rule 1: Mode-signal = 1 → Inject "Startup Mode"     ✓ Match! (stop here)
Rule 2: Mode-signal = 2 → Inject "Production Mode"  (not evaluated)
Rule 3: Mode-signal = 3 → Inject "Return Mode"      (not evaluated)
Result: Only "Startup Mode" injected
```

**Priority Ordering**: Drag rules to reorder. Top rules have higher priority.

---

## Connected Entity Management

### Entity Discovery

```lua
function get_connected_logistics_entities(combinator_unit_number)
  local data = storage.chooser_combinators[combinator_unit_number]
  local entity = -- get combinator entity

  -- Check if cache needs update
  if data.last_wire_update ~= game.tick then
    -- Scan circuit network for logistics-enabled entities
    local red_network = entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
    local green_network = entity.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_output)

    local connected = {}

    -- Scan red network
    if red_network then
      for _, connected_entity in pairs(red_network.connected_entities or {}) do
        if connected_entity.logistic_sections then
          table.insert(connected, connected_entity.unit_number)
        end
      end
    end

    -- Scan green network
    if green_network then
      for _, connected_entity in pairs(green_network.connected_entities or {}) do
        if connected_entity.logistic_sections then
          table.insert(connected, connected_entity.unit_number)
        end
      end
    end

    -- Update cache
    data.connected_entities = connected
    data.last_wire_update = game.tick
  end

  return data.connected_entities
end
```

### Wire Events

```lua
-- on_wire_added / on_wire_removed
function on_chooser_wire_changed(event)
  local entity = event.entity
  if entity.name == "logistics-chooser-combinator" then
    local data = storage.chooser_combinators[entity.unit_number]
    if data then
      -- Invalidate cache
      data.last_wire_update = 0
    end
  end
end
```

---

## Circuit Connection Behavior

### Input Connections (Red/Green Input)

- Read all signals from both red and green networks
- Merge signals for condition evaluation
- Signals with same ID from different networks are summed

### Output Connections (Red/Green Output)

**Primary Purpose**: Connect to logistics-enabled entities for control

**Optional Features** (future enhancement):
- Pass-through input signals
- Output status signal (e.g., virtual-signal-1 = number of active rules)
- Output active rule index

**Current Behavior**: Output connections used only for entity scanning, no signals sent

---

## Global State Structure

```lua
-- Initialization
storage.chooser_combinators = storage.chooser_combinators or {}

-- Per-combinator structure
storage.chooser_combinators[unit_number] = {
  -- Rule list (order matters in first_match_only mode)
  rules = {
    {
      rule_id = number,
      signal = SignalID,
      operator = string,
      value = number or SignalID,
      action = "inject" | "remove",
      group_name = string,
      group_template = table,
      last_state = boolean,
      last_tick_active = number
    },
    -- ...
  },

  -- Configuration
  evaluation_mode = "all_matching" | "first_match_only",

  -- Cache
  connected_entities = {unit_number, unit_number, ...},
  last_wire_update = number,  -- tick

  -- Metadata
  entity_unit_number = number,
  surface_index = number
}

-- Track injections for cleanup
storage.injected_groups = storage.injected_groups or {}
storage.injected_groups[entity_unit_number] = {
  [group_name] = {
    combinator_id = number,
    section_index = number
  },
  -- ...
}
```

---

## Entity Lifecycle

### On Built

```lua
function on_chooser_built(entity, player)
  -- Validate placement (no restrictions, can be placed anywhere)

  -- Register in global
  storage.chooser_combinators[entity.unit_number] = {
    rules = {},
    evaluation_mode = "all_matching",  -- Default
    connected_entities = {},
    last_wire_update = 0,
    entity_unit_number = entity.unit_number,
    surface_index = entity.surface.index
  }

  -- Open GUI if player-placed
  if player then
    create_chooser_gui(player, entity)
  end
end
```

### On Removed

```lua
function on_chooser_removed(entity)
  local data = storage.chooser_combinators[entity.unit_number]
  if not data then return end

  -- Remove all groups injected by this combinator
  for _, entity_unit_number in ipairs(data.connected_entities) do
    cleanup_injections_for_combinator(entity_unit_number, entity.unit_number)
  end

  -- Clear from global
  storage.chooser_combinators[entity.unit_number] = nil
end
```

### Cleanup Function

```lua
function cleanup_injections_for_combinator(target_entity_unit_number, combinator_unit_number)
  local injections = storage.injected_groups[target_entity_unit_number]
  if not injections then return end

  local target_entity = -- get entity from unit_number
  if not target_entity or not target_entity.valid then return end

  for group_name, injection_data in pairs(injections) do
    if injection_data.combinator_id == combinator_unit_number then
      -- Remove this group
      logistics_utils.remove_logistics_group(target_entity, group_name, combinator_unit_number)
      injections[group_name] = nil
    end
  end
end
```

---

## GUI Implementation

### GUI Creation

```lua
function create_chooser_gui(player, combinator_entity)
  local data = storage.chooser_combinators[combinator_entity.unit_number]
  if not data then return end

  -- Create main window
  local frame = player.gui.screen.add{
    type = "frame",
    name = "chooser_combinator_gui",
    direction = "vertical"
  }

  -- Titlebar
  local titlebar = gui_utils.create_titlebar(
    frame,
    "Logistics Chooser Combinator",
    "chooser_close"
  )

  -- Content area
  local content = frame.add{type = "flow", direction = "vertical"}
  content.style.padding = 12

  -- Header
  content.add{type = "label", caption = "Logistics Group Rules", style = "heading_2_label"}

  -- Add Rule button
  content.add{
    type = "button",
    name = "chooser_add_rule",
    caption = "[img=utility/add] Add Rule",
    style = "green_button"
  }

  -- Rule list container
  local rule_list = content.add{
    type = "scroll-pane",
    name = "chooser_rule_list",
    direction = "vertical"
  }
  rule_list.style.minimal_height = 200
  rule_list.style.maximal_height = 600

  -- Render each rule
  for i, rule in ipairs(data.rules) do
    create_rule_row(rule_list, rule, i, combinator_entity.unit_number)
  end

  -- Footer
  local footer = content.add{type = "flow", direction = "vertical"}
  footer.style.top_margin = 12

  -- Connected entities count
  footer.add{
    type = "label",
    caption = "Connected Entities: " .. #data.connected_entities
  }

  -- Evaluation mode selector
  local mode_flow = footer.add{type = "flow", direction = "horizontal"}
  mode_flow.add{type = "label", caption = "Evaluation Mode: "}

  local all_matching = mode_flow.add{
    type = "radiobutton",
    name = "chooser_mode_all",
    caption = "All matching",
    state = (data.evaluation_mode == "all_matching")
  }

  local first_match = mode_flow.add{
    type = "radiobutton",
    name = "chooser_mode_first",
    caption = "First match only",
    state = (data.evaluation_mode == "first_match_only")
  }

  -- Center and show
  gui_utils.center_gui(frame)
  player.opened = frame
end
```

### Rule Row Creation

```lua
function create_rule_row(parent, rule, index, combinator_unit_number)
  local row = parent.add{
    type = "frame",
    direction = "horizontal",
    style = "inside_shallow_frame"
  }
  row.style.padding = 8

  -- LED indicator
  local led = row.add{
    type = "sprite",
    name = "chooser_led_" .. index,
    sprite = rule.last_state and "utility/status_working" or "utility/status_not_working"
  }

  -- Drag handle (↑↓)
  local drag = row.add{
    type = "button",
    name = "chooser_drag_" .. index,
    caption = "↑↓",
    style = "mini_button"
  }

  -- Condition area
  local condition_flow = row.add{type = "flow", direction = "horizontal"}
  condition_flow.add{type = "label", caption = "When"}

  -- Signal picker
  condition_flow.add{
    type = "choose-elem-button",
    name = "chooser_signal_" .. index,
    elem_type = "signal",
    signal = rule.signal
  }

  -- Operator dropdown
  condition_flow.add{
    type = "drop-down",
    name = "chooser_operator_" .. index,
    items = {"<", ">", "=", "≠", "≤", "≥"},
    selected_index = get_operator_index(rule.operator)
  }

  -- Value field
  condition_flow.add{
    type = "textfield",
    name = "chooser_value_" .. index,
    text = tostring(rule.value),
    numeric = true,
    style = "short_number_textfield"
  }

  -- Action area
  local action_flow = row.add{type = "flow", direction = "horizontal"}
  action_flow.style.left_margin = 12
  action_flow.add{type = "label", caption = "Then"}

  -- Inject/Remove radio buttons
  action_flow.add{
    type = "radiobutton",
    name = "chooser_inject_" .. index,
    caption = "Inject",
    state = (rule.action == "inject")
  }
  action_flow.add{
    type = "radiobutton",
    name = "chooser_remove_" .. index,
    caption = "Remove",
    state = (rule.action == "remove")
  }

  -- Group picker
  action_flow.add{
    type = "choose-elem-button",
    name = "chooser_group_" .. index,
    elem_type = "logistic-groups",
    logistic_group = rule.group_name
  }

  -- Delete button
  row.add{
    type = "button",
    name = "chooser_delete_" .. index,
    caption = "×",
    style = "red_button"
  }
end
```

### GUI Event Handlers

```lua
-- on_gui_click
function on_chooser_gui_click(event)
  local element = event.element
  local player = game.players[event.player_index]

  if element.name == "chooser_add_rule" then
    add_new_rule(player, combinator_unit_number)
    rebuild_gui(player, combinator_unit_number)

  elseif element.name:match("^chooser_delete_") then
    local index = tonumber(element.name:match("%d+$"))
    delete_rule(combinator_unit_number, index)
    rebuild_gui(player, combinator_unit_number)

  elseif element.name:match("^chooser_inject_") then
    local index = tonumber(element.name:match("%d+$"))
    set_rule_action(combinator_unit_number, index, "inject")

  elseif element.name:match("^chooser_remove_") then
    local index = tonumber(element.name:match("%d+$"))
    set_rule_action(combinator_unit_number, index, "remove")

  elseif element.name == "chooser_mode_all" then
    set_evaluation_mode(combinator_unit_number, "all_matching")

  elseif element.name == "chooser_mode_first" then
    set_evaluation_mode(combinator_unit_number, "first_match_only")
  end
end

-- on_gui_elem_changed
function on_chooser_gui_elem_changed(event)
  local element = event.element

  if element.name:match("^chooser_signal_") then
    local index = tonumber(element.name:match("%d+$"))
    update_rule_signal(combinator_unit_number, index, element.elem_value)

  elseif element.name:match("^chooser_group_") then
    local index = tonumber(element.name:match("%d+$"))
    update_rule_group(combinator_unit_number, index, element.elem_value)
  end
end

-- on_gui_text_changed
function on_chooser_gui_text_changed(event)
  local element = event.element

  if element.name:match("^chooser_value_") then
    local index = tonumber(element.name:match("%d+$"))
    local value = tonumber(element.text) or 0
    update_rule_value(combinator_unit_number, index, value)
  end
end
```

---

## Integration with Mod Architecture

### Module Placement (Per Module Responsibility Matrix)

#### New Files to Create

**scripts/logistics_chooser_combinator/** (new directory)
- `logistics_chooser_combinator.lua` - Core logic (rule evaluation, entity management)
- `gui.lua` - GUI creation and event handling
- `control.lua` - Entity lifecycle events

**prototypes/entity/**
- `logistics_chooser_combinator.lua` - Entity prototype definition

**prototypes/item.lua**
- Add chooser combinator item definition

**prototypes/recipe.lua**
- Add chooser combinator recipe

**locale/en/mission-control.cfg**
- Add entity name, description, GUI strings

#### Shared Library Usage

The chooser combinator will use:
- `lib/logistics_utils.lua` - For group injection/removal
- `lib/circuit_utils.lua` - For reading input signals
- `lib/gui_utils.lua` - For GUI components (titlebar, etc.)
- `scripts/globals.lua` - For state registration/cleanup

#### control.lua Integration

```lua
-- In control.lua, add event handlers for chooser combinator
require("scripts.logistics_chooser_combinator.control")
```

---

## Use Case Examples

### Example 1: Progressive Resource Alerts

**Scenario**: Monitor iron plate levels with escalating alerts

```
Rule 1: Iron-plate < 1000 → Inject "Low Iron Warning"
Rule 2: Iron-plate < 500  → Inject "Critical Iron Alert"
Rule 3: Iron-plate < 100  → Inject "Emergency Iron Request"

Mode: All matching
Result: Multiple alert levels active simultaneously based on severity
```

### Example 2: Platform Operational Modes

**Scenario**: Switch platform logistics based on mission phase

```
Rule 1: Mission-phase = 1 → Inject "Launch Preparation"
Rule 2: Mission-phase = 2 → Inject "In-Transit Logistics"
Rule 3: Mission-phase = 3 → Inject "Orbit Operations"
Rule 4: Mission-phase = 4 → Inject "Return Journey"

Mode: First match only
Result: Only one operational mode active at a time
```

### Example 3: Dynamic Cargo Management

**Scenario**: Adjust cargo requests based on journey progress

```
Rule 1: Distance-to-destination < 1000 → Inject "Arrival Preparation"
Rule 2: Fuel-remaining < 50            → Inject "Emergency Fuel Request"
Rule 3: Ammo-count = 0                 → Inject "Ammo Resupply"
Rule 4: Time-in-orbit > 600            → Remove "Transit Supplies"

Mode: All matching
Result: Multiple logistics groups managed independently
```

### Example 4: Conditional Production Halting

**Scenario**: Stop science production when storage is full

```
Rule 1: Space-science-pack > 1000      → Remove "Science Production Requests"
Rule 2: Space-science-pack < 500       → Inject "Science Production Requests"

Mode: All matching (acts as hysteresis control)
Result: Production stops at high threshold, resumes at low threshold
```

---

## Performance Considerations

### Update Frequency

- **Rule Evaluation**: Every 15 ticks (matches logistics combinator)
- **Wire Connection Scan**: On-demand with caching (invalidated on wire events)
- **GUI Updates**: Only when GUI is open

### Optimization Strategies

1. **Connection Caching**: Don't rescan circuit network every tick
2. **Edge Triggering**: Only perform injection/removal on state changes
3. **Short-Circuit Evaluation**: In first_match_only mode, stop at first match
4. **Batch Processing**: Process all combinators in single on_nth_tick handler

### Expected Load

- **Low**: Single combinator with 5 rules = ~0.1ms per evaluation
- **Medium**: 10 combinators with 50 total rules = ~1ms per evaluation
- **High**: 100 combinators with 500 total rules = ~10ms per evaluation

**Mitigation**: If performance issues arise, increase update interval (30 ticks instead of 15).

---

## Testing Checklist

### Core Functionality
- [ ] Single rule injects group when condition becomes true
- [ ] Single rule removes group when condition becomes true
- [ ] Multiple rules process independently in "all matching" mode
- [ ] Only first matching rule processes in "first match only" mode
- [ ] LED indicators show correct state (green = active, off = inactive)
- [ ] Rule reordering changes evaluation priority
- [ ] Edge triggering prevents repeated injection of same group

### GUI Functionality
- [ ] Add rule button creates new rule
- [ ] Delete button removes rule
- [ ] Signal picker updates rule condition
- [ ] Operator dropdown changes comparison type
- [ ] Value field updates comparison value
- [ ] Inject/Remove radio buttons change action
- [ ] Group picker selects logistics group
- [ ] Evaluation mode radio buttons switch modes
- [ ] Connected entities count displays correctly
- [ ] GUI state persists across close/reopen

### Entity Behavior
- [ ] Combinator can be placed anywhere (no placement restrictions)
- [ ] Combinator connects to circuit networks (4 connection points)
- [ ] Input signals read correctly from red and green networks
- [ ] Output connections scan for logistics-enabled entities
- [ ] Multiple entities controlled by one combinator
- [ ] Wire connection/disconnection updates entity cache

### Lifecycle & Cleanup
- [ ] Building combinator opens GUI (if player-placed)
- [ ] Destroying combinator removes all injected groups
- [ ] Combinator removal clears from global state
- [ ] Injected groups tagged with combinator ID for cleanup
- [ ] Cleanup works even if target entity destroyed first

### Integration
- [ ] Works with cargo landing pads
- [ ] Works with inserters with logistics requests
- [ ] Works with assemblers with logistics requests
- [ ] Works with any entity with logistic_sections property
- [ ] Compatible with both "all matching" and "first match" modes

### Save/Load
- [ ] Rules persist across save/load
- [ ] Evaluation mode persists
- [ ] Rule state (last_state) persists
- [ ] Injected groups remain after load
- [ ] Connected entity cache rebuilds after load

### Multiplayer
- [ ] GUI changes sync to all players
- [ ] Rule evaluation syncs across clients
- [ ] No race conditions in group injection
- [ ] Multiple players can configure same combinator

### Edge Cases
- [ ] Empty rule list (no errors)
- [ ] Rule with no signal selected (condition always false)
- [ ] Rule with no group selected (no action taken)
- [ ] Entity destroyed while combinator active
- [ ] Combinator with no connected entities (no errors)
- [ ] Rapid wire connect/disconnect (cache updates correctly)
- [ ] Rule evaluation during save (no corruption)

---

## Implementation Priority

### Phase 1: Core Entity & Prototype
1. Create entity prototype
2. Create item and recipe
3. Add to technology unlock
4. Test placement and basic circuit connections

### Phase 2: Basic Rule Evaluation
1. Implement global state structure
2. Implement single-condition evaluation
3. Implement "all matching" mode
4. Test with simple inject rules

### Phase 3: GUI Implementation
1. Create basic GUI layout
2. Add rule row creation
3. Implement add/delete rule
4. Test GUI state persistence

### Phase 4: Advanced Features
1. Implement "first match only" mode
2. Add rule reordering (drag handles)
3. Add LED indicators
4. Test evaluation modes

### Phase 5: Integration & Polish
1. Wire connection caching
2. Connected entity scanning
3. Cleanup on entity removal
4. Performance optimization

### Phase 6: Testing & Documentation
1. Complete testing checklist
2. Create user guide
3. Add to main mod documentation
4. Multiplayer testing

---

## Future Enhancements (Optional)

### Potential Features (Not in Initial Release)

1. **Output Signals**: Send status information on output wires
   - Number of active rules
   - Active rule index
   - Pass-through input signals

2. **Rule Groups**: Organize rules into collapsible sections
   - Better organization for many rules
   - Enable/disable entire sections

3. **Templates**: Save/load rule configurations
   - Share configurations between combinators
   - Import/export as blueprint strings

4. **Visual Rule Builder**: More intuitive GUI
   - Flowchart-style rule visualization
   - Drag-and-drop rule creation

5. **Advanced Conditions**: Support more complex comparisons
   - Signal-to-signal comparison (not just signal-to-constant)
   - Multiple operators (between, modulo, etc.)

6. **Rule Comments**: Add descriptions to rules
   - Help remember what each rule does
   - Useful for complex setups

---

## Comparison Summary

| Feature | Logistics Combinator | Logistics Chooser Combinator |
|---------|---------------------|------------------------------|
| **Complexity** | High (multi-condition AND/OR) | Low (single condition per rule) |
| **Target User** | Advanced circuit users | General players |
| **Use Case** | Complex state logic | Simple threshold monitoring |
| **GUI Learning Curve** | Steep (precedence rules) | Gentle (clear if/then) |
| **Evaluation** | Boolean expression tree | Sequential or all-matching |
| **Priority Control** | Implicit (condition grouping) | Explicit (drag to reorder) |
| **Visual Feedback** | Active rules list | Per-rule LED indicators |
| **Configuration Time** | Slower (complex setup) | Faster (simple setup) |
| **Power** | Same (1kW) | Same (1kW) |
| **Size** | 2x1 | 2x1 |

**Recommendation**: Use Logistics Chooser for simple monitoring, Logistics Combinator for complex logic. Both have their place in a well-designed factory.

---

## Code Reuse Analysis & Refactoring Candidates

This section identifies existing code from `scripts/logistics_combinator/` that can be reused or adapted for the Logistics Chooser Combinator. Refactoring opportunities are noted for future implementation.

### A. Directly Reusable Code (No Changes Needed)

#### 1. **lib/logistics_utils.lua** - ALL FUNCTIONS ✅

All functions in this module are **directly reusable** without modification:

| Function | Purpose | Reuse Status |
|----------|---------|--------------|
| `supports_logistics_control(entity)` | Check if entity has logistics capability | ✅ Direct reuse |
| `has_logistics_group(entity, group_name)` | Check if group exists on entity | ✅ Direct reuse |
| `inject_logistics_group(entity, group, combinator_id)` | Inject logistics group | ✅ Direct reuse |
| `remove_logistics_group(entity, group, combinator_id, tracking)` | Remove logistics group | ✅ Direct reuse |
| `cleanup_combinator_groups(combinator_id, tracking)` | Cleanup all groups from combinator | ✅ Direct reuse |
| `cleanup_entity_groups(entity, tracking)` | Cleanup all groups from entity | ✅ Direct reuse |

**Why it works**: logistics_utils is already designed as a pure utility library with no business logic. It operates on individual entities and doesn't know about complex conditions or rule evaluation.

#### 2. **lib/circuit_utils.lua** - Input Signal Reading ✅

| Function | Purpose | Reuse Status |
|----------|---------|--------------|
| `get_input_signals(entity, connector_id)` | Read circuit signals | ✅ Direct reuse |
| `find_logistics_entities_on_output(entity)` | Find controllable entities | ✅ Direct reuse |

**Why it works**: Circuit signal reading is identical for both combinators - both need to read red/green input signals and merge them for evaluation.

#### 3. **lib/gui_utils.lua** - Generic GUI Components ✅

| Function | Purpose | Reuse Status |
|----------|---------|--------------|
| `create_titlebar(parent, title, close_button_name)` | Standard titlebar | ✅ Direct reuse |
| `create_button_row(parent, buttons)` | Button row layout | ✅ Direct reuse |
| `create_status_label(parent, text, icon_type)` | Status display | ✅ Direct reuse |
| `compare_values(left, right, operator)` | Single comparison | ✅ Direct reuse |
| `get_operator_from_index(index)` | Operator lookup | ✅ Direct reuse |
| `get_signal_key(signal_id)` | Signal key generation | ✅ Direct reuse |

**Why it works**: These are generic GUI patterns used across the mod.

#### 4. **scripts/globals.lua** - State Management Patterns ✅

The following **pattern** can be reused (not the exact functions):

```lua
-- Create similar functions for chooser combinator:
register_chooser_combinator(entity)
unregister_chooser_combinator(unit_number)
get_chooser_combinator_data(unit_number)
add_chooser_rule(unit_number, rule)
remove_chooser_rule(unit_number, rule_index)
update_chooser_rule(unit_number, rule_index, rule)
```

**Why it works**: Same state management pattern, just different data structure.

---

### B. Adaptable Code (Minor Modifications Required)

#### 1. **logistics_combinator.lua** → **chooser_combinator.lua**

##### B.1. Connected Entity Management 🔄 **REUSE WITH MINOR CHANGES**

**Source**: `logistics_combinator.lua:113-127`

```lua
function update_connected_entities(unit_number)
  -- Get entity
  local entity = combinator_data.entity

  -- Use circuit_utils to find logistics-capable entities
  local logistics_entities = circuit_utils.find_logistics_entities_on_output(entity)

  -- Store entity references
  combinator_data.connected_entities = logistics_entities
end
```

**Changes Needed**:
- Change function name to `chooser_combinator.update_connected_entities`
- Use `storage.chooser_combinators` instead of `storage.logistics_combinators`

**Refactoring Opportunity 🎯**:
- **Extract to shared module**: `lib/combinator_utils.lua`
- **New function**: `update_connected_logistics_entities(combinator_unit_number, storage_table)`
- **Benefit**: Both combinators call same code, reduces duplication

##### B.2. Group Injection Logic 🔄 **REUSE CORE, SIMPLIFY**

**Source**: `logistics_combinator.lua:208-268`

```lua
function inject_group(combinator_unit_number, entity, group_name, section_data)
  -- Validation
  if not logistics_utils.supports_logistics_control(entity) then return end

  -- Get requester point
  local requester_point = entity.get_requester_point()
  local multiplier = section_data.multiplier or 1.0

  -- Check if already exists (search backwards)
  local existing_section_index = nil
  for i = #sections, 1, -1 do
    if section.group == group_name and section.multiplier == multiplier then
      existing_section_index = i
      break
    end
  end

  if existing_section_index then return end  -- Already injected

  -- Inject new section
  local section_index = logistics_utils.inject_logistics_group(entity, group_name, combinator_id)

  -- Apply multiplier
  logistic_section.multiplier = multiplier

  -- Track injection
  globals.track_injected_section(combinator_id, entity.unit_number, group_name, multiplier)
end
```

**Changes Needed for Chooser**:
- **Simplification**: Chooser combinator doesn't use multipliers (optional feature)
- Remove multiplier logic if not needed
- Track by `{group_name}` instead of `{group_name, multiplier}` tuple

**Refactoring Opportunity 🎯**:
- **Extract core logic**: `inject_group_with_tracking(entity, group_name, combinator_id, multiplier?)`
- **Location**: `lib/logistics_utils.lua` (expand existing module)
- **Benefit**: Single injection implementation, less duplication

##### B.3. Group Removal Logic 🔄 **REUSE CORE, SIMPLIFY**

**Source**: `logistics_combinator.lua:275-315`

Similar pattern to injection - can be simplified by removing multiplier handling.

**Refactoring Opportunity 🎯**:
- **Extract to**: `lib/logistics_utils.lua`
- **Function**: `remove_group_with_tracking(entity, group_name, combinator_id, tracking_data)`

##### B.4. Cleanup Logic ✅ **DIRECT REUSE**

**Source**: `logistics_combinator.lua:330-337`

```lua
function cleanup_injected_groups(unit_number)
  logistics_combinator.reconcile_sections(unit_number, false)
  globals.clear_injected_tracking(unit_number)
end
```

**For Chooser**: Identical pattern, just different reconcile function name.

---

#### 2. **logistics_combinator/gui.lua** → **chooser_combinator/gui.lua**

##### B.5. GUI Structure & Lifecycle 🔄 **REUSE PATTERN**

**Source**: `gui.lua:808-952`

```lua
function create_gui(player, entity)
  -- Close existing
  close_gui(player)

  -- Create frame with flib_gui
  local refs = flib_gui.add(player.gui.screen, {
    -- Titlebar with drag handle
    -- Content frame
    -- Power status
    -- Condition indicator
  })

  -- Add panels
  create_conditions_panel(content_frame, entity)
  create_actions_section(content_frame, entity)
  create_signal_grid(content_frame, entity)

  -- Center and open
  refs[MAIN_FRAME].auto_center = true
  player.opened = refs[MAIN_FRAME]

  -- Store state
  globals.set_player_gui_entity(player.index, entity, "logistics_combinator")
end
```

**Changes Needed for Chooser**:
- Simplify conditions panel (no AND/OR logic)
- Replace with simple rule rows (drag handles + LED indicators)
- Remove complex condition builder
- Add evaluation mode radio buttons

**Refactoring Opportunity 🎯**:
- **Extract common pattern**: `lib/gui_utils.lua`
- **Function**: `create_combinator_gui_shell(player, entity, content_builder)`
- **Benefit**: Titlebar, power status, signal grid are identical across combinators

##### B.6. Power Status Display ✅ **DIRECT REUSE**

**Source**: `gui.lua:432-470`

```lua
function get_power_status(entity)
  if entity and entity.valid then
    local energy_ratio = entity.energy / entity.electric_buffer_size
    if energy_ratio >= 0.5 then
      return {sprite = "utility/status_working", text = "Working"}
    elseif energy_ratio > 0 then
      return {sprite = "utility/status_yellow", text = "Low Power"}
    else
      return {sprite = "utility/status_not_working", text = "No Power"}
    end
  end
  return {sprite = "utility/bar_gray_pip", text = "Unknown"}
end
```

**Refactoring Opportunity 🎯**:
- **Move to**: `lib/gui_utils.lua`
- **Rename**: `get_entity_power_status(entity)`
- **Benefit**: Reusable across all entity GUIs (MC, receiver, both combinators)

##### B.7. Signal Grid Display ✅ **DIRECT REUSE**

**Source**: `gui.lua:477-570`

```lua
function create_signal_grid(parent, entity, signal_grid_frame)
  -- Create signal grid with red/green subgrids
  -- Shows input signals in 10-column grid
  -- Color-coded by wire color
end
```

**Refactoring Opportunity 🎯**:
- **Move to**: `lib/gui_utils.lua`
- **Rename**: `create_input_signal_grid(parent, entity)`
- **Benefit**: Universal signal display for any combinator

##### B.8. GUI Utility Functions ✅ **DIRECT REUSE**

**Source**: `gui.lua:48-107`

```lua
function get_combinator_data_from_player(player)
  -- Helper to get combinator data from player GUI state
end

function get_condition_by_index(combinator_data, condition_index)
  -- Helper to get condition from data
end

function get_conditions_table(player)
  -- Helper to navigate GUI hierarchy
end
```

**Refactoring Opportunity 🎯**:
- **Pattern**: Create similar helpers for chooser
- These are so specific to the combinator type that direct reuse is hard
- Keep pattern, customize names

---

#### 3. **logistics_combinator/control.lua** → **chooser_combinator/control.lua**

##### B.9. Event Handlers ✅ **DIRECT PATTERN REUSE**

**Source**: `control.lua:10-90`

```lua
function on_built(entity, player)
  if entity.name ~= "logistics-combinator" then return end
  globals.register_logistics_combinator(entity)
  logistics_combinator.update_connected_entities(entity.unit_number)
  if player then
    logistics_combinator_gui.create_gui(player, entity)
  end
end

function on_removed(entity)
  if entity.name ~= "logistics-combinator" then return end
  logistics_combinator.cleanup_injected_groups(unit_number)
  globals.unregister_logistics_combinator(unit_number)
  -- Close GUIs
end
```

**Changes Needed**:
- Replace `"logistics-combinator"` with `"logistics-chooser-combinator"`
- Call chooser-specific functions instead

**Refactoring Opportunity 🎯**:
- **Extract pattern**: Could create generic combinator lifecycle manager
- **Location**: `lib/combinator_utils.lua`
- **Function**: `handle_combinator_built(entity, player, combinator_type_config)`
- **Benefit**: Reduce boilerplate for future combinator types

##### B.10. Periodic Update (on_nth_tick) 🔄 **SIMILAR PATTERN**

**Source**: `control.lua:134-150`

```lua
script.on_nth_tick(15, function()
  -- Update connected entities (detect wire changes)
  for unit_number, combinator_data in pairs(storage.logistics_combinators) do
    logistics_combinator.update_connected_entities(unit_number)
  end

  -- Process all combinator rules
  logistics_combinator.process_all_combinators()
end)
```

**Changes for Chooser**:
- Identical pattern, just call `chooser_combinator.process_all_combinators()`
- Could potentially **share same tick handler** if they run at same frequency

**Refactoring Opportunity 🎯**:
- **Unified tick handler**: Process both combinator types in same tick
- **Benefit**: Better performance, single update cycle

---

### C. New Code Required (No Existing Equivalent)

#### C.1. Simple Condition Evaluation ⚠️ **NEW LOGIC**

The chooser needs **single-condition evaluation**, which is simpler than the complex AND/OR logic.

**Existing**: `gui_utils.evaluate_complex_conditions()` - handles AND/OR precedence
**Needed**: `gui_utils.evaluate_single_condition(signals, condition)` - just one comparison

```lua
function evaluate_single_condition(signals, condition)
  local signal_value = signals[condition.signal] or 0
  local compare_value = condition.value  -- Always constant for chooser
  return compare_values(signal_value, compare_value, condition.operator)
end
```

**Refactoring Opportunity 🎯**:
- **Add to**: `lib/gui_utils.lua`
- This is actually simpler than existing code - extract the core comparison from complex evaluator

#### C.2. Rule Priority & Reordering ⚠️ **NEW FEATURE**

Drag-to-reorder functionality doesn't exist in logistics combinator.

**Needed**:
- GUI drag handles
- Rule index swapping
- Persistence of rule order

**Implementation**: Use FLib drag-drop helpers or custom implementation

#### C.3. Per-Rule LED Indicators ⚠️ **NEW FEATURE**

Logistics combinator has single condition indicator. Chooser needs one per rule.

**Needed**:
- Update LED state for each rule individually
- Different visual approach (inline vs status bar)

#### C.4. Evaluation Mode Selection ⚠️ **NEW FEATURE**

"All matching" vs "First match only" doesn't exist in logistics combinator.

**Needed**:
- Storage: `evaluation_mode` field
- GUI: Radio buttons
- Logic: Different processing loops

---

### D. Recommended Refactorings (Do While Implementing Chooser)

#### Priority 1: Extract Common Injection/Removal Logic 🎯

**Current State**: Duplicated in `logistics_combinator.lua`
**Target**: Move to `lib/logistics_utils.lua`

**New Functions**:
```lua
-- lib/logistics_utils.lua
function inject_group_with_multiplier(entity, group_name, multiplier, combinator_id)
  -- Combines current inject + multiplier application + tracking
end

function remove_group_by_tuple(entity, group_name, multiplier, combinator_id, tracking)
  -- Handles {group, multiplier} tuple matching
end
```

**Benefit**:
- Both combinators call same code
- Easier to maintain
- Consistent behavior

#### Priority 2: Extract GUI Shell Pattern 🎯

**Current State**: Duplicated titlebar, power status, signal grid
**Target**: Move to `lib/gui_utils.lua`

**New Function**:
```lua
-- lib/gui_utils.lua
function create_combinator_gui_base(player, entity, options)
  -- Creates titlebar, power status, returns content frame
  -- Caller fills in custom content
end
```

**Benefit**:
- Consistent look & feel
- Less GUI boilerplate
- Easier to update all combinator GUIs

#### Priority 3: Unified Connected Entity Tracking 🎯

**Current State**: Each combinator manages its own tracking
**Target**: Shared utility in `lib/combinator_utils.lua` (new file)

**New Function**:
```lua
-- lib/combinator_utils.lua (NEW FILE)
function update_connected_logistics_entities(combinator_entity, storage_key)
  -- Generic entity connection scanning
  -- Used by both logistics and chooser combinators
end
```

**Benefit**:
- Single implementation
- Consistent caching strategy

#### Priority 4: Extract Power Status to GUI Utils 🎯

**Current State**: In `logistics_combinator/gui.lua`
**Target**: Move to `lib/gui_utils.lua`

**Benefit**: Reusable across all entity GUIs

---

### E. Implementation Strategy

#### Phase 1: Implement Chooser (Copy & Simplify)
1. Copy logistics combinator code as starting point
2. Simplify condition evaluation (remove AND/OR)
3. Add new features (LED indicators, drag-to-reorder, evaluation modes)
4. Get chooser working independently

#### Phase 2: Refactor Common Code (After Chooser Works)
1. Extract injection/removal logic to lib/logistics_utils.lua
2. Extract GUI shell pattern to lib/gui_utils.lua
3. Create lib/combinator_utils.lua for shared combinator patterns
4. Update both combinators to use shared code

**Why This Order?**:
- Get chooser working first (prove it's viable)
- Refactor once you understand what's truly common
- Avoid premature abstraction

---

### F. File Organization Summary

```
lib/
├── logistics_utils.lua         ✅ ALREADY REUSABLE (expand with inject_with_multiplier)
├── circuit_utils.lua            ✅ ALREADY REUSABLE
├── gui_utils.lua                ✅ MOSTLY REUSABLE (add power_status, signal_grid, gui_shell)
├── combinator_utils.lua         ⚠️ NEW FILE (shared combinator patterns)
└── signal_utils.lua             ✅ ALREADY REUSABLE

scripts/
├── globals.lua                  🔄 ADD chooser functions (same pattern)
├── logistics_combinator/
│   ├── logistics_combinator.lua 🔄 ADAPT reconcile_sections pattern
│   ├── gui.lua                  🔄 ADAPT create_gui pattern, simplify conditions
│   └── control.lua              🔄 ADAPT event handlers (change entity name)
└── logistics_chooser_combinator/ ⚠️ NEW DIRECTORY
    ├── chooser_combinator.lua   ⚠️ NEW (simpler than logistics)
    ├── gui.lua                  ⚠️ NEW (simpler GUI, add LED + drag)
    └── control.lua              ⚠️ NEW (copy pattern from logistics)
```

---

### G. Reuse Checklist

When implementing chooser combinator, reference this checklist:

**Core Logic**:
- [ ] ✅ Use `lib/logistics_utils.lua` functions directly
- [ ] ✅ Use `lib/circuit_utils.lua` for signal reading
- [ ] 🔄 Adapt `inject_group()` pattern (simplify multiplier handling)
- [ ] 🔄 Adapt `remove_group()` pattern (simplify multiplier handling)
- [ ] 🔄 Adapt `cleanup_injected_groups()` pattern (same approach)
- [ ] 🔄 Adapt `update_connected_entities()` (same pattern)
- [ ] ⚠️ NEW: Simple condition evaluation (extract from complex evaluator)
- [ ] ⚠️ NEW: "All matching" vs "First match" processing loops

**GUI**:
- [ ] ✅ Use `gui_utils.create_titlebar()`
- [ ] ✅ Use `gui_utils.create_button_row()`
- [ ] ✅ Use `gui_utils.compare_values()` for condition eval
- [ ] 🔄 Adapt `create_signal_grid()` pattern (or refactor to gui_utils first)
- [ ] 🔄 Adapt `get_power_status()` pattern (or refactor to gui_utils first)
- [ ] 🔄 Adapt `create_gui()` shell structure
- [ ] ⚠️ NEW: Per-rule LED indicators
- [ ] ⚠️ NEW: Drag-to-reorder handles
- [ ] ⚠️ NEW: Evaluation mode radio buttons
- [ ] ⚠️ NEW: Simplified rule row (no AND/OR buttons)

**State Management**:
- [ ] 🔄 Add chooser functions to `scripts/globals.lua` (same pattern as logistics)
- [ ] 🔄 Create similar data structure (simpler: no complex conditions)

**Events**:
- [ ] 🔄 Copy `control.lua` event handler pattern
- [ ] 🔄 Adapt `on_built()` - change entity name, call chooser functions
- [ ] 🔄 Adapt `on_removed()` - change entity name, call chooser functions
- [ ] 🔄 Adapt `on_nth_tick(15)` - process chooser rules

---

## Final Notes

The Logistics Chooser Combinator is designed to **complement**, not replace, the Logistics Combinator. It provides a simpler, more accessible interface for common use cases while maintaining the same powerful group injection/removal capabilities.

**Design Goals Achieved**:
- ✓ Simple one-condition-per-rule design
- ✓ Clear visual feedback (LED indicators)
- ✓ Flexible evaluation modes
- ✓ Intuitive priority system
- ✓ Consistent with vanilla Factorio UI patterns
- ✓ Compatible with existing mod architecture

**Code Reuse Strategy**:
- ✓ Maximum reuse of lib/ utilities (logistics_utils, circuit_utils, gui_utils)
- ✓ Adapt and simplify logistics combinator patterns where applicable
- ✓ New features cleanly separated (LED indicators, drag-to-reorder, evaluation modes)
- ✓ Refactoring opportunities identified for future improvement

**Next Steps**: Proceed with Phase 1 implementation (copy & simplify approach), then Phase 2 refactoring to extract common code.

# Logistics Combinator Mod - Requirements Document

## Vision Statement
The Logistics Combinator mod extends Factorio 2.0+ logistics automation by enabling circuit network control of logistics groups. It introduces two combinators that dynamically inject/remove logistics groups based on circuit conditions, providing powerful automation for complex logistics scenarios without manual reconfiguration.

## Core Components

### 1. Technology

#### Logistics Circuit Control Technology
- **Name:** `logistics-circuit-control`
- **Prerequisites:** Logistic system
- **Cost:** 500x automation, 500x logistic, 500x chemical, 500x utility science packs
- **Unlocks:** Logistics Combinator, Logistics Chooser Combinator
- **Icon:** Combinator with logistics chest overlay

---

### 2. Logistics Combinator

The Logistics Combinator provides advanced circuit control with complex multi-condition logic using AND/OR operators.

**Entity Specifications:**
- **Size:** 2x1 (standard combinator size)
- **Recipe:** 5 electronic circuits + 1 decider combinator + 1 constant combinator
- **Placement:** Anywhere combinators can be placed (land or platform)
- **Health:** 150 (same as decider combinator, scales with quality)
- **Power:** 1kW
- **Circuit Connections:** 3 terminals (red in, green in, output - red/green)
- **Graphics:** Decider combinator with logistics chest icon overlay
- **Stack Size:** 50
- **Rocket Capacity:** 50

**Connection Behavior:**
- Output wire connects to ANY entity with logistics points (cargo landing pad, inserters, assemblers, etc.)
- Scans all circuit-connected entities on the output network
- Applies group injection/removal to all connected logistics-enabled entities
- One combinator can control multiple entities simultaneously
- Updates connection cache when wires added/removed

**Group Injection System:**
- **Does NOT modify existing logistics groups**
- **Injects/removes complete logistics groups based on conditions**
- Uses vanilla logistics group picker UI (`elem_type = "logistic-groups"`)
- Player selects from named groups library
- Each group gets a circuit condition (like decider combinator)
- Edge-triggered behavior (only acts on condition state change)
- Injected groups tagged with combinator unit_number for cleanup

**Multi-Condition Logic:**
- Supports AND/OR operators with proper precedence
- AND has higher precedence than OR (AND binds tighter)
- First condition has no AND/OR button (base condition)
- Subsequent conditions toggle between AND/OR (default: AND)
- OR conditions visually left-shifted to indicate grouping
- Example: `(Iron<100 AND Coal<50) OR Rocket-Fuel=0`

**GUI Structure:**
```
[Logistics Combinator]
┌──────────────────────────────────────────────────────────┐
│ Circuit-Controlled Groups                                │
├──────────────────────────────────────────────────────────┤
│ [+] Add Controlled Group                                 │
│                                                          │
│ Group: [Space Platform Fuel ▼]                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │      [Iron Plate ▼] [< ▼] [100      ]               │ │
│ │ [AND][Coal       ▼] [< ▼] [50       ]               │ │
│ │ [OR] [Rocket Fuel▼] [= ▼] [0        ]               │ │
│ │                                          [+][-]      │ │
│ └──────────────────────────────────────────────────────┘ │
│ Action: ◉ Inject ○ Remove                               │
│                                                          │
│ Active Rules: (2)                                        │
│ ✓ Inject "Space Platform Fuel"                          │
│   when ((Iron<100 AND Coal<50) OR Rocket-Fuel=0)        │
│                                                          │
│ Connected Entities: 4                                    │
└──────────────────────────────────────────────────────────┘
```

**Operation Logic:**
```lua
-- Every 15 ticks:
for each rule do
  -- Evaluate multi-condition expression with AND/OR precedence
  local condition_met = evaluate_conditions(input_signals, rule.conditions)
  local state_changed = (condition_met ~= rule.last_state)

  if state_changed then
    rule.last_state = condition_met

    for each entity in connected_entities do
      if entity.logistic_sections then
        if rule.action == "inject" and condition_met then
          if not has_group(entity, rule.group) then
            inject_logistics_group(entity, rule.group_template, combinator_id)
          end
        elseif rule.action == "remove" and condition_met then
          remove_logistics_group(entity, rule.group)
        end
      end
    end
  end
end
```

**Use Cases:**
- Complex state-based logistics control
- Multiple interdependent conditions
- Boolean logic expressions for automation
- Advanced circuit network integration

---

### 3. Logistics Chooser Combinator

The Logistics Chooser Combinator provides simplified circuit control with single-condition rules and priority ordering.

**Entity Specifications:**
- **Size:** 2x1 (standard combinator size)
- **Recipe:** 5 electronic circuits + 1 decider combinator + 1 constant combinator
- **Placement:** Anywhere combinators can be placed (land or platform)
- **Health:** 150 (same as decider combinator, scales with quality)
- **Power:** 1kW
- **Circuit Connections:** 3 terminals (red in, green in, output - red/green)
- **Graphics:** Decider combinator with distinct color tint
- **Stack Size:** 50
- **Rocket Capacity:** 50

**Design Philosophy:**
- One condition per rule (no AND/OR logic)
- Visual priority via drag handles for rule reordering
- Per-row LED indicators show which rules are active
- Two evaluation modes: "all matching" or "first match only"
- Follows vanilla Factorio combinator design patterns

**GUI Structure:**
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
│ Connected Entities: 4                                    │
│ Evaluation Mode: ◉ All matching  ○ First match only     │
└──────────────────────────────────────────────────────────┘

Legend:
● = Green LED (rule active - condition true)
○ = Dark LED (rule inactive - condition false)
```

**Evaluation Modes:**

**All Matching Mode** (Default):
- Process all rules
- Apply every rule whose condition is TRUE
- Use for: Multiple independent alerts, layered logistics, parallel monitoring
- Example: Resource monitoring with escalating thresholds

**First Match Only Mode:**
- Process rules in order (top to bottom)
- Stop at first TRUE condition
- Use for: Mutually exclusive states, priority-based selection, switch/case logic
- Example: Platform operational modes

**LED Indicators:**
- Green/Lit: Condition is TRUE and action is executing
- Dark/Off: Condition is FALSE (no action)
- Update frequency: Every 15 ticks (matches rule evaluation)

**Use Cases:**
- Simple threshold monitoring
- Progressive state changes (low/critical/emergency)
- Priority-based rule selection
- Quick setup with clear visualization
- Single-signal decision making

---

## When to Use Which Combinator

| Use Logistics Combinator When | Use Logistics Chooser When |
|-------------------------------|----------------------------|
| Complex multi-condition logic needed | Simple threshold monitoring |
| Boolean expressions required | Progressive state changes |
| AND/OR combinations necessary | Priority-based rule selection |
| Advanced circuit network integration | Quick setup and clear visualization |
| Multiple signals must be evaluated together | Single-signal decision making |

---

## Critical Implementation Details

### Global State Structure
```lua
storage = {
  -- Logistics Combinator
  logistics_combinators = {
    [unit_number] = {
      rules = {},  -- condition/action pairs with AND/OR logic
      connected_entities = {},  -- cached unit_numbers
      injected_groups = {}  -- track what we added
    }
  },

  -- Chooser Combinator
  chooser_combinators = {
    [unit_number] = {
      rules = {},  -- simple condition/action pairs
      evaluation_mode = "all_matching",  -- or "first_match_only"
      connected_entities = {},
      injected_groups = {}
    }
  },

  -- Injection tracking
  injected_groups = {
    [entity_unit_number] = {
      [group_name] = {
        combinator_id = number,
        section_index = number
      }
    }
  }
}
```

### Performance Optimizations
1. Use `on_nth_tick(15)` for rule evaluation
2. Cache entity connections, only update on wire events
3. Batch signal processing per combinator
4. Use edge-triggered conditions to reduce processing
5. Limit GUI updates to when GUI is open

### Entity Lifecycle
- **On Built:** Register in global, scan connections, open GUI (if player-placed)
- **On Removed:** Remove all injected groups, cleanup from global
- **On Wire Change:** Invalidate connection cache

---

## Edge Cases & Solutions

| Edge Case | Solution |
|-----------|----------|
| Combinator destroyed mid-operation | Remove all injected groups via cleanup handler |
| Wire disconnected | Update connection cache, stop controlling orphaned entities |
| Multiple combinators inject same group | Last wins (groups are idempotent) |
| Entity destroyed while controlled | Cleanup handler removes tracking data |
| Save during rule evaluation | Store rule states in global for restoration |
| Quality upgrade of entity | Preserve configuration, update health/power values |

---

## Validation Checklist

### Core Functionality
- [x] Combinators inject/remove groups, never modify existing ones
- [x] Red/green wire separation preserved for input signals
- [x] Edge-triggered behavior prevents repeated injection
- [x] All entities require appropriate tech unlock
- [x] 15-tick evaluation interval implemented

### Entity Behavior
- [x] Health values scale with quality
- [x] Power consumption: 1kW constant
- [x] Entities can be blueprinted and copy/pasted
- [x] Circuit connections preserved in blueprints

### UI/UX
- [x] Logistics group picker shows vanilla groups
- [x] LED indicators show active state (chooser only)
- [x] Connection status clearly displayed
- [x] GUI responsive to changes

### Events & Lifecycle
- [x] Wire added/removed updates connections
- [x] Entity destroyed events cleanup global state
- [x] Save/load preserves all state
- [x] Multiplayer synchronized properly

---

## Success Criteria

Players can successfully:
1. Build logistics combinators for circuit-controlled logistics
2. Configure complex multi-condition rules (logistics combinator)
3. Configure simple priority-based rules (chooser combinator)
4. See clear visual feedback (LEDs, status text) of system state
5. Create blueprints incorporating the new entities
6. Scale up to multiple combinators without issues
7. Use familiar Factorio UI patterns throughout

---

## File Structure

See [CLAUDE.md](../CLAUDE.md) for actual file organization.

Key directories:
- `mod/lib/` - Stateless utility libraries (signal_utils, circuit_utils, logistics_utils, gui_utils)
- `mod/scripts/logistics_combinator/` - Logistics Combinator implementation
- `mod/scripts/logistics_chooser_combinator/` - Chooser Combinator implementation
- `mod/prototypes/` - Entity, item, recipe, and technology definitions

---

## Notes

- This mod extends vanilla logistics without replacing functionality
- All vanilla logistics behaviors remain intact
- Circuit control is optional - players can ignore it entirely
- Focus on intuitive, Factorio-like user experience
- Prioritize stability over feature complexity
- When in doubt, follow vanilla patterns

For detailed implementation specifications, see:
- [logistics_chooser_combinator_spec.md](logistics_chooser_combinator_spec.md) - Detailed chooser spec
- [module_responsibility_matrix.md](module_responsibility_matrix.md) - Code organization
- [todo.md](todo.md) - Development roadmap (NOTE: May reference original mission control concept)

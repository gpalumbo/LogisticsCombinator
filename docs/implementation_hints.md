# Mission Control Mod - Complete Implementation Requirements

## Vision Statement
The Mission Control mod extends Factorio 2.0+ space platform automation by enabling circuit network communication between planetary surfaces and orbiting platforms. It introduces Mission Control buildings that act as planetary communication hubs, Receiver Combinators for platform-side data exchange, and Logistics Combinators that dynamically inject/remove logistics groups based on circuit conditions. This creates a seamless ground-to-space automation layer that feels native to Factorio's design philosophy while opening new strategic possibilities for cross-surface logistics control.

## File Structure
```
/
├── info.json
├── changelog.txt
├── thumbnail.png (optional, 144x144)
├── data.lua
├── control.lua
├── locale/
│   └── en/
│       └── mission-control.cfg
├── prototypes/
│   ├── technology.lua
│   ├── entity.lua
│   ├── item.lua
│   └── recipe.lua
└── graphics/
│   ├── entity/
│   │   ├── mission-control/
│   │   │   ├── mission-control-base.png
│   │   │   ├── mission-control-base-hr.png
│   │   │   ├── mission-control-shadow.png
│   │   │   ├── mission-control-shadow-hr.png
│   │   │   ├── mission-control-antenna.png
│   │   │   ├── mission-control-antenna-hr.png
│   │   │   ├── mission-control-leds.png
│   │   │   └── mission-control-remnants.png
│   │   ├── receiver-combinator/
│   │   │   ├── receiver-combinator-base.png
│   │   │   ├── receiver-combinator-base-hr.png
│   │   │   ├── receiver-combinator-dish.png
│   │   │   ├── receiver-combinator-dish-hr.png
│   │   │   └── ...
│   │   └── logistics-combinator/
│   │       ├── logistics-combinator-base.png
│   │       ├── logistics-combinator-base-hr.png
│   │       └── ...
│   ├── icons/
│   │   ├── mission-control-building.png
│   │   ├── receiver-combinator.png
│   │   └── logistics-combinator.png
│   ├── technology/
│   │   ├── mission-control.png
│   │   └── logistics-circuit-control.png
│   └── gui/
│       └── ...
```

## info.json
```json
{
  "name": "mission-control",
  "version": "0.1.0",
  "title": "Mission Control",
  "author": "YourName",
  "factorio_version": "2.0",
  "dependencies": ["base >= 2.0.0"],
  "description": "Enables circuit network communication between planets and space platforms with dynamic logistics control"
}
```

## Technologies

### 1. Mission Control Technology
```lua
-- prototypes/technology.lua
{
  type = "technology",
  name = "mission-control",
  icon = "__mission-control__/graphics/technology/mission-control.png",
  icon_size = 256,
  prerequisites = {"space-platform", "advanced-electronics-2", "radar"},
  unit = {
    count = 1000,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1}
    },
    time = 60
  },
  effects = {
    {type = "unlock-recipe", recipe = "mission-control-building"},
    {type = "unlock-recipe", recipe = "receiver-combinator"}
  }
}
```

### 2. Logistics Circuit Control Technology
```lua
{
  type = "technology",
  name = "logistics-circuit-control",
  icon = "__mission-control__/graphics/technology/logistics-circuit.png",
  icon_size = 256,
  prerequisites = {"logistic-system"},
  unit = {
    count = 500,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1}
    },
    time = 30
  },
  effects = {
    {type = "unlock-recipe", recipe = "logistics-combinator"}
  }
}
```

## Entity Specifications

### 1. Mission Control Building
```lua
-- prototypes/entity.lua
{
  type = "radar",  -- Use radar as base prototype
  name = "mission-control-building",
  icon = "__mission-control__/graphics/icons/mission-control.png",
  icon_size = 64,
  max_health = 500,  -- Double radar health for importance
  corpse = "radar-remnants",
  collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
  selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
  },
  energy_per_sector = "10MJ",  -- Dummy value, not used
  energy_usage = "1MW",  -- Constant power draw
  max_distance_of_sector_revealed = 0,  -- Disable exploration
  max_distance_of_nearby_sector_revealed = 0,  -- Disable exploration
  
  -- Circuit connections (4 terminals)
  circuit_wire_connection_points = {
    -- Define 4 connection points: red_in, green_in, red_out, green_out
    -- Use arithmetic-combinator connection point definitions as reference
  },
  
  -- Graphics: Use radar graphics as placeholder initially
  pictures = table.deepcopy(data.raw["radar"]["radar"].pictures),
  
  -- Custom data
  localised_description = {"entity-description.mission-control-building"}
}
```

**Item Definition:**
```lua
{
  type = "item",
  name = "mission-control-building",
  icon = "__mission-control__/graphics/icons/mission-control.png",
  icon_size = 64,
  subgroup = "circuit-network",
  order = "d[other]-b[mission-control]",
  place_result = "mission-control-building",
  stack_size = 10
}
```

**Recipe:**
```lua
{
  type = "recipe",
  name = "mission-control-building",
  enabled = false,  -- Unlocked by technology
  ingredients = {
    {"radar", 5},
    {"processing-unit", 100}
  },
  result = "mission-control-building",
  energy_required = 30
}
```

### 2. Receiver Combinator
```lua
{
  type = "arithmetic-combinator",  -- Use as base
  name = "receiver-combinator",
  icon = "__mission-control__/graphics/icons/receiver-combinator.png",
  icon_size = 64,
  max_health = 200,  -- Slightly more than standard combinator
  corpse = "arithmetic-combinator-remnants",
  collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
  selection_box = {{-1, -1}, {1, 1}},
  
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
  },
  active_energy_usage = "5kW",  -- 2.5x standard combinator
  
  -- 4 wire connection points needed
  input_connection_points = { /* red_in, green_in */ },
  output_connection_points = { /* red_out, green_out */ },
  
  -- Graphics: Use 2x2 version of combinator graphics
  sprites = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"].sprites),
  
  localised_description = {"entity-description.receiver-combinator"}
}
```

**Item Definition:**
```lua
{
  type = "item",
  name = "receiver-combinator",
  icon = "__mission-control__/graphics/icons/receiver-combinator.png",
  icon_size = 64,
  subgroup = "circuit-network",
  order = "d[other]-c[receiver-combinator]",
  place_result = "receiver-combinator",
  stack_size = 50
}
```

**Recipe:**
```lua
{
  type = "recipe",
  name = "receiver-combinator",
  enabled = false,
  ingredients = {
    {"advanced-circuit", 10},
    {"radar", 5},
    {"arithmetic-combinator", 1}
  },
  result = "receiver-combinator",
  energy_required = 10
}
```

### 3. Logistics Combinator
```lua
{
  type = "decider-combinator",  -- Use as base
  name = "logistics-combinator",
  icon = "__mission-control__/graphics/icons/logistics-combinator.png",
  icon_size = 64,
  max_health = 150,  -- Same as decider
  corpse = "decider-combinator-remnants",
  collision_box = {{-0.35, -0.65}, {0.35, 0.65}},
  selection_box = {{-0.5, -1}, {0.5, 1}},
  
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
  },
  active_energy_usage = "2kW",  -- Same as decider
  
  -- Standard combinator connections
  input_connection_points = { /* Standard */ },
  output_connection_points = { /* Standard */ },
  
  -- Graphics: Use decider graphics with color tint
  sprites = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"].sprites),
  
  localised_description = {"entity-description.logistics-combinator"}
}
```

**Recipe:**
```lua
{
  type = "recipe",
  name = "logistics-combinator",
  enabled = false,
  ingredients = {
    {"electronic-circuit", 5},
    {"decider-combinator", 1},
    {"constant-combinator", 1}
  },
  result = "logistics-combinator",
  energy_required = 5
}
```

## Control Script Structure

### control.lua Main Structure
```lua
-- control.lua

-- Global state structure
function init_globals()
  global.mc_networks = global.mc_networks or {}  -- [surface_index] = {red_signals, green_signals}
  global.platform_receivers = global.platform_receivers or {}  -- [platform.unit_number] = {entity, surfaces}
  global.logistics_combinators = global.logistics_combinators or {}  -- [unit_number] = {entity, rules, connected}
  global.injected_groups = global.injected_groups or {}  -- Track which groups we injected
  global.signal_queue = global.signal_queue or {}  -- For transmission delay
end

-- Event Registration
script.on_init(init_globals)
script.on_configuration_changed(init_globals)

-- Building placement/removal
script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)
script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)

-- Platform lifecycle
script.on_event(defines.events.on_space_platform_built, on_platform_built)
script.on_event(defines.events.on_space_platform_destroyed, on_platform_destroyed)

-- GUI events
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

-- Circuit updates - Every 15 ticks for transmission delay
script.on_nth_tick(15, update_transmissions)

-- Platform orbit checks - Every 60 ticks
script.on_nth_tick(60, update_platform_connections)
```

### Key Functions to Implement

```lua
function on_entity_built(event)
  local entity = event.created_entity or event.entity
  
  if entity.name == "mission-control-building" then
    -- Register MC in global.mc_networks[entity.surface.index]
    -- Initialize circuit monitoring
  elseif entity.name == "receiver-combinator" then
    -- Only allow on space platforms
    if not entity.surface.platform then
      -- Refund and cancel
      return
    end
    -- Register in global.platform_receivers
    -- Open configuration GUI
  elseif entity.name == "logistics-combinator" then
    -- Register in global.logistics_combinators
    -- Initialize rule storage
  end
end

function update_transmissions()
  -- Process MC networks
  for surface_index, network in pairs(global.mc_networks) do
    local red_sum, green_sum = {}, {}
    
    -- Sum all MC inputs on surface
    for _, mc in pairs(network.buildings) do
      add_signals(red_sum, get_circuit_signals(mc, defines.wire_type.red, "input"))
      add_signals(green_sum, get_circuit_signals(mc, defines.wire_type.green, "input"))
    end
    
    -- Send to all orbiting platforms
    for platform_id, receiver_data in pairs(global.platform_receivers) do
      if is_platform_orbiting(platform_id, surface_index) then
        output_signals(receiver_data.entity, red_sum, green_sum)
      end
    end
  end
  
  -- Process logistics combinators
  for unit_number, combinator_data in pairs(global.logistics_combinators) do
    process_logistics_rules(combinator_data)
  end
end

function process_logistics_rules(combinator_data)
  local entity = combinator_data.entity
  if not entity.valid then return end
  
  local input_signals = get_merged_input_signals(entity)
  local connected_entities = find_connected_logistics_entities(entity)
  
  for _, rule in pairs(combinator_data.rules) do
    local condition_met = evaluate_condition(input_signals, rule.condition)
    
    for _, target in pairs(connected_entities) do
      if target.logistic_sections then
        if rule.action == "inject" and condition_met then
          inject_logistics_group(target, rule.group_name)
        elseif rule.action == "remove" and condition_met then
          remove_logistics_group(target, rule.group_name)
        end
      end
    end
  end
end
```

## Locale Strings
```ini
[entity-name]
mission-control-building=Mission Control
receiver-combinator=Receiver Combinator
logistics-combinator=Logistics Combinator

[entity-description]
mission-control-building=Enables circuit network communication with orbiting space platforms. All Mission Control buildings on a surface share signals.
receiver-combinator=Receives and sends circuit signals to/from planetary Mission Control when platform is in orbit. Configure target planets in GUI.
logistics-combinator=Dynamically injects or removes logistics groups based on circuit conditions. Connect output to any logistics-enabled entity.

[technology-name]
mission-control=Mission Control
logistics-circuit-control=Logistics Circuit Control

[technology-description]
mission-control=Unlock buildings for cross-surface circuit network communication
logistics-circuit-control=Enable circuit-controlled logistics group management
```

## Critical Implementation Notes

### Placement Restrictions
```lua
-- MC Building: Planets only
if entity.surface.platform then
  player.create_local_flying_text{text={"message.mc-planet-only"}, position=entity.position}
  entity.destroy()
  -- Refund items
end

-- Receiver: Platforms only  
if not entity.surface.platform then
  player.create_local_flying_text{text={"message.receiver-platform-only"}, position=entity.position}
  entity.destroy()
  -- Refund items
end
```

### Signal Aggregation Pattern
```lua
-- CRITICAL: Sum signals, don't max or average
function add_signals(target_table, source_signals)
  for signal_id, count in pairs(source_signals or {}) do
    target_table[signal_id] = (target_table[signal_id] or 0) + count
  end
end
```

### Platform Orbit Detection
```lua
function is_platform_orbiting(platform_id, surface_index)
  local platform = game.get_platform_by_unit_number(platform_id)
  if not platform then return false end
  
  -- Must have space_location (orbiting something)
  if not platform.space_location then return false end
  
  -- Must be stationary (not traveling)
  -- Check if platform has movement scheduled or is mid-flight
  if platform.speed and platform.speed > 0 then return false end
  
  -- Check if orbiting the correct surface
  return platform.space_location.surface.index == surface_index
end
```

### Logistics Group Management
```lua
-- NEVER modify existing groups, only inject/remove
function inject_logistics_group(entity, group_name)
  -- Check if group already exists
  for _, section in pairs(entity.logistic_sections) do
    if section.group == group_name then
      return  -- Already has this group
    end
  end
  
  -- Add new section with group
  local group_data = get_logistics_group_template(group_name)
  entity.logistic_sections.add_section(group_data)
  
  -- Track injection for cleanup
  global.injected_groups[entity.unit_number] = global.injected_groups[entity.unit_number] or {}
  table.insert(global.injected_groups[entity.unit_number], group_name)
end
```

### GUI Implementation
```lua
-- Receiver Combinator: Surface selection
function create_receiver_gui(player, entity)
  local gui = player.gui.screen.add{
    type = "frame",
    name = "receiver_config",
    caption = {"gui.receiver-configuration"},
    direction = "vertical"
  }
  
  -- List all discovered planet surfaces
  for _, surface in pairs(game.surfaces) do
    if not surface.platform then  -- Is a planet
      gui.add{
        type = "checkbox",
        name = "surface_" .. surface.index,
        caption = surface.name,
        state = is_surface_selected(entity, surface.index)
      }
    end
  end
end

-- Logistics Combinator: Use logistics group dropdown
function create_logistics_gui(player, entity)
  local gui = player.gui.screen.add{
    type = "frame",
    name = "logistics_config",
    caption = {"gui.logistics-configuration"},
    direction = "vertical"
  }
  
  -- Group selector using vanilla element
  gui.add{
    type = "choose-elem-button",
    name = "group_selector",
    elem_type = "logistic-groups",  -- Key: Use vanilla group selector
    caption = {"gui.select-group"}
  }
  
  -- Condition builder (like decider combinator)
  -- Signal selector, operator dropdown, value field
end
```

### Performance Optimizations
- Cache connected entities, only recalculate on wire changes
- Batch signal updates in 15-tick intervals
- Use global lookup tables instead of repeated searches
- Minimize GUI updates to user-initiated events only

### Migration Support
```lua
-- migrations/0_1_0.lua
for _, surface in pairs(game.surfaces) do
  for _, entity in pairs(surface.find_entities_filtered{name = "mission-control-building"}) do
    -- Re-register any existing buildings
  end
end
```

## Testing Checklist
- [ ] MC buildings sum signals correctly from multiple buildings
- [ ] Receiver only activates when platform orbiting AND stationary
- [ ] Red/green wire signals remain separated through transmission
- [ ] 15-tick transmission delay functions properly
- [ ] Logistics combinator injects groups without modifying existing
- [ ] Logistics combinator removes only groups it injected
- [ ] GUI shows vanilla logistics group selector
- [ ] Platform lifecycle events handle connect/disconnect
- [ ] Save/load preserves all global state
- [ ] Multiplayer sync works correctly
- [ ] Quality bonuses apply to health/power consumption
- [ ] Technologies unlock recipes at correct progression point
- [ ] Placement restrictions enforced (MC on planet, Receiver on platform)

## Success Metrics
Players can successfully:
1. Establish planet-to-space communication networks
2. Differentiate multiple platforms using unique signals
3. Control platform logistics based on planetary conditions
4. See visual feedback of active circuit control
5. Use familiar Factorio UI patterns throughout

## Final Notes
- Start with placeholder graphics using tinted vanilla sprites
- All entity prototypes should extend appropriate vanilla bases
- Circuit behavior must use entity wire connections, not network hacks
- This mod adds capabilities without breaking vanilla behaviors
- Focus on making the system feel native to Factorio's design language

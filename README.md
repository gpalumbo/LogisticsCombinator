# Logistics Combinator

Named logistics groups provide a mechanism to reuse complex requests. This mod effectively allows you to turn these named groups on or off based on circuit conditions.   

The Logistics Combinator dynamically injects/removes named logistics groups when circuit conditions are met.
The Logistics Chooser Combinator switches between predefined logistics groups.

This mod doesn't allow for changing the definition of a named logistics group as that breaks the limitations on immediate planet to planet communications. That will be a different mod. 

## Features

- **Two specialized combinators** for circuit-controlled logistics
- **Edge-triggered behavior** - actions occur only when conditions change
- **Complex condition support** - combine multiple signals with AND/OR logic
- **Signal and constant comparisons** - flexible condition evaluation
- **Works with any logistics-enabled entity** - cargo landing pads, assemblers, inserters, chests, etc.

## Combinators

### Logistics Combinator

The **Logistics Combinator** dynamically injects and removes logistics groups based on circuit network conditions. When circuit conditions transition from false to true (or vice versa), the combinator adds or removes the specified logistics group from all connected entities.

**How it works:**
1. Place the Logistics Combinator and connect it to a circuit network (red/green wire to input)
2. Connect the **output** to entities with logistics (cargo landing pads, assemblers, etc.)
3. Open the combinator GUI and configure rules:
   - Select a logistics group to control
   - Set circuit conditions (e.g., "Iron plate < 100")
   - Choose action: **Inject** (add group) or **Remove** (remove group)
4. When conditions change state, the combinator injects/removes the group

**Use cases:**
- **Conditional logistics requests**: Request fuel only when low
- **Dynamic platform requests**: Adjust cargo landing pad requests based on logistics request.  
- **Smart mining outposts**: Request different ore types based on circuit signals
- **Adaptive manufacturing**: Change assembler requests based on production needs

**Example**: Inject "Rocket Fuel Group" when `Iron-plate < 100 AND Coal < 50` or when `Rocket-fuel = 0`

### Logistics Chooser Combinator

The **Logistics Chooser Combinator** selects and applies logistics groups from a predefined list based on circuit conditions. It's designed for quickly switching between multiple complete logistics configurations.

**How it works:**
1. Place the Logistics Chooser Combinator and connect it to a circuit network
2. Connect the **output** to entities with logistics
3. Open the GUI and add multiple groups, each with its own condition:
   - Group 1: "Mining Setup" when `Signal-M = 1`
   - Group 2: "Building Setup" when `Signal-B = 1`
   - Group 3: "Science Setup" when `Signal-S = 1`
4. Choose operating mode:
   - **Each**: Activates ALL groups whose conditions are true
   - **First Only**: Activates only the FIRST group with a true condition (priority order)

**Use cases:**
- **Multi-mode platforms**: Switch between different space platform configurations
- **Flexible outposts**: Toggle between mining, building, and maintenance logistics

**Example (First Only mode)**:
- Priority 1: "Emergency Supplies" when `Emergency-signal = 1`
- Priority 2: "Science Production" when `Science-needed = 1`
- Priority 3: "Normal Operations" when `Always-on = 1`

Only the highest-priority active group is applied.

## Technology Requirements

- **Logistics Circuit Control**
  - Prerequisites: Logistic system
  - Cost: 500× Automation, Logistic, Chemical, and Utility science packs
  - Unlocks: Both Logistics Combinator and Logistics Chooser Combinator

## Recipes

- **Logistics Combinator**: 5 Electronic circuits + 1 Decider combinator + 1 Constant combinator
- **Logistics Chooser Combinator**: 5 Electronic circuits + 1 Decider combinator + 1 Constant combinator

## Tips & Tricks

- **Edge-triggered behavior**: The Logistics Combinator only acts when conditions *change* state, not continuously while true
- **Wire filters**: Use red/green wire filters in the GUI to read from specific wire colors
- **Multiple entities**: Connect one combinator's output to multiple entities to control them all simultaneously
- **Group naming**: Use meaningful logistics group names that match your combinator rules
- **Priority order**: In Chooser's "First Only" mode, groups are evaluated top-to-bottom - reorder groups to change priority
- **Always-active groups**: In Chooser, create a final group with condition `each = 1` (always true) as a fallback

## Compatibility

- **Factorio version**: 2.0+
- **Required dependencies**: flib >= 0.16.0
- Compatible with any mod that uses standard Factorio logistics groups

## Known Issues

None currently reported. Please report issues on the mod portal or GitHub.

## Credits

- **Author**: Gordon Palumbo
- **Version**: 0.2.0

## License

This mod is licensed under the Apache License 2.0. See LICENSE file for details.

## Changelog

### 0.2.0
- Added Logistics Chooser Combinator with "Each" and "First Only" modes
- Enhanced condition evaluation system
- Improved GUI with wire filters

### 0.1.0
- Initial release
- Basic Logistics Combinator functionality
- Multi-condition support with AND/OR logic

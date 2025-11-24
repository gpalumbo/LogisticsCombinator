# Logistics Combinator Mod - Development TODO

## Project Status: Implementation Complete ✓

**Current Version:** 0.2.0
**Status:** Both combinators implemented and functional

---

## Completed Features ✓

### Core Implementation
- [x] Logistics Combinator with AND/OR logic
- [x] Logistics Chooser Combinator with priority-based rules
- [x] Circuit network integration
- [x] Logistics group injection/removal system
- [x] Entity lifecycle management
- [x] Wire connection tracking
- [x] Edge-triggered rule evaluation
- [x] Multi-condition evaluation with proper precedence

### User Interface
- [x] Logistics Combinator GUI with AND/OR condition builder
- [x] Chooser Combinator GUI with drag handles
- [x] LED indicators (chooser only)
- [x] Power status display
- [x] Connected entities count
- [x] Signal grid display
- [x] Evaluation mode selector (chooser only)

### Technical Infrastructure
- [x] Shared utility libraries (signal_utils, circuit_utils, logistics_utils, gui_utils)
- [x] Global state management
- [x] Event handling system
- [x] Save/load persistence
- [x] Migration support
- [x] Performance optimization (caching, batch processing)

### Prototypes & Data
- [x] Entity definitions (both combinators)
- [x] Item definitions
- [x] Recipe definitions
- [x] Technology tree integration
- [x] Locale strings
- [x] Graphics assets (placeholder using tinted vanilla sprites)

---

## Active Development Tasks

### Documentation
- [ ] Update all docs to reflect actual implementation (in progress)
  - [x] spec.md - Rewritten for actual implementation
  - [x] CLAUDE.md - File structure updated
  - [ ] todo.md - This file (in progress)
  - [ ] module_responsibility_matrix.md - Remove mission control references
  - [ ] code_architecture.md - Update to match actual structure
  - [ ] tile_buildability_approach.md - Update examples
  - [ ] linting_setup.md - Update examples
  - [ ] implementation_hints.md - Update code snippets
  - [ ] asset_spec.md - Check if exists and update if needed
  - [ ] VERIFICATION_REPORT.md - Update references

- [ ] Rename mod/locale/en/mission-control.cfg to logistics-combinator.cfg

### Testing & QA
- [ ] Full playthrough testing
- [ ] Multiplayer testing
- [ ] Blueprint support verification
- [ ] Copy/paste settings verification
- [ ] Performance testing with many combinators
- [ ] Edge case validation
- [ ] Mod compatibility testing

### Polish & UX
- [ ] Review GUI tooltips for clarity
- [ ] Verify all locale strings are clear
- [ ] Check entity descriptions
- [ ] Technology descriptions review
- [ ] Ensure consistent visual feedback

---

## Future Enhancements (Optional)

### Graphics
- [ ] Custom combinator sprites (currently using tinted vanilla)
- [ ] Custom technology icons
- [ ] LED indicator sprites for entity (chooser)
- [ ] Custom GUI graphics

### Features (Post 1.0)
- [ ] Output signals for combinator status
- [ ] Rule templates/presets
- [ ] Import/export configurations
- [ ] Rule comments/descriptions
- [ ] Signal-to-signal comparison (currently signal-to-constant)
- [ ] Advanced operators (between, modulo, etc.)
- [ ] Rule groups with enable/disable

### Performance
- [ ] Further optimization if needed (profile first)
- [ ] Configurable update intervals
- [ ] Lazy evaluation modes

---

## Code Organization

### File Structure (Actual)
```
mod/
├── lib/                    # Stateless utilities
│   ├── signal_utils.lua
│   ├── circuit_utils.lua
│   ├── logistics_utils.lua
│   ├── logistics_injection.lua
│   ├── gui_utils.lua
│   ├── platform_utils.lua
│   ├── validation.lua
│   └── gui/
│       ├── gui_circuit_inputs.lua
│       └── gui_entity.lua
├── scripts/               # Stateful logic
│   ├── globals.lua
│   ├── migrations.lua
│   ├── logistics_combinator/
│   │   ├── logistics_combinator.lua
│   │   ├── gui.lua
│   │   └── control.lua
│   └── logistics_chooser_combinator/
│       ├── logistics_chooser_combinator.lua
│       ├── gui.lua
│       └── control.lua
└── prototypes/
    ├── entity/
    │   ├── logistics_combinator.lua
    │   └── logistics_chooser_combinator.lua
    ├── item/
    │   ├── logistics_combinator.lua
    │   └── logistics_chooser_combinator.lua
    ├── recipe/
    │   ├── logistics_combinator.lua
    │   └── logistics_chooser_combinator.lua
    ├── technology/
    │   └── technologies.lua
    └── custom-input.lua
```

### Module Responsibilities

**lib/** - Pure utility functions, no global state access
- `signal_utils.lua` - Signal table operations (add, merge, copy, compare)
- `circuit_utils.lua` - Circuit network interaction (read signals, find entities)
- `logistics_utils.lua` - Logistics group manipulation (inject, remove, check)
- `logistics_injection.lua` - Advanced injection tracking
- `gui_utils.lua` - Reusable GUI components
- `platform_utils.lua` - Platform detection (for future space use)
- `validation.lua` - Entity placement validation (currently unused - using tile buildability)

**scripts/** - Stateful entity logic
- `globals.lua` - Global state management and accessors
- `migrations.lua` - Save migration support
- Entity directories contain:
  - `<entity>.lua` - Core functionality (rule processing, state management)
  - `gui.lua` - GUI creation and event handling
  - `control.lua` - Entity lifecycle events

---

## Development Guidelines

### Before Writing Code
1. Consult `docs/module_responsibility_matrix.md` for correct file placement
2. Check existing utilities in `lib/` before duplicating functionality
3. Follow established patterns in similar modules

### Code Quality
- Keep files under 750-900 lines
- Use inline documentation heavily
- Follow Factorio modding best practices
- Test changes before committing

### Performance
- Prefer `on_nth_tick` over `on_tick`
- Cache expensive lookups
- Minimize global table traversals
- Profile before optimizing

---

## Version History

### 0.2.0 (Current)
- Added Logistics Chooser Combinator
- Enhanced GUI feedback
- Performance optimizations
- Bug fixes

### 0.1.0
- Initial release
- Logistics Combinator with AND/OR logic
- Basic GUI
- Technology integration

---

## Notes for Future Development

### Original Vision
This mod was originally envisioned as "Mission Control" - a system for cross-surface communication between planets and space platforms using Mission Control buildings and Receiver Combinators. The original spec is preserved in:
- `docs/spec_original_mission_control.md` - Original requirements
- `docs/todo_original_mission_control.md` - Original development plan

The project pivoted to focus on logistics automation, which proved to be more practical and useful.

### Migration Path
If cross-surface communication is needed in the future, the logistics combinators provide a solid foundation:
- Signal handling infrastructure exists
- GUI patterns are established
- State management is robust
- Could add surface transmission as separate entities

---

## References

- **spec.md** - Current requirements and feature documentation
- **logistics_chooser_combinator_spec.md** - Detailed chooser specification
- **module_responsibility_matrix.md** - Code organization rules
- **code_architecture.md** - System architecture (may need updates)
- **CLAUDE.md** - Project process and file structure

---

## Current Focus

**Immediate Priority:** Documentation cleanup to remove mission control references and reflect actual implementation.

**Next Steps:**
1. Complete documentation updates
2. Testing pass
3. Prepare for release

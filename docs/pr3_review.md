# PR #3 Code Review - Phase 1 Utility Libraries
**Date:** 2025-11-13
**Reviewer:** Claude Code
**Scope:** Review of 6 utility library files against Factorio API best practices

---

## Executive Summary

**Overall Assessment:** ⚠️ **NEEDS REVISION**

The utility libraries demonstrate good organization and documentation, but several **critical API misunderstandings** need correction before Phase 2 implementation:

### Critical Issues Found:
1. ❌ **circuit_utils.lua** - Incorrect signal conversion logic
2. ❌ **platform_utils.lua** - API usage inconsistencies
3. ⚠️ **logistics_utils.lua** - Placeholder implementation with incorrect assumptions
4. ⚠️ **gui_utils.lua** - Module export uses global functions
5. ✅ **signal_utils.lua** - Well implemented
6. ✅ **validation.lua** - Correctly deprecated

---

## File-by-File Analysis

### 1. signal_utils.lua ✅ APPROVED

**Status:** No issues found

**Strengths:**
- Pure utility functions with no side effects
- Clear documentation and examples
- Proper module boundary adherence
- Inline test suite provided
- Handles edge cases (nil, zero values)

**Code Quality:** Excellent

---

### 2. circuit_utils.lua ❌ CRITICAL ISSUES

**Status:** MUST FIX before Phase 2

#### Issue #1: Incorrect Signal Table Conversion (Lines 106-112)
```lua
-- CURRENT (WRONG):
local signal_table = {}
for _, signal_data in pairs(signals) do
  if signal_data.signal and signal_data.count then
    signal_table[signal_data.signal] = signal_data.count  -- ❌ WRONG
  end
end
```

**Problem:** Using signal object as table key is incorrect. Factorio API returns signals as an array, not a lookup table.

**Factorio API Reality:**
```lua
-- LuaCircuitNetwork.signals returns:
{
  {signal = {type = "item", name = "iron-plate"}, count = 100},
  {signal = {type = "virtual", name = "signal-A"}, count = 50}
}
```

**Correct Implementation:**
```lua
local signal_table = {}
for _, signal_data in pairs(signals) do
  if signal_data.signal and signal_data.count then
    -- Create string key for lookup
    local key = signal_data.signal.type .. ":" .. signal_data.signal.name
    signal_table[key] = {signal = signal_data.signal, count = signal_data.count}
  end
end
```

**Impact:** HIGH - This will break all signal processing if not fixed.

---

#### Issue #2: has_circuit_connection - Inefficient Iteration (Lines 161-177)

```lua
-- CURRENT (SUBOPTIMAL):
local connector_ids = {
  defines.circuit_connector_id.combinator_input,
  defines.circuit_connector_id.combinator_output,
  -- ... checking all possible connectors
}
```

**Problem:** Iterates through all connector types for every entity, even when entity only has one connector type.

**Better Approach:**
```lua
function circuit_utils.has_circuit_connection(entity, wire_type)
  if not circuit_utils.is_valid_circuit_entity(entity) then
    return false
  end

  -- Use circuit_connected_entities (available in API)
  local connected = entity.circuit_connected_entities
  if not connected then return false end

  local wire_entities = connected[wire_type == defines.wire_type.red and "red" or "green"]
  return wire_entities and #wire_entities > 0
end
```

**Impact:** MEDIUM - Performance issue with many entities.

---

#### Issue #3: Removed Function Migration Comments

The removed functions are correctly identified, but the migration guide is incomplete:

**Missing:** `entity.get_merged_signals()` was added in Factorio 1.1.50, but the format differs from `get_circuit_signals()`. Need to clarify conversion:

```lua
-- get_merged_signals returns ARRAY format:
-- {{signal={...}, count=N}, ...}

-- To convert to the signal_table format this mod uses:
local function convert_merged_signals(merged_array)
  local signal_table = {}
  if not merged_array then return signal_table end

  for _, signal_data in pairs(merged_array) do
    local key = signal_data.signal.type .. ":" .. signal_data.signal.name
    signal_table[key] = signal_data.count
  end
  return signal_table
end
```

---

### 3. platform_utils.lua ⚠️ WARNINGS

**Status:** FUNCTIONAL but needs consistency improvements

#### Issue #1: Inconsistent Wrapper Removal (Lines 27-42)

The file documents removal of wrapper functions but then **still includes some wrappers**:

```lua
-- Lines 65-77: is_platform_stationary is a wrapper around platform.speed
-- This is actually GOOD - adds semantic meaning
-- But contradicts the "no wrappers" principle stated in removed functions

-- INCONSISTENCY: Why remove get_platform_for_surface but keep is_platform_stationary?
```

**Recommendation:**
- **KEEP** `is_platform_stationary` - it adds value (checks both location and speed)
- **KEEP** `get_orbited_surface` - it adds value (extracts surface from space_location)
- Document WHY these wrappers are kept (they add semantic value, not just 1:1 wrappers)

#### Issue #2: API Assumptions Not Verified (Lines 110-114)

```lua
-- Line 111: Comment says "space_location.surface gives the orbited surface"
if space_location.surface and space_location.surface.valid then
  return space_location.surface
end
```

**Concern:** Need to verify `LuaSpaceLocation.surface` exists in API. If this is a custom interpretation, needs clarification.

**Action Item:** Test with actual Factorio API or add TODO comment about verification.

---

#### Issue #3: Platform Lookup by ID (Lines 139-148)

```lua
-- Line 145: Looks up platform by unit_number using game.space_platforms
local platform = game.space_platforms[platform_id]
```

**Problem:** `game.space_platforms` is an **array**, not a table keyed by unit_number.

**Correct Access:**
```lua
-- game.space_platforms is an array, need to iterate:
local function find_platform_by_unit_number(unit_number)
  for _, platform in pairs(game.space_platforms or {}) do
    if platform.valid and platform.unit_number == unit_number then
      return platform
    end
  end
  return nil
end
```

**Impact:** HIGH - This function will fail at runtime.

---

### 4. logistics_utils.lua ⚠️ MAJOR CONCERNS

**Status:** Contains placeholder implementations with incorrect assumptions

#### Issue #1: Empty Function with Wrong Assumptions (Lines 63-81)

```lua
-- Lines 70-72: INCORRECT COMMENT
-- "TODO: Implement event-based entity tracking"
-- "LuaCircuitNetwork.connected_entities does NOT exist in Factorio API"
```

**CORRECTION:** `LuaCircuitNetwork` doesn't have `connected_entities`, but **entities do**:

```lua
-- CORRECT API ACCESS:
entity.circuit_connected_entities
-- Returns: {red = {array of LuaEntity}, green = {array of LuaEntity}}
```

**Proper Implementation:**
```lua
function logistics_utils.find_logistics_entities_on_network(circuit_network)
  local results = {}

  if not circuit_network or not circuit_network.valid then
    return results
  end

  -- Get all entities on the network by walking connections
  -- Start with a seed entity (caller should provide) or use network_id tracking

  -- Note: Circuit networks don't directly expose entities
  -- Caller needs to maintain entity tracking via on_wire_added/removed events

  return results
end
```

**But wait** - this reveals a design flaw. This function **cannot work** as designed. The caller (logistics_combinator) needs to track connected entities itself.

**Recommendation:** Remove this function entirely or document it as a helper for filtered iteration over tracked entities.

---

#### Issue #2: Logistics API Correctness (Lines 108-120)

```lua
-- Lines 108-109: Uses get_requester_point()
local requester_point = entity.get_requester_point()
```

**Verification Needed:** Confirm Factorio 2.0 API has `get_requester_point()` and that logistics sections are accessed via `requester_point.sections`.

**API Change Alert:** In Factorio 2.0, the logistics API changed significantly. Verify:
- `LuaEntity.get_requester_point()` exists (Factorio 2.0.21+)
- `LuaLogisticPoint.sections` property
- `LuaLogisticSection.group` property

If API differs, this needs major refactoring.

---

#### Issue #3: Inefficient Entity Lookup (Lines 316-334)

```lua
-- Lines 319-334: Iterates ALL entities on ALL surfaces
for _, surface in pairs(game.surfaces) do
  local found_entities = surface.find_entities_filtered{
    name = {"cargo-landing-pad", "inserter", "assembling-machine", "cargo-bay"},
    limit = 1000
  }
```

**Problem:** O(n) search across entire game for every cleanup operation.

**Better Approach:**
```lua
-- Store entity references in global when injecting:
-- global.injected_groups[entity_id] = {
--   entity = entity,  -- Direct reference (but see warning below)
--   sections = {...}
-- }

-- WARNING: Cannot store entity references across save/load!
-- Must find entities by position or maintain surface-indexed lookup
```

**This is a fundamental architecture problem.** Need to decide:
1. Accept O(n) search (simple but slow)
2. Maintain reverse lookup table (complex but fast)
3. Only cleanup when entity is still valid (skip destroyed entities)

**Recommendation:** Option 3 - Only clean up injected groups on entities that still exist. Don't search for destroyed entities.

---

### 5. gui_utils.lua ⚠️ MINOR ISSUES

**Status:** Functional but needs cleanup

#### Issue #1: Global Functions (Lines 47-316)

```lua
-- Lines 47-304: Functions defined globally, then exported at line 321
function create_titlebar(parent, title, close_button_name)
  -- ...
end

-- Then at line 321:
return {
  create_titlebar = create_titlebar,
  -- ...
}
```

**Problem:** Functions are global before being exported. Should be local.

**Correct Pattern:**
```lua
local gui_utils = {}

function gui_utils.create_titlebar(parent, title, close_button_name)
  -- ...
end

return gui_utils
```

**Or:**
```lua
local function create_titlebar(parent, title, close_button_name)
  -- ...
end

return {
  create_titlebar = create_titlebar,
  -- ...
}
```

**Impact:** LOW - Works but pollutes global namespace during loading.

---

#### Issue #2: Signal Key Function (Lines 306-315)

```lua
-- Lines 310-314: Oversimplified signal key generation
function get_signal_key(signal)
  if not signal or not signal.name then return "" end
  return signal.type .. ":" .. signal.name  -- GOOD approach
end
```

**But why is this in gui_utils?** This duplicates signal_utils logic.

**Recommendation:**
- Move to signal_utils.lua (it's signal manipulation)
- Or have gui_utils call signal_utils for this

---

#### Issue #3: evaluate_condition Signal Format (Lines 266-304)

```lua
-- Line 271: Gets signal key
local signal_key = get_signal_key(condition.signal)
local left_value = signals[signal_key] or 0
```

**Question:** What format are `signals` expected to be in?
- If it's the array format from Factorio API: ❌ Won't work
- If it's converted to key-value table: ✅ Will work

**Need to document expected input format clearly.**

---

### 6. validation.lua ✅ APPROVED

**Status:** Correctly marked as deprecated

**Strengths:**
- Clear documentation of why it's deprecated
- References tile_buildability_approach.md
- Maintains code for reference
- Well-structured for optional custom messages

**Recommendation:** Keep as-is. Don't import in Phase 2 unless custom error messages are needed.

---

## Separation of Concerns Review

### Top-Level Structure ✅ GOOD
- All files are in `mod/lib/` (correct location)
- No entity-specific logic (correct)
- No global state access (correct)
- Pure functions only (correct)

### Module Boundaries ✅ MOSTLY GOOD

**Correct:**
- `signal_utils` - Pure signal manipulation
- `validation` - Placement validation (deprecated correctly)
- `gui_utils` - Reusable GUI components

**Needs Clarification:**
- `circuit_utils` - Mixes low-level API access with convenience methods
- `platform_utils` - Some functions are thin wrappers (document why kept)
- `logistics_utils` - Contains placeholder that can't work as designed

---

## Best Practices Review

### ✅ GOOD PRACTICES OBSERVED:
1. Comprehensive inline documentation
2. Clear module purpose statements
3. Edge case handling (nil checks)
4. Module responsibility matrix compliance
5. No global state access in lib modules
6. Defensive programming (valid checks)

### ❌ POOR PRACTICES FOUND:
1. **Incorrect API assumptions** (circuit signals, platform lookup)
2. **Inefficient algorithms** (O(n) surface scans)
3. **Global function pollution** (gui_utils)
4. **Placeholder implementations** (logistics_utils.find_logistics_entities_on_network)
5. **Inconsistent documentation** (platform_utils wrappers)

---

## Critical Blockers for Phase 2

Before implementing Phase 2 (prototypes) or Phase 3 (entity scripts), **MUST FIX:**

### 🔴 BLOCKER 1: circuit_utils.get_circuit_signals Signal Format
**File:** `circuit_utils.lua:106-112`
**Issue:** Returns wrong signal table format
**Impact:** All circuit signal processing will fail

### 🔴 BLOCKER 2: platform_utils.is_platform_orbiting Platform Lookup
**File:** `platform_utils.lua:145`
**Issue:** Incorrect array access (treats array as lookup table)
**Impact:** Receiver connection checks will crash

### 🔴 BLOCKER 3: logistics_utils.find_logistics_entities_on_network
**File:** `logistics_utils.lua:63-81`
**Issue:** Cannot work as designed (no API to get entities from network)
**Impact:** Logistics combinator can't find target entities

---

## Recommendations

### Immediate Actions (Before Merging PR #3):

1. **Fix circuit_utils signal conversion** (30 min)
   - Correct the signal table key generation
   - Add format documentation
   - Update tests

2. **Fix platform_utils lookup** (15 min)
   - Implement proper iteration over game.space_platforms
   - Cache platform lookups if needed
   - Document performance implications

3. **Redesign logistics_utils network scanning** (2 hours)
   - Accept tracked entities as parameter
   - Remove impossible find_logistics_entities_on_network
   - Document caller responsibility for tracking
   - Move wire tracking to entity script

4. **Fix gui_utils global pollution** (15 min)
   - Make all functions local or module-scoped
   - Clean up namespace

5. **Verify Factorio 2.0 APIs** (1 hour)
   - Test get_requester_point() exists
   - Verify space_location.surface property
   - Confirm logistics section API
   - Document API version dependencies

### Long-term Improvements:

1. **Add API version checks** - Detect Factorio version and fail gracefully
2. **Performance profiling** - Test with 100+ entities
3. **Integration tests** - Test across save/load cycles
4. **Add signal format converter** - Standardize on key-value OR array consistently

---

## Verdict

**Recommendation:** 🔴 **REQUEST CHANGES**

The utility libraries have a solid foundation but contain critical API misunderstandings that will cause runtime failures. The fixes are straightforward but essential before Phase 2 implementation.

**Estimated Fix Time:** 4-5 hours
**Risk if Not Fixed:** High - Multiple systems will fail at runtime

---

## Detailed Fix Checklist

### circuit_utils.lua
- [ ] Fix signal table conversion (lines 106-112)
- [ ] Optimize has_circuit_connection (lines 161-177)
- [ ] Document signal format expectations
- [ ] Add format converter utility

### platform_utils.lua
- [ ] Fix game.space_platforms access (line 145)
- [ ] Verify space_location.surface API
- [ ] Document wrapper retention rationale
- [ ] Add platform lookup caching

### logistics_utils.lua
- [ ] Remove/redesign find_logistics_entities_on_network
- [ ] Document caller tracking responsibility
- [ ] Fix cleanup_combinator_groups performance
- [ ] Verify Factorio 2.0 logistics API

### gui_utils.lua
- [ ] Fix global function pollution
- [ ] Move signal_key to signal_utils
- [ ] Document signal format expectations
- [ ] Clean up module exports

### validation.lua
- [ ] No changes needed ✅

### signal_utils.lua
- [ ] No changes needed ✅

---

**Review Completed:** 2025-11-13
**Next Step:** Address blockers before Phase 2 implementation

--[[
  signal_utils.lua
  Mission Control Mod - Pure Signal Manipulation Utilities

  PURPOSE:
  This module provides pure functions for manipulating Factorio circuit signal tables.
  All functions are stateless and do not access global state or entity APIs.

  SIGNAL FORMAT:
  Factorio signals are stored as:
    signals = {
      [signal_id] = count,
      ...
    }

  Where signal_id is a table: {type = "item"|"fluid"|"virtual", name = "signal-name"}

  EXAMPLES:
    {type = "item", name = "iron-plate"}
    {type = "virtual", name = "signal-A"}
    {type = "fluid", name = "water"}

  SCOPE:
  ✓ Signal table operations (add, merge, copy, compare, clear)
  ✓ Signal counting and validation
  ✗ Reading signals from entities (that's circuit_utils)
  ✗ Storing signals in global (that's entity scripts)
  ✗ Evaluating conditions (that's gui_utils)

  DEPENDENCIES: None (pure utility module)

  MODULE RESPONSIBILITY:
  - Pure signal table manipulation
  - No side effects
  - No global state access
  - No entity interactions
--]]

local signal_utils = {}

--[[
  HELPER: Convert signal_id to string key for comparison
  Signal IDs are tables, so we need string keys for equality checks

  @param signal_id table: Signal identifier {type, name}
  @return string: Unique string key for this signal
--]]
local function signal_to_key(signal_id)
  if not signal_id then return nil end
  return signal_id.type .. ":" .. signal_id.name
end

--[[
  HELPER: Check if two signal_ids are equal

  @param a table: First signal_id {type, name}
  @param b table: Second signal_id {type, name}
  @return boolean: True if both represent the same signal
--]]
local function signal_ids_equal(a, b)
  if not a or not b then return false end
  return a.type == b.type and a.name == b.name
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
  Add source signals into target table (MUTATES target)

  This function performs in-place addition of signal values.
  If a signal exists in both tables, values are summed.
  If a signal only exists in source, it's added to target.

  @param target table: Signal table to add into (modified in place)
  @param source table: Signal table to add from (not modified)

  BEHAVIOR:
  - Mutates target table
  - Does not modify source table
  - Handles nil gracefully (no-op)
  - Skips nil or zero values

  EXAMPLE:
    target = {[iron_signal] = 10, [copper_signal] = 5}
    source = {[iron_signal] = 15, [coal_signal] = 20}
    add_signals(target, source)
    -- Result: target = {[iron_signal] = 25, [copper_signal] = 5, [coal_signal] = 20}
--]]
function signal_utils.add_signals(target, source)
  -- Validate inputs
  if not target then return end
  if not source then return end

  -- Iterate through source signals and add to target
  for signal_id, count in pairs(source) do
    if signal_id and count and count ~= 0 then
      if target[signal_id] then
        target[signal_id] = target[signal_id] + count
      else
        target[signal_id] = count
      end
    end
  end
end

--[[
  Merge red and green wire signals (returns NEW table)

  When both red and green wires have the same signal, values are SUMMED.
  This matches Factorio's vanilla behavior for circuit network evaluation.

  @param red_signals table: Red wire signal table
  @param green_signals table: Green wire signal table
  @return table: New merged signal table (sum value per signal)

  BEHAVIOR:
  - Creates new table (does not modify inputs)
  - SUM values for duplicate signals
  - Handles nil inputs (returns empty table)
  - Preserves signal_id table references

  EXAMPLE:
    red = {[iron_signal] = 10, [copper_signal] = 5}
    green = {[iron_signal] = 15, [coal_signal] = 20}
    merged = merge_signals(red, green)
    -- Result: {[iron_signal] = 25, [copper_signal] = 5, [coal_signal] = 20}
--]]
function signal_utils.merge_signals(red_signals, green_signals)
  local merged = {}

  -- Add all red signals
  if red_signals then
    for signal_id, count in pairs(red_signals) do
      if signal_id and count and count ~= 0 then
        merged[signal_id] = count
      end
    end
  end

  -- Add/merge green signals (sum values)
  if green_signals then
    for signal_id, count in pairs(green_signals) do
      if signal_id and count and count ~= 0 then
        if merged[signal_id] then
          merged[signal_id] = merged[signal_id] + count
        else
          merged[signal_id] = count
        end
      end
    end
  end

  return merged
end

--[[
  Deep copy signal table (returns NEW table)

  Creates an independent copy of the signal table.
  Signal_id tables are used as keys (preserved by reference).

  @param source table: Signal table to copy
  @return table: New independent signal table

  BEHAVIOR:
  - Returns new table
  - Does not modify source
  - Returns empty table if source is nil
  - Signal_id keys are preserved by reference (Factorio pattern)

  EXAMPLE:
    original = {[iron_signal] = 10}
    copy = copy_signals(original)
    copy[iron_signal] = 20
    -- original[iron_signal] is still 10
--]]
function signal_utils.copy_signals(source)
  if not source then return {} end

  local copy = {}
  for signal_id, count in pairs(source) do
    if signal_id and count then
      copy[signal_id] = count
    end
  end

  return copy
end

--[[
  Compare two signal tables for equality

  Returns true if both tables contain exactly the same signals with same values.

  @param a table: First signal table
  @param b table: Second signal table
  @return boolean: True if tables are identical

  BEHAVIOR:
  - Deep comparison of signal values
  - Handles nil (nil == nil is true, nil != table is false)
  - Ignores zero values (treats as absent)
  - Order-independent

  EXAMPLE:
    a = {[iron_signal] = 10, [copper_signal] = 5}
    b = {[copper_signal] = 5, [iron_signal] = 10}
    signals_equal(a, b)  -- true (order doesn't matter)

    c = {[iron_signal] = 10}
    signals_equal(a, c)  -- false (different signals)
--]]
function signal_utils.signals_equal(a, b)
  -- Both nil = equal
  if not a and not b then return true end

  -- One nil, one table = not equal
  if not a or not b then return false end

  -- Build normalized sets (ignore zero values)
  local normalized_a = {}
  local normalized_b = {}

  for signal_id, count in pairs(a) do
    if signal_id and count and count ~= 0 then
      local key = signal_to_key(signal_id)
      normalized_a[key] = count
    end
  end

  for signal_id, count in pairs(b) do
    if signal_id and count and count ~= 0 then
      local key = signal_to_key(signal_id)
      normalized_b[key] = count
    end
  end

  -- Compare counts
  local count_a = 0
  local count_b = 0

  for _ in pairs(normalized_a) do count_a = count_a + 1 end
  for _ in pairs(normalized_b) do count_b = count_b + 1 end

  if count_a ~= count_b then return false end

  -- Compare values
  for key, value_a in pairs(normalized_a) do
    if normalized_b[key] ~= value_a then
      return false
    end
  end

  return true
end

--[[
  Reset signal table to empty (MUTATES table)

  Clears all signals from the table, making it empty.

  @param signals table: Signal table to clear (modified in place)

  BEHAVIOR:
  - Mutates input table
  - Removes all keys
  - Handles nil gracefully (no-op)

  EXAMPLE:
    signals = {[iron_signal] = 10, [copper_signal] = 5}
    clear_signals(signals)
    -- signals is now {}
--]]
function signal_utils.clear_signals(signals)
  if not signals then return end

  -- Clear all keys
  for key in pairs(signals) do
    signals[key] = nil
  end
end

--[[
  Count number of unique signals in table

  Returns the number of non-zero signals present.

  @param signals table: Signal table to count
  @return number: Count of unique signals (0 if nil or empty)

  BEHAVIOR:
  - Returns 0 for nil input
  - Ignores zero values
  - Counts unique signal_ids only

  EXAMPLE:
    signals = {[iron_signal] = 10, [copper_signal] = 5, [coal_signal] = 0}
    count = count_signals(signals)
    -- count = 2 (coal_signal ignored because value is 0)
--]]
function signal_utils.count_signals(signals)
  if not signals then return 0 end

  local count = 0
  for signal_id, value in pairs(signals) do
    if signal_id and value and value ~= 0 then
      count = count + 1
    end
  end

  return count
end

--------------------------------------------------------------------------------
-- INLINE TESTS (for development validation)
--------------------------------------------------------------------------------

--[[
  INLINE TEST SUITE

  These tests demonstrate expected behavior and can be manually verified
  by calling signal_utils.run_tests() from the Factorio console:

  /c require("lib.signal_utils").run_tests()

  All tests should print "PASS" to console.
--]]
function signal_utils.run_tests()
  local function assert_equal(actual, expected, test_name)
    if actual == expected then
      game.print("[signal_utils] PASS: " .. test_name)
    else
      game.print("[signal_utils] FAIL: " .. test_name ..
                 " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
  end

  -- Create test signals
  local iron = {type = "item", name = "iron-plate"}
  local copper = {type = "item", name = "copper-plate"}
  local coal = {type = "item", name = "coal"}

  -- TEST: add_signals
  local target = {[iron] = 10, [copper] = 5}
  local source = {[iron] = 15, [coal] = 20}
  signal_utils.add_signals(target, source)
  assert_equal(target[iron], 25, "add_signals: sum existing")
  assert_equal(target[copper], 5, "add_signals: preserve target-only")
  assert_equal(target[coal], 20, "add_signals: add source-only")

  -- TEST: merge_signals (sum values)
  local red = {[iron] = 10, [copper] = 30}
  local green = {[iron] = 25, [coal] = 15}
  local merged = signal_utils.merge_signals(red, green)
  assert_equal(merged[iron], 35, "merge_signals: sum value for iron")
  assert_equal(merged[copper], 30, "merge_signals: red-only copper")
  assert_equal(merged[coal], 15, "merge_signals: green-only coal")

  -- TEST: copy_signals
  local original = {[iron] = 100}
  local copy = signal_utils.copy_signals(original)
  copy[iron] = 200
  assert_equal(original[iron], 100, "copy_signals: original unchanged")
  assert_equal(copy[iron], 200, "copy_signals: copy modified")

  -- TEST: signals_equal
  local a = {[iron] = 10, [copper] = 5}
  local b = {[copper] = 5, [iron] = 10}
  local c = {[iron] = 10}
  assert_equal(signal_utils.signals_equal(a, b), true, "signals_equal: same signals different order")
  assert_equal(signal_utils.signals_equal(a, c), false, "signals_equal: different signals")
  assert_equal(signal_utils.signals_equal(nil, nil), true, "signals_equal: both nil")

  -- TEST: count_signals
  local signals = {[iron] = 10, [copper] = 5, [coal] = 0}
  assert_equal(signal_utils.count_signals(signals), 2, "count_signals: ignore zero values")
  assert_equal(signal_utils.count_signals(nil), 0, "count_signals: nil returns 0")
  assert_equal(signal_utils.count_signals({}), 0, "count_signals: empty returns 0")

  -- TEST: clear_signals
  local to_clear = {[iron] = 10, [copper] = 5}
  signal_utils.clear_signals(to_clear)
  assert_equal(signal_utils.count_signals(to_clear), 0, "clear_signals: table is empty")

  game.print("[signal_utils] All tests completed!")
end

return signal_utils

--------------------------------------------------------------------------------
-- circuit_utils.lua
-- Pure utility functions for circuit network operations
--
-- PURPOSE:
--   Provides low-level access to Factorio's circuit network API without
--   knowledge of mod-specific entities or global state. All functions are
--   pure (no side effects except reading/writing circuit signals).
--
-- RESPONSIBILITIES:
--   - Reading signals from entity circuit connectors
--   - Writing signals to entity circuit outputs
--   - Checking circuit connection status
--   - Finding entities on circuit networks
--   - Entity circuit capability validation
--
-- DOES NOT OWN:
--   - Signal table manipulation (see signal_utils.lua)
--   - Entity placement validation (see validation.lua)
--   - Global state access (pure library)
--   - Mod-specific entity logic
--
-- DEPENDENCIES: None (pure library)
--
-- COMPLEXITY: ~200 lines
--------------------------------------------------------------------------------

local circuit_utils = {}

--------------------------------------------------------------------------------
-- ENTITY VALIDATION
--------------------------------------------------------------------------------

--- Validate entity can be used for circuit operations
--- @param entity LuaEntity: Entity to validate
--- @return boolean: True if valid and has circuit connectors
---
--- EDGE CASES:
---   - Returns false if entity is nil
---   - Returns false if entity.valid is false
---   - Returns false if entity doesn't support circuit connections
---
--- TEST CASES:
---   is_valid_circuit_entity(nil) => false
---   is_valid_circuit_entity(destroyed_entity) => false
---   is_valid_circuit_entity(combinator) => true
---   is_valid_circuit_entity(chest) => false (if no circuit connection)
function circuit_utils.is_valid_circuit_entity(entity)
  if not entity then return false end
  if not entity.valid then return false end

  -- Check if entity supports circuit connections
  -- Entities with circuit capability have get_circuit_network method
  return entity.get_circuit_network ~= nil
end

--------------------------------------------------------------------------------
-- SIGNAL READING
--------------------------------------------------------------------------------

--- Read signals from entity circuit connector
--- @param entity LuaEntity: Entity to read from
--- @param wire_connector_id defines.wire_connector_id: Which wire connector (e.g., combinator_input_red)
--- @return table|nil: Signal table {[signal_id] = count} or nil if no connection
---
--- FACTORIO 2.0 API:
---   Uses wire_connector_id (combines wire type + location) instead of separate parameters
---   Examples: defines.wire_connector_id.combinator_input_red, combinator_input_green,
---            combinator_output_red, combinator_output_green, circuit_red, circuit_green
---
---   IMPORTANT: SignalID.type is nil for item signals when reading!
---   When using signal_id.type, default to "item" if nil: (signal_id.type or "item")
---
--- EDGE CASES:
---   - Returns nil if entity is invalid
---   - Returns nil if no circuit network on specified wire connector
---   - Returns empty table if network exists but has no signals
---   - Handles multi-connector entities (combinators, power switches, etc.)
---
--- SIGNAL TABLE FORMAT:
---   {
---     [{type=nil, name="iron-plate"}] = 100,        -- type is nil for items!
---     [{type="virtual", name="signal-A"}] = 50,
---     [{type="fluid", name="water"}] = 25
---   }
---
--- TEST CASES:
---   get_circuit_signals(nil, combinator_input_red) => nil
---   get_circuit_signals(unwired_combinator, combinator_input_red) => nil
---   get_circuit_signals(wired_combinator, combinator_input_red) => {...}
function circuit_utils.get_circuit_signals(entity, wire_connector_id)
  if not circuit_utils.is_valid_circuit_entity(entity) then
    return nil
  end

  -- Get the circuit network for this wire connector (Factorio 2.0 API)
  local circuit_network = entity.get_circuit_network(wire_connector_id)

  if not circuit_network then
    return nil
  end

  -- Get signals from the network
  local signals = circuit_network.signals

  if not signals then
    return {} -- Network exists but no signals
  end

  -- Convert signals array to lookup table
  -- Factorio API returns signals as: {{signal={type="item", name="..."}, count=N}, ...}
  local signal_table = {}
  for _, signal_data in pairs(signals) do
    if signal_data.signal and signal_data.count then
      signal_table[signal_data.signal] = signal_data.count
    end
  end

  return signal_table
end

--[[
  REMOVED FUNCTION: get_merged_input_signals

  This function duplicated Factorio's native API: entity.get_merged_signals()

  Migration guide:
  OLD: local signals = circuit_utils.get_merged_input_signals(entity)

  NEW: Use native Factorio API:
  local merged = entity.get_merged_signals(defines.circuit_connector_id.combinator_input)
  -- Convert format if needed (native returns array, not lookup table):
  local signals = {}
  if merged then
    for _, signal_data in pairs(merged) do
      signals[signal_data.signal] = signal_data.count
    end
  end
--]]

--------------------------------------------------------------------------------
-- CONNECTION STATUS
--------------------------------------------------------------------------------

--- Check if entity has any circuit connection
--- @param entity LuaEntity: Entity to check
--- @return boolean: True if has any circuit connection (red or green, any connector)
---
--- FACTORIO 2.0 API:
---   Checks all common wire_connector_id values to detect any circuit connection
---   Returns true if ANY wire connector has a network
---
--- EDGE CASES:
---   - Returns false if entity is invalid
---   - Returns false if entity doesn't support circuits
---   - Returns true if any wire connector has a network
---
--- TEST CASES:
---   has_circuit_connection(nil) => false
---   has_circuit_connection(unwired_entity) => false
---   has_circuit_connection(red_wired_entity) => true
---   has_circuit_connection(green_wired_entity) => true
function circuit_utils.has_circuit_connection(entity)
  if not circuit_utils.is_valid_circuit_entity(entity) then
    return false
  end

  -- Check all common wire connector IDs (Factorio 2.0 API)
  local wire_connector_ids = {
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green,
    defines.wire_connector_id.combinator_input_red,
    defines.wire_connector_id.combinator_input_green,
    defines.wire_connector_id.combinator_output_red,
    defines.wire_connector_id.combinator_output_green,
  }

  for _, wire_connector_id in pairs(wire_connector_ids) do
    local circuit_network = entity.get_circuit_network(wire_connector_id)
    if circuit_network then
      return true
    end
  end

  return false
end

--[[
  REMOVED FUNCTION: get_connected_entities

  This function was non-functional (returned empty array).
  LuaCircuitNetwork does not have a connected_entities property.

  Migration guide:
  OLD: local entities = circuit_utils.get_connected_entities(network)

  NEW: Use native Factorio API on entities:
  local connected = entity.circuit_connected_entities
  -- Returns: {red = {array of entities}, green = {array of entities}}

  for _, e in pairs(connected.red or {}) do
    -- Process red wire connected entities
  end
  for _, e in pairs(connected.green or {}) do
    -- Process green wire connected entities
  end
--]]

--------------------------------------------------------------------------------
-- UTILITY HELPERS
--------------------------------------------------------------------------------

--- Get number of unique signals on entity's circuit network
--- @param entity LuaEntity: Entity to check
--- @param wire_connector_id defines.wire_connector_id: Which wire connector to check
--- @return number: Count of unique signals
---
--- FACTORIO 2.0 API:
---   Requires specific wire_connector_id (e.g., combinator_input_red)
---
--- EDGE CASES:
---   - Returns 0 if entity is invalid
---   - Returns 0 if no circuit connection
---
--- TEST CASES:
---   get_signal_count(nil, combinator_input_red) => 0
---   get_signal_count(combinator, combinator_input_red) => 5 (if 5 signals present)
function circuit_utils.get_signal_count(entity, wire_connector_id)
  local signals = circuit_utils.get_circuit_signals(entity, wire_connector_id)
  if not signals then return 0 end

  local count = 0
  for _ in pairs(signals) do
    count = count + 1
  end

  return count
end

--- Check if entity has any circuit connections (red or green)
--- @param entity LuaEntity: Entity to check
--- @return boolean: True if has any circuit connection
---
--- NOTE: This is an alias for has_circuit_connection() for backwards compatibility
---
--- TEST CASES:
---   has_any_circuit_connection(nil) => false
---   has_any_circuit_connection(unwired) => false
---   has_any_circuit_connection(red_wired) => true
---   has_any_circuit_connection(green_wired) => true
function circuit_utils.has_any_circuit_connection(entity)
  return circuit_utils.has_circuit_connection(entity)
end

--------------------------------------------------------------------------------
-- EXPORT MODULE
--------------------------------------------------------------------------------

return circuit_utils

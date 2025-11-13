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
--- @param wire_type defines.wire_type: RED or GREEN
--- @param connector_id defines.circuit_connector_id: Which connector (default: combinator_input)
--- @return table|nil: Signal table {[signal_id] = count} or nil if no connection
---
--- EDGE CASES:
---   - Returns nil if entity is invalid
---   - Returns nil if no circuit network on specified wire
---   - Returns empty table if network exists but has no signals
---   - Handles multi-connector entities (combinators, power switches, etc.)
---
--- SIGNAL TABLE FORMAT:
---   {
---     [{type="item", name="iron-plate"}] = 100,
---     [{type="virtual", name="signal-A"}] = 50
---   }
---
--- TEST CASES:
---   get_circuit_signals(nil, red, input) => nil
---   get_circuit_signals(unwired_combinator, red, input) => nil
---   get_circuit_signals(wired_combinator, red, input) => {...}
function circuit_utils.get_circuit_signals(entity, wire_type, connector_id)
  if not circuit_utils.is_valid_circuit_entity(entity) then
    return nil
  end

  -- Default to combinator input connector if not specified
  connector_id = connector_id or defines.circuit_connector_id.combinator_input

  -- Get the circuit network for this wire type and connector
  local circuit_network = entity.get_circuit_network(wire_type, connector_id)

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

--- Check if entity has circuit connection on specified wire
--- @param entity LuaEntity: Entity to check
--- @param wire_type defines.wire_type: RED or GREEN
--- @return boolean: True if connected
---
--- EDGE CASES:
---   - Returns false if entity is invalid
---   - Returns false if entity doesn't support circuits
---   - Returns true only if network exists and is connected
---
--- TEST CASES:
---   has_circuit_connection(nil, red) => false
---   has_circuit_connection(unwired_entity, red) => false
---   has_circuit_connection(wired_entity, red) => true
function circuit_utils.has_circuit_connection(entity, wire_type)
  if not circuit_utils.is_valid_circuit_entity(entity) then
    return false
  end

  -- Check all possible connector IDs (some entities have multiple)
  -- Most entities use combinator_input/output, but check common ones
  local connector_ids = {
    defines.circuit_connector_id.combinator_input,
    defines.circuit_connector_id.combinator_output,
    defines.circuit_connector_id.constant_combinator,
    defines.circuit_connector_id.container,
    defines.circuit_connector_id.inserter,
  }

  for _, connector_id in pairs(connector_ids) do
    local circuit_network = entity.get_circuit_network(wire_type, connector_id)
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
--- @param wire_type defines.wire_type: RED or GREEN
--- @return number: Count of unique signals
---
--- EDGE CASES:
---   - Returns 0 if entity is invalid
---   - Returns 0 if no circuit connection
---
--- TEST CASES:
---   get_signal_count(nil, red) => 0
---   get_signal_count(combinator, red) => 5 (if 5 signals present)
function circuit_utils.get_signal_count(entity, wire_type)
  local signals = circuit_utils.get_circuit_signals(entity, wire_type)
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
--- TEST CASES:
---   has_any_circuit_connection(nil) => false
---   has_any_circuit_connection(unwired) => false
---   has_any_circuit_connection(red_wired) => true
---   has_any_circuit_connection(green_wired) => true
function circuit_utils.has_any_circuit_connection(entity)
  return circuit_utils.has_circuit_connection(entity, defines.wire_type.red) or
         circuit_utils.has_circuit_connection(entity, defines.wire_type.green)
end

--------------------------------------------------------------------------------
-- EXPORT MODULE
--------------------------------------------------------------------------------

return circuit_utils

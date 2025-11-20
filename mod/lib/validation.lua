-- validation.lua
-- Entity placement validation and player feedback
--
-- ⚠️ ARCHITECTURAL NOTE (2025-11-13): SUPERSEDED BY TileBuildabilityRule ⚠️
--
-- This module is now OPTIONAL and NOT RECOMMENDED for primary placement validation.
-- Factorio's native TileBuildabilityRule system (defined in entity prototypes) is
-- superior for performance, game integration, and simplicity.
--
-- See: docs/tile_buildability_approach.md for full rationale
--
-- This module is retained ONLY for:
--   - Optional custom error messages (future enhancement)
--   - Reference implementation
--   - Backward compatibility if needed
--
-- RECOMMENDED APPROACH:
--   Use tile_buildability_rules in entity prototypes:
--   - Mission Control: colliding_tiles = {"space-platform-foundation"}
--   - Receiver: required_tiles = {"space-platform-foundation"}
--   - Logistics Combinator: no restrictions
--
-- This module validates entity placement and provides user feedback for errors.
-- It is a pure library module with NO global state access.
--
-- Original Responsibilities (NOW HANDLED BY TILE RULES):
--   - Validate Mission Control placement (planet-only)
--   - Validate Receiver Combinator placement (platform-only)
--   - Validate Logistics Combinator placement (anywhere)
--   - Refund entity items when placement is invalid
--   - Show placement error messages to players
--
-- Dependencies: None (pure library)
-- Module Type: lib/ (stateless, pure functions)

local validation = {}

-- =============================================================================
-- CONSTANTS
-- =============================================================================

-- Entity names that require validation
local ENTITY_NAMES = {
  LOGISTICS_COMBINATOR = "logistics-combinator"
}

-- Placement requirements
local PLACEMENT_RULES = {
  [ENTITY_NAMES.MISSION_CONTROL] = "planet_only",
  [ENTITY_NAMES.RECEIVER_COMBINATOR] = "platform_only",
  [ENTITY_NAMES.LOGISTICS_COMBINATOR] = "anywhere"
}

-- Locale keys for error messages
local LOCALE_KEYS = {
  MC_PLANET_ONLY = "message.mc-planet-only",
  RECEIVER_PLATFORM_ONLY = "message.receiver-platform-only",
  PLACEMENT_INVALID = "message.placement-invalid"
}

-- =============================================================================
-- INTERNAL HELPER FUNCTIONS
-- =============================================================================

--- Check if a surface is a space platform
-- @param surface LuaSurface: Surface to check
-- @return boolean: True if surface is a platform
local function is_platform_surface(surface)
  if not surface or not surface.valid then
    return false
  end

  -- In Factorio 2.0+, platforms have a .platform property
  return surface.platform ~= nil
end

--- Check if a surface is a planet (not a platform)
-- @param surface LuaSurface: Surface to check
-- @return boolean: True if surface is a planet
local function is_planet_surface(surface)
  return not is_platform_surface(surface)
end

--- Get the item name from an entity
-- @param entity LuaEntity: Entity to get item from
-- @return string|nil: Item name or nil
local function get_entity_item_name(entity)
  if not entity or not entity.valid then
    return nil
  end

  -- Most entities have their item as entity.name
  -- For special cases, check prototype
  if entity.prototype and entity.prototype.items_to_place_this then
    local items = entity.prototype.items_to_place_this
    if items and #items > 0 then
      return items[1].name
    end
  end

  -- Fallback to entity name
  return entity.name
end

--- Get the quality of an entity
-- @param entity LuaEntity: Entity to get quality from
-- @return string: Quality name (default: "normal")
local function get_entity_quality(entity)
  if not entity or not entity.valid then
    return "normal"
  end

  -- Check if entity has quality property (Factorio 2.0+)
  if entity.quality then
    return entity.quality.name
  end

  return "normal"
end

-- =============================================================================
-- PUBLIC API FUNCTIONS
-- =============================================================================

--- Check if surface allows entity type
-- Generic function to check if an entity can be placed on a surface
-- @param surface LuaSurface: Surface to check
-- @param entity_name string: Entity name to validate
-- @return boolean: True if placement is valid
-- @return string: Locale key for error message (or empty string if valid)
function validation.can_place_on_surface(surface, entity_name)
  if not surface or not surface.valid then
    return false, LOCALE_KEYS.PLACEMENT_INVALID
  end

  local rule = PLACEMENT_RULES[entity_name]

  -- If no rule defined, allow placement anywhere
  if not rule then
    return true, ""
  end

  if rule == "planet_only" then
    if is_platform_surface(surface) then
      return false, LOCALE_KEYS.MC_PLANET_ONLY
    end
  elseif rule == "platform_only" then
    if is_planet_surface(surface) then
      return false, LOCALE_KEYS.RECEIVER_PLATFORM_ONLY
    end
  elseif rule == "anywhere" then
    return true, ""
  end

  return true, ""
end

--- Validate Mission Control placement (planet-only)
-- @param entity LuaEntity: MC building entity
-- @param player LuaPlayer|nil: Player who placed (nil if robot)
-- @return boolean: True if valid placement
function validation.validate_mission_control_placement(entity, player)
  if not entity or not entity.valid then
    return false
  end

  local surface = entity.surface
  local valid, message_key = validation.can_place_on_surface(surface, ENTITY_NAMES.MISSION_CONTROL)

  if not valid then
    -- Show error to player if present
    if player and player.valid then
      validation.show_placement_error(player, message_key, entity.position)
    end

    -- Refund and destroy
    validation.refund_entity(entity, player, nil)
    return false
  end

  return true
end

--- Validate Receiver Combinator placement (platform-only)
-- @param entity LuaEntity: Receiver combinator entity
-- @param player LuaPlayer|nil: Player who placed (nil if robot)
-- @return boolean: True if valid placement
function validation.validate_receiver_placement(entity, player)
  if not entity or not entity.valid then
    return false
  end

  local surface = entity.surface
  local valid, message_key = validation.can_place_on_surface(surface, ENTITY_NAMES.RECEIVER_COMBINATOR)

  if not valid then
    -- Show error to player if present
    if player and player.valid then
      validation.show_placement_error(player, message_key, entity.position)
    end

    -- Refund and destroy
    validation.refund_entity(entity, player, nil)
    return false
  end

  return true
end

--- Validate Logistics Combinator placement (anywhere)
-- @param entity LuaEntity: Logistics combinator entity
-- @param player LuaPlayer|nil: Player who placed (nil if robot)
-- @return boolean: True if valid placement (always true for logistics combinator)
function validation.validate_logistics_combinator_placement(entity, player)
  -- Logistics combinator can be placed anywhere
  if not entity or not entity.valid then
    return false
  end

  return true
end

--- Refund entity items and destroy entity
-- Handles both player placement and robot placement
-- @param entity LuaEntity: Entity to refund and destroy
-- @param player LuaPlayer|nil: Player to refund to (nil if robot placed)
-- @param robot_inventory LuaInventory|nil: Robot inventory to return items to
function validation.refund_entity(entity, player, robot_inventory)
  if not entity or not entity.valid then
    return
  end

  local item_name = get_entity_item_name(entity)
  local quality = get_entity_quality(entity)
  local position = entity.position
  local surface = entity.surface

  -- Destroy the entity first (before refunding)
  entity.destroy({raise_destroy = false})

  -- If no item to refund, we're done
  if not item_name then
    return
  end

  -- Refund to player if present
  if player and player.valid then
    local inserted = player.insert({name = item_name, count = 1, quality = quality})

    -- If player inventory full, spill to ground
    if inserted == 0 then
      surface.spill_item_stack(
        position,
        {name = item_name, count = 1, quality = quality},
        true, -- enable_looted
        nil,  -- force
        false -- allow_belts
      )
    end
  -- Refund to robot inventory if provided
  elseif robot_inventory and robot_inventory.valid then
    local inserted = robot_inventory.insert({name = item_name, count = 1, quality = quality})

    -- If robot inventory full, spill to ground
    if inserted == 0 then
      surface.spill_item_stack(
        position,
        {name = item_name, count = 1, quality = quality},
        false, -- enable_looted
        nil,   -- force
        false  -- allow_belts
      )
    end
  else
    -- No player or robot - spill directly to ground
    surface.spill_item_stack(
      position,
      {name = item_name, count = 1, quality = quality},
      true,  -- enable_looted
      nil,   -- force
      false  -- allow_belts
    )
  end
end

--- Show placement error message to player
-- @param player LuaPlayer: Player to notify
-- @param message_key string: Locale key for message
-- @param position MapPosition: Where to show flying text
function validation.show_placement_error(player, message_key, position)
  if not player or not player.valid then
    return
  end

  -- Create flying text at entity position
  player.create_local_flying_text({
    text = {message_key},
    position = position,
    color = {r = 1, g = 0.3, b = 0.3}, -- Red color for error
    time_to_live = 120, -- 2 seconds
    speed = 1
  })

  -- Also show in console for visibility
  player.print({"", "[color=red]", {message_key}, "[/color]"})
end

--- Generic validation dispatcher
-- Validates any mod entity and returns success status
-- @param entity LuaEntity: Entity to validate
-- @param player LuaPlayer|nil: Player who placed
-- @return boolean: True if placement is valid
function validation.validate_entity_placement(entity, player)
  if not entity or not entity.valid then
    return false
  end

  local entity_name = entity.name

  if entity_name == ENTITY_NAMES.MISSION_CONTROL then
    return validation.validate_mission_control_placement(entity, player)
  elseif entity_name == ENTITY_NAMES.RECEIVER_COMBINATOR then
    return validation.validate_receiver_placement(entity, player)
  elseif entity_name == ENTITY_NAMES.LOGISTICS_COMBINATOR then
    return validation.validate_logistics_combinator_placement(entity, player)
  end

  -- Unknown entity - allow placement
  return true
end

-- =============================================================================
-- TEST CASES (for development/debugging)
-- =============================================================================

--[[
UNIT TEST EXAMPLES:

Test 1: Mission Control on planet surface
  - Setup: Create MC entity on nauvis
  - Expected: validate_mission_control_placement returns true

Test 2: Mission Control on platform
  - Setup: Create MC entity on space platform
  - Expected: validate_mission_control_placement returns false, entity destroyed

Test 3: Receiver on platform
  - Setup: Create receiver entity on space platform
  - Expected: validate_receiver_placement returns true

Test 4: Receiver on planet
  - Setup: Create receiver entity on nauvis
  - Expected: validate_receiver_placement returns false, entity destroyed

Test 5: Logistics combinator anywhere
  - Setup: Create logistics combinator on any surface
  - Expected: validate_logistics_combinator_placement always returns true

Test 6: Robot placement refund
  - Setup: Robot places invalid entity
  - Expected: Item returned to robot inventory

Test 7: Player placement refund (inventory full)
  - Setup: Player with full inventory places invalid entity
  - Expected: Item spilled to ground

Test 8: Quality preservation
  - Setup: Place legendary quality MC on platform
  - Expected: Legendary quality item refunded

Edge Cases:
  - Entity destroyed before validation
  - Invalid player reference
  - Nil robot inventory
  - Unknown entity type
  - Invalid surface
]]

-- =============================================================================
-- EXPORT MODULE
-- =============================================================================

return validation

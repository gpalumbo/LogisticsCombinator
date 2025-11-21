-- Mission Control Mod - Data Migrations
-- Handles data structure migrations between mod versions

local migrations = {}

--- Migrate from version 0.1.2 to 0.2.0
--- Changes:
--- - Adds storage.logistics_choosers table (new logistics chooser combinator)
--- - Adds mode field to chooser data ("each" or "first_only")
--- - Adds injected_tracking to chooser data
--- - Ensures all chooser groups have proper condition structure with wire_filter fields
function migrations.migrate_0_1_2_to_0_2_0()
    log("[Migration] Running migration from 0.1.2 to 0.2.0")

    -- 1. Initialize logistics_choosers table if it doesn't exist
    if not storage.logistics_choosers then
        log("[Migration] Creating storage.logistics_choosers table")
        storage.logistics_choosers = {}
    end

    -- 2. Migrate existing chooser data (if any from dev builds)
    if storage.logistics_choosers then
        for unit_number, chooser_data in pairs(storage.logistics_choosers) do
            log("[Migration] Migrating chooser " .. unit_number)

            -- Add mode field if missing (default to "each")
            if not chooser_data.mode then
                log("[Migration]   Adding mode field (default: 'each')")
                chooser_data.mode = "each"
            end

            -- Add injected_tracking if missing
            if not chooser_data.injected_tracking then
                log("[Migration]   Adding injected_tracking table")
                chooser_data.injected_tracking = {}
            end

            -- Migrate groups to new condition structure
            if chooser_data.groups then
                for i, group in ipairs(chooser_data.groups) do
                    -- Check if this is old format group (no condition field)
                    if not group.condition then
                        log("[Migration]   Migrating group " .. i .. " from old format")
                        -- Old format: {group, signal, value, multiplier, is_active}
                        local old_signal = group.signal
                        local old_value = group.value or 0
                        local old_operator = group.operator or "="

                        -- Create new condition structure
                        group.condition = {
                            left_wire_filter = "both",
                            left_signal = old_signal,
                            operator = old_operator,
                            right_type = "constant",
                            right_value = old_value,
                            right_signal = nil,
                            right_wire_filter = "both"
                        }

                        -- Remove old fields
                        group.signal = nil
                        group.value = nil
                        group.operator = nil

                        -- Ensure other fields exist
                        if group.multiplier == nil then
                            group.multiplier = 1.0
                        end
                        if group.is_active == nil then
                            group.is_active = false
                        end
                    else
                        -- Condition exists, but ensure wire_filter fields exist
                        if not group.condition.left_wire_filter then
                            log("[Migration]   Adding left_wire_filter to group " .. i)
                            group.condition.left_wire_filter = "both"
                        end
                        if not group.condition.right_wire_filter then
                            log("[Migration]   Adding right_wire_filter to group " .. i)
                            group.condition.right_wire_filter = "both"
                        end

                        -- Ensure multiplier and is_active exist
                        if group.multiplier == nil then
                            group.multiplier = 1.0
                        end
                        if group.is_active == nil then
                            group.is_active = false
                        end
                    end
                end
            end
        end
    end

    log("[Migration] Migration from 0.1.2 to 0.2.0 complete")
end

--- Run all necessary migrations based on old and new versions
--- @param old_version string|nil Previous mod version (nil if new install)
--- @param new_version string Current mod version
function migrations.run_migrations(old_version, new_version)
    log("[Migration] Running migrations from " .. tostring(old_version) .. " to " .. new_version)

    -- If this is a new install, no migration needed
    if not old_version then
        log("[Migration] New install detected, skipping migrations")
        return
    end

    -- Parse version strings into comparable numbers
    local function parse_version(version_string)
        if not version_string then return nil end
        local major, minor, patch = version_string:match("(%d+)%.(%d+)%.(%d+)")
        if not major then return nil end
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            string = version_string
        }
    end

    local old_ver = parse_version(old_version)
    local new_ver = parse_version(new_version)

    if not old_ver or not new_ver then
        log("[Migration] WARNING: Could not parse version numbers")
        return
    end

    -- Check if we need to migrate from 0.1.x to 0.2.0
    if (old_ver.major == 0 and old_ver.minor == 1) and
       (new_ver.major == 0 and new_ver.minor == 2) then
        log("[Migration] Detected upgrade from 0.1.x to 0.2.0")
        migrations.migrate_0_1_2_to_0_2_0()
    end

    -- Add more migration paths as needed
    -- Example:
    -- if old_ver < {0, 2, 0} and new_ver >= {0, 3, 0} then
    --     migrations.migrate_0_2_0_to_0_3_0()
    -- end

    log("[Migration] All migrations complete")
end

return migrations

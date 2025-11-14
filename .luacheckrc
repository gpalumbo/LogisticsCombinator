--[[----------------------------------------------------------------------------
    .luacheckrc for Mission Control Mod (Factorio 2.0)

    Luacheck configuration for the Mission Control mod.
    Based on standard Factorio modding practices.
----------------------------------------------------------------------------]]

-- Default settings
std = "lua52c"
quiet = 1 -- Only report warnings and errors
codes = true -- Show warning codes
max_line_length = false -- Disabled (we manage this in code reviews)
max_code_line_length = false
max_string_line_length = false
max_comment_line_length = false
max_cyclomatic_complexity = false

-- Ignore common false positives
ignore = {
    "111", -- Setting undefined global variable (false positives for Factorio globals)
    "112", -- Mutating undefined global variable
    "113", -- Accessing undefined global variable
    "211", -- Unused local variable (allow unused vars with _ prefix)
    "212", -- Unused argument
    "213", -- Unused loop variable
    "21._/^_", -- Ignore unused variables starting with underscore
    "43.", -- Shadowing upvalue
    "542", -- Empty if branch (sometimes intentional)
}

-- Globals that should NOT be accessible (security)
not_globals = {
    "coroutine",
    "io",
    "socket",
    "dofile",
    "loadfile",
}

-- Factorio global variables and API
globals = {
    -- Data stage (prototypes)
    "data",
    "mods",
    "settings",

    -- Control stage (runtime)
    "game",
    "script",
    "remote",
    "commands",
    "rcon",
    "rendering",
    "global",

    -- Standard Factorio libraries
    "util",
    "table_size",
    "mod_gui",
    "defines",

    -- Factorio events
    "defines",

    -- Serpent (data serialization)
    "serpent",

    -- Log function
    "log",

    -- Localised strings
    "localised_print",
}

-- Read-only Factorio globals (should not be modified)
read_globals = {
    -- Standard library extensions
    "table",
    "math",
    "string",

    -- Factorio API objects
    "defines",
    "data",
    "mods",
    "settings",
}

-- File-specific rules
files = {}

-- Data stage files (prototypes, data.lua, settings.lua)
files["mod/data*.lua"] = {
    globals = { "data" },
    read_globals = { "util", "mods", "settings", "defines" },
}

files["mod/settings*.lua"] = {
    globals = { "data" },
    read_globals = { "util", "mods", "settings", "defines" },
}

files["mod/prototypes/"] = {
    globals = { "data" },
    read_globals = { "util", "mods", "settings", "defines" },
}

files["mod/data/"] = {
    globals = { "data" },
    read_globals = { "util", "mods", "settings", "defines" },
}

-- Control stage files (control.lua, scripts/, lib/)
files["mod/control.lua"] = {
    globals = { "global", "game", "script", "remote", "commands", "rcon", "rendering" },
    read_globals = { "util", "defines", "log", "serpent", "localised_print", "mod_gui", "table_size" },
}

files["mod/scripts/"] = {
    globals = { "global", "game", "script", "remote", "rendering" },
    read_globals = { "util", "defines", "log", "serpent", "localised_print", "table_size" },
}

-- Library files should be pure (minimal globals)
files["mod/lib/"] = {
    read_globals = { "util", "defines", "log", "table_size", "game", "script" },
    -- Libraries should not access global directly
    globals = {},
    -- Allow _ prefix for intentionally unused parameters
    ignore = { "21._/^_" },
}

-- Exclude files/directories
exclude_files = {
    "**/.git/",
    "**/.trash/",
    "**/.history/",
    "**/node_modules/",
    "**/dist/",
    "**/.vscode/",
    "**/docs/",
    "**/*_nolint*",
}

-- Allow longer lines in specific cases
files["mod/prototypes/"].max_line_length = 200 -- Prototypes can have long data tables

-- Specific overrides for known patterns
files["mod/lib/signal_utils.lua"] = {
    ignore = { "432/target" }, -- Allow shadowing 'target' in specific contexts
}

files["mod/lib/gui_utils.lua"] = {
    globals = { "game" }, -- GUI utils may need to access game for player GUI
}

-- Test files (if you add tests later)
files["**/test*.lua"] = {
    std = "+busted",
    globals = { "describe", "it", "before_each", "after_each", "setup", "teardown" },
}

-- Migration files
files["mod/migrations/"] = {
    globals = { "global", "game", "script" },
    read_globals = { "util", "defines", "log" },
    -- Migrations often have complex logic, relax some rules
    ignore = { "212", "213", "432" },
}

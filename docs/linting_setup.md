# Linting Setup for Mission Control Mod

This document explains how to set up and use code linting for the Mission Control mod.

## What is Luacheck?

**Luacheck** is a static analyzer and linter for Lua. It detects:
- Undefined variables and globals
- Unused variables and parameters
- Shadowing of variables
- Code style issues
- Factorio API misuse (with proper configuration)

## Installation

### Option 1: Via Luarocks (Recommended)

```bash
# Install luarocks first (if not already installed)
# Debian/Ubuntu:
sudo apt install luarocks

# macOS:
brew install luarocks

# Arch Linux:
sudo pacman -S luarocks

# Then install luacheck
luarocks install --local luacheck

# Add to your PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.luarocks/bin:$PATH"
```

### Option 2: Via Package Manager

```bash
# Debian/Ubuntu:
sudo apt install lua-check

# macOS:
brew install luacheck

# Arch Linux:
sudo pacman -S luacheck
```

### Option 3: Via Makefile

```bash
make lint-install
```

## Configuration

The project includes a `.luacheckrc` file that configures luacheck specifically for Factorio 2.0 modding:

- **Factorio globals**: Defines `game`, `script`, `global`, `data`, etc.
- **File-specific rules**: Different rules for data stage vs control stage
- **Library files**: Stricter rules for `mod/lib/` (no global access)
- **Ignore patterns**: Allows `_` prefix for intentionally unused variables

## Usage

### Run Lint Check

```bash
# Standard linting
make lint

# Strict linting (all warnings enabled)
make lint-strict

# Run all CI checks (structure + lint)
make ci
```

### Manual Luacheck

```bash
# Check entire mod directory
luacheck mod/

# Check specific file
luacheck mod/lib/signal_utils.lua

# Check with custom config
luacheck mod/ --config .luacheckrc

# Show only errors (suppress warnings)
luacheck mod/ --only 0

# Verbose output
luacheck mod/ -v
```

## Understanding Warnings

### Common Warning Codes

- **111** - Setting undefined global variable
- **112** - Mutating undefined global variable
- **113** - Accessing undefined global variable
- **211** - Unused local variable
- **212** - Unused argument
- **213** - Unused loop variable
- **311** - Value assigned to a local variable is unused
- **321** - Accessing uninitialized local variable
- **411** - Redefining a local variable
- **412** - Redefining an argument
- **421** - Shadowing a local variable
- **422** - Shadowing an argument
- **423** - Shadowing a loop variable

### Example Output

```
mod/lib/signal_utils.lua:45:1: warning: unused function 'format_signal'
mod/scripts/logistics_combinator/logistics_combinator.lua:12:5: error: undefined global variable 'globa' (typo?)
mod/control.lua:8:1: warning: accessing undefined global 'defines'

Total: 2 warnings / 1 error in 3 files
```

## Fixing Common Issues

### 1. Unused Variables

```lua
-- ❌ Warning: unused variable
local function process_data(value)
    local result = calculate(value)
    return value  -- 'result' is unused!
end

-- ✅ Fix: Use the variable or prefix with _
local function process_data(value)
    local result = calculate(value)
    return result
end

-- ✅ Or mark as intentionally unused
local function process_data(value)
    local _result = calculate(value)  -- _ prefix = intentional
    return value
end
```

### 2. Undefined Globals

```lua
-- ❌ Error: undefined global 'globa'
function on_init()
    globa.data = {}  -- Typo!
end

-- ✅ Fix: Correct spelling
function on_init()
    storage.data = {}
end
```

### 3. Shadowing Variables

```lua
-- ❌ Warning: shadowing variable
local data = {1, 2, 3}
for _, data in pairs(data) do  -- Shadows outer 'data'
    print(data)
end

-- ✅ Fix: Use different name
local data = {1, 2, 3}
for _, value in pairs(data) do
    print(value)
end
```

### 4. Lib Files Accessing Global

```lua
-- In mod/lib/signal_utils.lua
-- ❌ Error: lib files should not access global directly
function get_stored_signals()
    return storage.signals  -- Violates pure function principle!
end

-- ✅ Fix: Pass data as parameter
function get_stored_signals(signals_data)
    return signals_data
end

-- In calling code (mod/scripts/logistics_combinator/logistics_combinator.lua)
local signals = signal_utils.get_stored_signals(storage.signals)
```

## File-Specific Rules

### Data Stage Files (`data.lua`, `prototypes/`, `settings.lua`)
- Can access: `data`, `mods`, `settings`, `util`, `defines`
- Cannot access: `game`, `script`, `global` (not available in data stage)

### Control Stage Files (`control.lua`, `scripts/`)
- Can access: `game`, `script`, `global`, `remote`, `rendering`
- Can access: `util`, `defines`, `log`, `serpent`

### Library Files (`lib/`)
- Should be pure functions (no global state)
- Can read from parameters: `util`, `defines`, `game` (read-only)
- Cannot write to: `global` (pass data via parameters)

## Ignoring Warnings

### In Code

```lua
-- Ignore specific warning on next line
-- luacheck: ignore 211
local unused_variable = 5

-- Ignore multiple warnings
-- luacheck: ignore 211 212
local function foo(unused_arg)
    local unused_var = 1
end

-- Push/pop ignore rules
-- luacheck: push ignore 211
local a, b, c = 1, 2, 3
-- luacheck: pop
```

### In `.luacheckrc`

Already configured for common Factorio patterns. Edit `.luacheckrc` if needed:

```lua
-- Add custom ignores
ignore = {
    "111/__",  -- Ignore globals starting with __
    "21._/^_", -- Ignore unused vars starting with _
}

-- Add custom globals
globals = {
    "my_custom_global",
}
```

## Integration with VS Code

Install the **Lua** extension by sumneko and create `.vscode/settings.json`:

```json
{
    "Lua.diagnostics.enable": true,
    "Lua.diagnostics.globals": [
        "game", "script", "global", "defines", "data",
        "remote", "commands", "settings", "mods", "util"
    ],
    "Lua.runtime.version": "Lua 5.2",
    "Lua.workspace.library": [
        "/path/to/factorio/data/core/lualib"
    ]
}
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/lint.yml`:

```yaml
name: Lua Lint

on: [push, pull_request]

jobs:
  luacheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Luacheck
        run: |
          sudo apt-get update
          sudo apt-get install -y lua-check

      - name: Run Lint
        run: make ci
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Run linting before commit

echo "Running luacheck..."
make lint

if [ $? -ne 0 ]; then
    echo "❌ Lint failed! Fix errors before committing."
    exit 1
fi

echo "✓ Lint passed"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Best Practices

1. **Run lint frequently** - Use `make lint` before commits
2. **Fix errors first** - Address errors before warnings
3. **Don't ignore blindly** - Understand warnings before suppressing
4. **Keep libs pure** - Library functions shouldn't access global
5. **Use `_` prefix** - For intentionally unused variables
6. **Document ignores** - Explain why you're ignoring a warning

## Troubleshooting

### "luacheck: command not found"

```bash
# Check installation
which luacheck

# If not found, install via:
make lint-install
# or
sudo apt install lua-check
```

### "Configuration file not found"

```bash
# Ensure .luacheckrc exists in project root
ls -la .luacheckrc

# Run from project root directory
cd /path/to/FactorioSignals
make lint
```

### Too Many Warnings

```bash
# Start with errors only
luacheck mod/ --only 0

# Gradually enable warning levels
luacheck mod/ --only 0 1 2
```

## Resources

- [Luacheck Documentation](https://luacheck.readthedocs.io/)
- [Factorio Modding Reference](https://lua-api.factorio.com/)
- [Nexela's Factorio Luacheck Config](https://github.com/Nexela/Factorio-luacheckrc)
- [Lua 5.2 Reference Manual](https://www.lua.org/manual/5.2/)

Creating a FACTORIO mod called mission-control.

Requirements for the mod are @docs/spec.md
Maintain currect activity in @docs/todo.md
Code snippets defined when considering feasibilty options are in @docs/implmentation_hints.md, When planning you need to look at these and take them into consideration.

**🚨 CRITICAL: Module Responsibility Matrix 🚨**
Ensure proper API usage is strictly adhered to.  
- use @docs\flib_api_reference.md to find premade utilities
- Use Context7 to view "Factorio Lua API"  also use 
- Use https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua
VERY IMPORATANT: ALWAYS MAKE SURE YOU ARE USING 2.0 APIs.  I wastes time and gets everyone upset when you use older apis!

**🚨 CRITICAL: Module Responsibility Matrix 🚨**
Before writing ANY code, consult @docs/module_responsibility_matrix.md
This defines EXACTLY where each function belongs (lib/ vs scripts/, which module).
Use the decision tree to determine correct placement for new functions.

## File Structure (Actual)
```
mod/
├── info.json
├── thumbnail.png
├── data.lua
├── control.lua
├── lib/                    # Stateless utility libraries
│   ├── signal_utils.lua
│   ├── circuit_utils.lua
│   ├── platform_utils.lua
│   ├── logistics_utils.lua
│   ├── logistics_injection.lua
│   ├── gui_utils.lua
│   ├── gui/
│   │   ├── gui_circuit_inputs.lua
│   │   └── gui_entity.lua
│   └── validation.lua
├── scripts/               # Stateful entity logic
│   ├── globals.lua       # Global state management
│   ├── migrations.lua
│   ├── logistics_combinator/
│   │   ├── logistics_combinator.lua  # Core functionality
│   │   ├── gui.lua                   # GUI handling
│   │   └── control.lua               # Event handling
│   └── logistics_chooser_combinator/
│       ├── logistics_chooser_combinator.lua  # Core functionality
│       ├── gui.lua                   # GUI handling
│       └── control.lua               # Event handling
├── locale/
│   └── en/
│       └── mission-control.cfg
├── prototypes/
│   ├── custom-input.lua
│   ├── technology/
│   │   └── technologies.lua
│   ├── entity/
│   │   ├── logistics_combinator.lua
│   │   └── logistics_chooser_combinator.lua
│   ├── item/
│   │   ├── logistics_combinator.lua
│   │   └── logistics_chooser_combinator.lua
│   └── recipe/
│       ├── logistics_combinator.lua
│       └── logistics_chooser_combinator.lua
└── graphics/
    └── entities/
        ├── logistics-combinator.png
        ├── logistocs_combinator_icon.png
        ├── logistics-chooser-combinator.png
        └── logistics_chooser_combinator_icon.png
```

Important Process Rules:
1. All implementation files must go under the mod/ directory and follow the File Structure above.
2. Claude implementaion specs, feature specs, and todos should go under docs/
3. Make/git/precommit hooks and otehr SDLC or development infrastructure may live in the root directory.
4. Plan before you code.  Write out the feature plan to a @docs/<feature>_todo.md and add a line to the @docs/todo.md referencing this new file.

Important Coding rules:
1. Keep code well organized.  Each entity type should have it's own file, and common code should be a shared utility file.
2. .lua/.java/.py Code files should not exceed 750-900 lines.  Break it up into mutliple modules.  (Single JSON ,XML or data files that can't be readily broken apart should be in .json .xml .csv files respectively and imported as such)
3. Utilize in-line documentation heavily, and keep to BEST coding practices.



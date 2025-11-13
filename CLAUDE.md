Creating a FACTORIO mod called mission-control.

Requirements for the mod are @docs/spec.md
Maintain currect activity in @docs/todo.md 
Code snippets defined when considering feasibilty options are in @docs/implmentation_hints.md, When planning you need to look at these and take them into consideration.

## File Structure
```
docs/
├── spec.md
mod/
├── info.json
├── changelog.txt
├── thumbnail.png (optional, 144x144)
├── data.lua
├── control.lua
├── locale/
│   └── en/
│       └── mission-control.cfg
├── prototypes/
│   ├── technology.lua
│   ├── entity.lua
│   ├── item.lua
│   └── recipe.lua
└── graphics/
│   ├── entity/
│   │   ├── mission-control/
│   │   │   ├── mission-control-base.png
│   │   │   ├── mission-control-base-hr.png
│   │   │   ├── mission-control-shadow.png
│   │   │   ├── mission-control-shadow-hr.png
│   │   │   ├── mission-control-antenna.png
│   │   │   ├── mission-control-antenna-hr.png
│   │   │   ├── mission-control-leds.png
│   │   │   └── mission-control-remnants.png
│   │   ├── receiver-combinator/
│   │   │   ├── receiver-combinator-base.png
│   │   │   ├── receiver-combinator-base-hr.png
│   │   │   ├── receiver-combinator-dish.png
│   │   │   ├── receiver-combinator-dish-hr.png
│   │   │   └── ...
│   │   └── logistics-combinator/
│   │       ├── logistics-combinator-base.png
│   │       ├── logistics-combinator-base-hr.png
│   │       └── ...
│   ├── icons/
│   │   ├── mission-control-building.png
│   │   ├── receiver-combinator.png
│   │   └── logistics-combinator.png
│   ├── technology/
│   │   ├── mission-control.png
│   │   └── logistics-circuit-control.png
│   └── gui/
│       └── ...
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



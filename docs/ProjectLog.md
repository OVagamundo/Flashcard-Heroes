# Flashcard Heroes - Project Log

This document tracks the development of the Flashcard Heroes MVP, explaining each step in a didactic way.

---
## Step 1: Foundational Data Scripts

### What We Did
We just created six GDScript files in the `res://scripts/` directory. These scripts don't create anything visible in the game yet. Instead, they define the **data structures**, or "blueprints," for all the core concepts in our project.

### Didactic Explanation

**Why start with data?**
Our project architecture is based on the principle of **Separation of Data and View**. This means the information about a game object (like a unit's stats) is stored completely separately from its visual representation on screen. These scripts are the "data" part. This is a powerful concept that keeps code organized and easier to manage.

**Key Concepts Introduced:**

1.  **`extends Resource`**: All our scripts inherit from `Resource`. In Godot, a Resource is a special object designed to hold data. They are lightweight, can be saved to disk as `.tres` files, and are easily shared. Think of them as custom data containers.

2.  **`class_name`**: This keyword turns our script into a new, custom "type" within Godot. For example, `class_name GachaBallDefinition` means we can now create variables of type `GachaBallDefinition` in other scripts, and Godot will understand what that is. It also allows us to create new resources of this type directly in the editor.

3.  **`@export`**: This annotation makes a variable visible and editable in the Godot Inspector. This is incredibly useful for creating our `.tres` data files later, as we can just fill in the values without writing any code.

**Breakdown of Each Script:**

*   **`GachaBallDefinition.gd`**: This is the **template** or **blueprint** for a *type* of unit or item. It holds static data that is the same for all "Tier 1 Warriors," for example: their name, icon, tier, etc.
*   **`GachaBallInstance.gd`**: This represents a **single, unique copy** of a GachaBall. If you have three "Tier 1 Warriors," you will have three `GachaBallInstance` resources, each with its own unique ID (`ball_uuid`). This script tracks data that can change, like what items are equipped.
*   **`RunState.gd`**: This holds all the data for a player's entire run that needs to persist between battles, most importantly the `run_inventory`.
*   **`MergeRecipe.gd`**: Defines the rules for what happens when you combine two GachaBalls.
*   **`FlashcardDeckDefinition.gd` & `ConditionDefinition.gd`**: These are placeholders for future systems, but creating them now establishes the full data foundation.

### Summary
We've laid the complete data foundation for our game. With these "blueprints" in place, we are now ready to create the specific data files (the `.tres` resources) that will define every unit and item in our MVP.

---
## Step 2: Core Game Data Resources

### What We Did
We created thirteen `.tres` files and organized them into subdirectories within `res://resources/`. These files define all the specific units, items, and merge combinations for our MVP.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **`.tres` Files (Text-based Resources)**: If the `.gd` scripts from Step 1 were the *blueprints*, these `.tres` files are the *filled-out forms*. Each `.tres` file is a saved instance of a `Resource` script. For example, `UnitTier1A.tres` is an instance of our `GachaBallDefinition.gd` script, with all its `@export` variables (like `id`, `tier`, `icon`) filled in with specific values.

2.  **Data-Driven Design**: This is the core benefit of our approach. We can now add new units, items, or recipes to the game simply by creating new `.tres` files and editing them in the Godot Inspector. We don't need to write any new code. This makes balancing the game and adding content much faster and less error-prone.

3.  **`[ext_resource]` and `[resource]`**: Look inside any `.tres` file. You'll see it's quite readable.
    *   `[ext_resource]` defines external files that this resource depends on. The first line always points to the script (`GachaBallDefinition.gd`) that defines its structure. Subsequent lines can point to assets like our `.png` textures.
    *   `[resource]` is where the actual data is stored, matching the `@export` variables from the script.

4.  **`@tool` in Action**: The `@tool` keyword we added to our definition scripts in Step 1 is what makes this possible. It tells the Godot editor how to read our script and display its `@export` variables in the Inspector, allowing us to edit and save these `.tres` files visually.

### Summary
Our project now has **content**. We have defined a Hero, several tiers of units and items, and the rules for how they combine. The next crucial step is to create the global "manager" scripts (Singletons) that will load all this data into memory when the game starts, making it instantly accessible to any other part of the code.

---
## Step 3: Foundational Autoload Scripts (Singletons)

### What We Did
We created four new scripts (`EventBus`, `UUIDUtils`, `Database`, `SceneManager`) and then edited the `project.godot` file to register them as **Autoloads**.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Autoloads (Singletons)**: An Autoload is a script that Godot automatically loads when the game starts and keeps active for the entire duration of the game. It's globally accessible, meaning any other script can call its functions without needing a direct reference. This is the implementation of the **Singleton** design pattern. It's perfect for "manager" type scripts that need to coordinate things across the whole game.

2.  **Event-Driven Architecture**: Our `EventBus.gd` is the heart of this architecture. It contains nothing but `signal` definitions. Other scripts don't talk to each other directly. Instead, one script *emits* a signal on the EventBus (e.g., `EventBus.emit_signal("start_run_requested")`), and other scripts that are *connected* to that signal will react. This **decouples** our code; the button that starts the run doesn't need to know that a `GameManager` even exists. This makes the system incredibly flexible and easy to modify.

3.  **The `project.godot` file**: This is the master configuration file for your entire Godot project. By editing it, we've programmatically done what you would normally do in the `Project -> Project Settings -> Autoload` tab. We've ensured a clean setup by replacing any old configuration.

**Breakdown of Each Autoload:**

*   **`EventBus`**: The global "radio station" for our game. It allows different systems to communicate without being directly linked.
*   **`UUIDUtils`**: A simple but vital utility. It generates unique IDs for our `GachaBallInstance`s, ensuring we can always tell one from another.
*   **`Database`**: The game's "central library." When the game starts, its `_ready` function runs, loading all our `.tres` files into dictionaries. This provides instant, cached access to all unit and item data without needing to `load()` them from the disk during gameplay.
*   **`SceneManager`**: The game's "stage director." It listens for signals on the `EventBus` and is responsible for switching between the main scenes of the game (like from the Title screen to the Main screen).

### Summary
The core architectural pillars of our project are now in place. We have our data (`.tres` files), a system to load it (`Database`), and a system for communication (`EventBus`). We are now ready to create the high-level logic managers that will use these systems to control the game flow.

---
## Step 4: Core Logic Manager Autoloads

### What We Did
We created four more global manager scripts (`MergeManager`, `AbilityResolver`, `InteractionManager`, `GameManager`) and registered them as Autoloads, updating our `project.godot` file to include the full list of eight singletons.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Single Responsibility Principle**: Notice how each manager has a very specific job. `MergeManager` only knows how to merge things. `InteractionManager` only tracks what the user has clicked on. `GameManager` only manages the persistent state of the run. This is a core software engineering principle. It makes the code much easier to understand, debug, and expand later. If merging is broken, we know to look in `MergeManager.gd` and nowhere else.

2.  **State Management**: We are now managing two different kinds of "state".
    *   **Persistent State (`GameManager`)**: The `GameManager` holds the `RunState` resource. This is the "source of truth" for the player's entire run—their inventory, gold, etc. Actions handled by the `GameManager` are permanent.
    *   **Temporary UI State (`InteractionManager`)**: The `InteractionManager` holds information that is fleeting, like which UI element is currently selected. If the player clicks elsewhere, this state is cleared. It doesn't affect the permanent game data.

**Breakdown of Each Manager:**

*   **`MergeManager`**: The "rulebook" for combining units. It takes two `GachaBallInstance`s, checks the `Database` for a valid `MergeRecipe`, and if found, performs the complex logic of creating a new instance, transferring items, and updating the inventory.
*   **`AbilityResolver`**: A placeholder for a future system. By creating it now, we ensure our architecture has a designated place for ability logic, even if it's empty for the MVP.
*   **`InteractionManager`**: The "short-term memory" for player input. It tracks which `GachaBallView` is selected, facilitating click-and-click or drag-and-drop actions. It communicates the player's *intent* to other systems via the `EventBus`.
*   **`GameManager`**: The "dungeon master" for the overall run. It initiates the run, holds the player's permanent inventory (`run_state`), and listens for inventory actions that should be made permanent (i.e., when the player is in the "Inspect Inventory" modal).

### Summary
All of our non-visual, backend systems are now in place. We have a complete, self-contained logic layer that can manage a game run from start to finish. The next step is to finally start building the visual components—the scenes and UI elements that the player will actually see and interact with.

---
## Step 5: The GachaBallView Scene and Script

### What We Did
We created our first scene, `GachaBallView.tscn`, and its accompanying script, `GachaBallView.gd`. This is the most fundamental visual element of our game, designed to be reused everywhere to display units and items.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Scene as a Reusable Component**: In Godot, scenes are not just for levels or screens. They can be treated as reusable components, much like "prefabs" in other engines. We will be creating instances of `GachaBallView.tscn` dynamically all over our UI.

2.  **"Dumb" Components**: The `GachaBallView` script is intentionally "dumb." It has no knowledge of game rules. It doesn't know what a merge is, what a swap is, or where it's located. Its only jobs are:
    *   Display the data it's given (`set_instance_data`).
    *   Report user input to the global managers (`_gui_input`, `_get_drag_data`).
    *   Visually react to signals from those managers (`_on_view_selected`, `_on_invalid_action_triggered`).
    This follows our **Separation of Data and View** principle. The "smart" logic lives in the managers (like `BattleManager`), and the "dumb" view just does what it's told.

3.  **Input Handling (`_gui_input`)**: This function is automatically called by Godot for `Control` nodes whenever there is mouse or touch input over them. We use it to detect clicks and tell the `InteractionManager` what was clicked.

4.  **Drag and Drop**: Godot has a built-in drag-and-drop system that we're using.
    *   `_get_drag_data()`: When a drag starts, this function is called. We create a preview image and return `self`, which means the data being dragged is a reference to the view node itself.
    *   `_can_drop_data()`: This is called when a dragged object hovers over another control. We check if the data is a `GachaBallView` to see if it's a valid drop target.
    *   `_drop_data()`: This is called when the drop happens. We simply emit the `inventory_action_requested` signal, passing the source and target views. The `BattleManager` or `GameManager` will then decide what this action means (merge, swap, etc.).

5.  **`@onready`**: This keyword is a shorthand that tells a variable to wait until the node and all its children have entered the scene tree before getting its value. It's essential for getting references to child nodes like `%Icon` and `%ItemGrid`, as they don't exist until the scene is fully loaded.

### Summary
We have built the visual cornerstone of our application. With the `GachaBallView` component ready, we can now start constructing the main scenes of the game that will contain and manage these views. The next step is to build the initial scene flow: Title -> Loadout -> Main.

---
## Step 6: Initial Scenes (Title, Loadout, Main)

### What We Did
We built the first set of user-facing scenes: `Title.tscn`, `Loadout.tscn`, `Main.tscn`, and the initial content scene, `PathChoice.tscn`. We also configured `Title.tscn` to be the starting scene for the entire application.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Scene Flow and Navigation**: We've now implemented the user journey defined in the TDD:
    *   Game starts, loads `Title.tscn`.
    *   User clicks "Start Run" -> `Title.gd` emits `start_run_requested`.
    *   `GameManager` catches this, creates the `RunState`, and emits `loadout_scene_requested`.
    *   `SceneManager` catches this and switches to `Loadout.tscn`.
    *   User clicks "Begin" -> `Loadout.gd` emits `main_scene_requested`.
    *   `SceneManager` catches this and switches to `Main.tscn`.
    This demonstrates our event-driven architecture in action. The scenes are completely decoupled from each other.

2.  **Scene Instancing and `preload`**: In `Main.gd`, we use `preload("res://scenes/PathChoice.tscn")`. `preload` loads a resource from the disk when the script itself is loaded, which is very efficient. We then use `.instantiate()` to create a new copy of that scene's nodes and add it as a child to our `%ContentArea`. This is the standard way to dynamically load and display content in Godot.

3.  **UI Layout with Containers**: We made extensive use of `CenterContainer` and `VBoxContainer`. These special nodes automatically arrange their children according to set rules. This is the key to building responsive UIs that adapt to different screen sizes. By setting `Layout -> Container Sizing` properties, we tell nodes how to behave inside their parent container (e.g., `Expand` makes them fill the available space).

4.  **`CanvasLayer` for Modals**: The `%ModalLayer` in `Main.tscn` is a `CanvasLayer` node. This is important because it renders its children on a separate layer, ensuring they always draw *on top* of the rest of the UI, which is exactly what we want for modal dialogs.

### Summary
Our application now has a functional user interface flow. The player can navigate from the title screen to the main game shell. The backend systems we built earlier are now being triggered by actual UI buttons. The next step is to build the most complex scene of the MVP: the `Battle.tscn` itself, where the core gameplay will take place.

---
## Step 7: The Battle Scene and BattleManager

### What We Did
We constructed the `Battle.tscn`, the main stage for our gameplay, complete with placeholders for units. We then created the comprehensive `BattleManager.gd` script to act as the "brain" for this scene, controlling every aspect of the battle.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Scene-Specific Controller**: Unlike our global Autoload managers, `BattleManager.gd` is a script attached directly to the `Battle.tscn` root node. Its lifetime is tied to the scene; it's created when the battle starts and destroyed when it ends. This is the standard pattern for a "controller" that manages a specific, complex piece of UI or gameplay.

2.  **Temporary Battle State**: A crucial concept here is the creation of a temporary inventory. In `_setup_battle()`, the manager loops through the permanent `GameManager.run_state.run_inventory` and calls `instance.create_battle_copy()` for each item. This creates a separate, temporary set of `GachaBallInstance`s that exist *only for this battle*. This is vital because it means any changes during the battle (like merging units) won't affect the player's permanent collection until we explicitly decide to.

3.  **The Master Interaction Logic**: The `_on_inventory_action_requested` function is the heart of the `BattleManager`. It's a master router that determines the player's intent based on the source and target of their action (drag-and-drop or click-click). It follows the logic from our TDD precisely:
    *   Is the target an empty slot? It's a **Move**.
    *   Is it an item dropped on a unit? It's an **Equip**.
    *   Is it two units/items? Check for a recipe.
        *   If a recipe exists, it's a complex interaction. Show a **choice prompt** (Merge/Swap).
        *   If no recipe exists, it must be a **Swap**.
    *   Anything else is an **Invalid Action**.

4.  **Dynamic UI Population**: We don't place `GachaBallView`s in the editor. The `Battle.tscn` only has empty `PanelContainer` slots. The `BattleManager` dynamically creates (`.instantiate()`) and places `GachaBallView` instances into these slots as needed (e.g., when drawing a new unit or placing the initial hero).

### Summary
The core gameplay loop is now implemented. We have a scene where all the action happens and a powerful script that manages the state and rules of that action. The final pieces are the modal dialogs (for inspecting inventories and making choices) and the last bit of integration to tie everything together.

---
## Step 8: Modal UI Scenes

### What We Did
We created three distinct modal (pop-up) scenes: `InspectInventoryView.tscn`, `DiscardPileView.tscn`, and `ChoicePromptUI.tscn`. We also created a reusable helper script, `ModalBackground.gd`, to handle closing these modals consistently.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Modal Behavior**: A modal dialog is a window that appears on top of the main content and prevents interaction with the UI behind it. We achieve this with a `ColorRect` background that covers the whole screen and is set to stop mouse events.

2.  **Reusable Logic (`ModalBackground.gd`)**: The logic for closing a modal (by pressing Escape or clicking the background) is the same for all modals. Instead of copying this code into each modal's script, we created a single, reusable script and attached it to the background `ColorRect` in our modal scenes. This is a great example of the DRY (Don't Repeat Yourself) principle.

3.  **Click-Through Functionality**: The `ModalBackground.gd` script has a clever feature. When you click the background, it first closes the modal and then programmatically injects a *new* click event at the same screen position. This allows a user to close a modal and interact with a button behind it in a single, fluid action, as specified in our TDD.

4.  **Passing Data to Instances**: In `BattleManager.gd`, we passed data to the `DiscardPileView` instance using `modal.set("discard_pile_data", ...)`. When you instantiate a scene, you can't pass data directly to its `_ready` function. The standard way to initialize it with data is to create the instance, set its exported properties, and then add it to the scene tree. The instance's own `_ready` function can then use that data.

5.  **Signal-driven UI Updates**: The `InspectInventoryView.gd` connects to the `GameManager.run_inventory_changed` signal. This is a perfect example of our decoupled architecture. When a merge happens, the `GameManager` emits this signal. The `InspectInventoryView` hears it and calls its `_populate_grid` function to refresh itself, without ever needing to know *what* caused the inventory to change.

### Summary
Our application now has all the necessary UI components to fulfill the MVP requirements. The player can view their inventories and make choices when presented with complex interactions. The final step is a small but crucial one: ensuring the empty slots on our battle board can correctly receive dropped units.

---
## Step 9: Final Polish and Integration

### What We Did
We created one last script, `DropTarget.gd`, and attached it to all the empty placeholder `PanelContainer` slots in our `Battle.tscn`. This was the final piece of the puzzle.

### Didactic Explanation

**Key Concepts Introduced:**

1.  **Completing the Interaction Loop**: This final script completes our drag-and-drop interaction model. Our `GachaBallView.gd` script already defined how a view can *be dragged* (`_get_drag_data`) and how it can have another view *dropped onto it* (`_drop_data`). The `DropTarget.gd` script now defines how an *empty slot* can have a view dropped onto it.

2.  **Specialized vs. Generic Scripts**: `GachaBallView.gd` is a complex, specialized script. `DropTarget.gd`, on the other hand, is extremely simple and generic. Its only job is to announce that it has been dropped on. This is a good design practice. We didn't need to add complex logic to the `PanelContainer`s; we just needed to make them participate in the `EventBus` communication system.

3.  **Final System Integration Check (Mental Walkthrough)**: Let's trace the full user journey to see how all the parts we've built work together.
    *   **Launch & Start**: `Title.tscn` -> `start_run_requested` signal -> `GameManager` creates `RunState` -> `loadout_scene_requested` signal -> `SceneManager` loads `Loadout.tscn`. (✓)
    *   **Enter Main**: `Loadout.tscn` -> `main_scene_requested` signal -> `SceneManager` loads `Main.tscn`, which in turn loads `PathChoice.tscn`. (✓)
    *   **Inspect Inventory**: `Main.tscn` -> "Inspect" button -> `inspect_inventory_requested` signal -> `Main.gd` loads `InspectInventoryView.tscn`. Dragging views inside emits `inventory_action_requested`. `GameManager` (since `is_inspecting_inventory` is true) catches this, calls `MergeManager`, and emits `run_inventory_changed`, which causes the view to refresh. (✓)
    *   **Enter Battle**: `PathChoice.tscn` -> "Start Battle" button -> `battle_start_requested` signal -> `Main.gd` loads `Battle.tscn`. (✓)
    *   **Battle Setup**: `BattleManager.gd`'s `_ready` function creates a temporary `_battle_inventory` by copying from `GameManager`. It places the Hero view. (✓)
    *   **Build Team**: "Draw" buttons emit `draw_gacha_requested(tier)`. `BattleManager` catches this, finds a unit in `_battle_inventory`, finds an empty slot, and instantiates a `GachaBallView` there. (✓)
    *   **Manage Board**:
        *   Dragging a view onto another view emits `inventory_action_requested`. `BattleManager`'s logic correctly routes to swap, equip, or prompt for merge. (✓)
        *   Dragging a view onto an empty slot (now with `DropTarget.gd`) emits `inventory_action_requested`. `BattleManager` identifies the target as an empty `PanelContainer` and handles the move. (✓)
    *   **Item Transfer on Merge**: `MergeManager.attempt_merge` correctly gathers item instances from parents, removes parents from the tiered inventory, adds the new unit, and re-assigns the item instances to the new unit. (✓)
    *   **Discard & Reshuffle**: "Discard Pile" button opens `DiscardPileView.tscn`. "Reshuffle" button triggers the reshuffle logic in `BattleManager`. (✓)

### Summary & Project Completion
**Congratulations!** By following these steps, we have successfully built the entire Core Mechanics MVP as defined in the Technical Design Document. We have a solid, scalable foundation built on clear architectural principles. The project is now fully implemented and ready for testing and future expansion.

---
## Bug Fix: Typo in AbilityResolver

### What We Did
The project failed to launch due to a series of errors originating from `AbilityResolver.gd`. We identified a simple typo (`helpability_queue` instead of `ability_queue`) and corrected it by overwriting the file with the valid code.

### Didactic Explanation

**Key Learning: How to Debug**

This was our first bug, and it highlights a critical programming skill: reading the error log. The errors appeared in a chain:

1.  A **Parse Error** (syntax error) happened first inside a single script.
2.  This caused a **Load Error** because Godot couldn't understand the broken script.
3.  This caused an **Autoload Error** because Godot couldn't load the script it needed to create a global singleton.

The key takeaway is to **always start with the first and most specific error**. Fixing the root cause (the typo) makes all the subsequent errors in the chain disappear. This is a fundamental concept in debugging.

---
## Bug Fix: Corrupted Theme in Title.tscn

### What We Did
After fixing the `AbilityResolver.gd` typo, the project still crashed on startup. The new error, found in `log.txt`, was a `Parse Error` in `res://scenes/Title.tscn` caused by a `Missing 'path' in external resource tag`.

Investigation revealed that a theme resource (`.tres` file) was referenced in the scene file but the path was missing. A search for the theme's unique ID (`uid`) found no corresponding theme file in the project, indicating the resource was likely deleted or corrupted.

To resolve the crash, we removed the broken reference entirely from `Title.tscn`. This included deleting the `[ext_resource]` line and the `theme` property on the root node.

### Didactic Explanation

**Key Learning: Scene File Integrity**

This bug highlights how Godot's text-based scene files (`.tscn`) work. They are a list of nodes, properties, and resource references. If a reference is broken (e.g., points to a file that doesn't exist or has a malformed tag), Godot's parser will fail, preventing the scene—and often the whole project—from loading.

When you see a `Parse Error`, it's almost always a problem *inside* the file itself, not with the code that uses it. The fix is to open the `.tscn` file as text and repair the broken line, which is exactly what we did.

---
## Bug Fix: Broken Sprite Paths in Resources

### What We Did
After fixing the scene file, the robust error handling we added to `Database.gd` revealed a new wave of non-crashing errors. The log showed that every single unit and item `.tres` resource file was failing to load because it was pointing to a non-existent sprite path.

We investigated the `assets/` directory and found that the actual `.png` filenames had different capitalization and naming schemes than what was referenced in the resource files (e.g., `Tier1unitA.png` vs. `UnitTier1A.png`).

We performed a batch update, correcting the `path` in all 9 affected `.tres` files to match the actual filenames on disk.

### Didactic Explanation

**Key Learning: Asset Path Rigidity**

This bug is a classic example of how unforgiving file paths can be. A single character difference in capitalization or naming can cause a resource to not be found. This also highlighted the value of our earlier fix to `Database.gd`; without it, the first error would have crashed the game, and we would have had to fix the errors one by one. With robust loading, we got a complete list of all broken paths at once, making the problem much faster to diagnose and solve.

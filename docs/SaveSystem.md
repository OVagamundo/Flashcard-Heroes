# Save System
Version: 1.0
Status: Implemented

## 1. Overview
The Save System allows players to suspend their run and resume it later. It is designed as a "checkpoint" system rather than a "save anywhere" system. The primary goal is to allow players to take breaks without losing progress, while maintaining the roguelike tension (saves are cleared on death).

## 2. Architecture

### 2.1. SaveManager (Autoload)
The `SaveManager` is a globally accessible autoload singleton responsible for file I/O operations.
- **Path**: `res://scripts/SaveManager.gd`
- **Save Location**: `user://run_save.dat`
- **Format**: Godot native variant serialization (`FileAccess.store_var` / `get_var`) of a Dictionary.

### 2.2. RunState Serialization
The `RunState` resource serves as the single source of truth for a run's data. It implements `to_save_dict()` and `from_save_dict()` methods to handle serialization.

**Serialized Data:**
- **Run Progress**: `day`, `gold`, `bosses_defeated`, `current_boss_level`.
- **Statistics**: `total_enemies_defeated`, `total_gold_earned`.
- **Deck State**: `deck_def_id`, `active_deck_ids`, `cards_presented_count`.
- **Flashcard Progress**: Full history of card mastery (`mastery_level`, `times_reviewed`, `last_review_day`).
- **Instances**: All `GachaBallInstance` objects (Units, Items, Trinkets) including their stats, equipment, and modifiers.
- **Containers**: The layout of all inventories (`PlayerLineup`, `PlayerBench`, `RunInventory`, etc.).

### 2.3. GachaBallInstance Serialization
Each game entity (unit, item) is serialized via `to_save_dict()`, capturing:
- **Definition**: `definition_id`.
- **Identity**: `ball_uuid`, `origin_uuid`.
- **Stats**: `current_hp`, `current_pwr`.
- **Location**: Container tag and slot index.
- **Equipment**: UUIDs of equipped items.
- **Dynamic State**: Status effects and tags.

## 3. Save Logic

### 3.1. Save Trigger
The game automatically saves the run state **immediately upon entering the Path Choice scene** (Day start).
- This occurs after the `day` counter has advanced.
- This creates a "safe checkpoint" at the start of every day.

### 3.2. Loading (Continue)
- The **Title Screen** checks for the existence of a save file.
- If found, a **"Continue"** button is displayed.
- Clicking "Continue" loads the `RunState` into `GameManager.run_state` and transitions directly to the **Path Choice** scene.
- **Double Increment Prevention**: A `GameManager.loading_from_save` flag is set during load. The `PathChoice` script checks this flag to skip the daily day-increment logic, ensuring the loaded day count is accurate.

### 3.3. Save Clearing
To enforce the roguelike structure, the save file is **deleted** in the following scenarios:
- **Game Over (Defeat)**: When the player loses a battle and acknowledges the defeat.
- **Victory (Run Complete)**: When the player defeats the final boss and acknowledges the victory.

## 4. Technical Constraints
- **Versioning**: Currently, the system assumes data compatibility. Major changes to `RunState` structure in the future will require version handling or will invalidate old saves.
- **File System**: Saves are stored in the user data directory (`user://`), which persists across game updates and sessions but is local to the device.

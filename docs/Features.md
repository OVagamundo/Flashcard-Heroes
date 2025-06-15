# Flashcard Heroes - Feature Documentation

This document is organized by game features rather than by script files, making it easier to understand how different parts of the system work together.

> **Note**: For implementation details of specific scripts, see the corresponding script files in the `scripts/` directory. This document focuses on how features are implemented across multiple scripts.

## Key Design Patterns

- **Event-Driven Architecture**: The game uses a centralized EventBus for communication between systems
- **Scene-Based Organization**: Each major game screen is implemented as a separate scene
- **UI/Logic Separation**: UI elements are separated from game logic where possible

## How to Use This Document

1. Start with the [Game Flow](#2-game-flow) section to understand the overall game structure
2. Explore specific systems that interest you
3. Use the table of contents for quick navigation
4. Look for 🔄 icons to find related features

## Table of Contents

1. [Core Systems](#1-core-systems)
   - [1.1 Event Bus System](#11-event-bus-system)
   - [1.2 Scene Management](#12-scene-management)
   - [1.3 UI Framework](#13-ui-framework)

2. [Game Flow](#2-game-flow)
   - [2.1 Main Menu Flow](#21-main-menu-flow)
   - [2.2 Game Navigation](#22-game-navigation)

3. [Gacha System](#3-gacha-system)
   - [3.1 Gacha Machine UI](#31-gacha-machine-ui)
   - [3.2 Gacha Pool Management](#32-gacha-pool-management)
   - [3.3 Item/Unit Display](#33-itemunit-display)

4. [Battle System](#4-battle-system)
   - [4.1 Battle Flow](#41-battle-flow)
   - [4.2 Unit Management](#42-unit-management)
   - [4.3 Item System](#43-item-system)

5. [Shop System](#5-shop-system)
6. [Rest System](#6-rest-system)
7. [Analysis & Improvements](#7-analysis--improvements)

---

## 1. Core Systems

### 1.1 Event Bus System

**Purpose**: Centralized event handling system that allows decoupled communication between game components.

**Key Files**:
- `EventBus.gd`

**Related Features**:
- 🔄 Used by all major systems for inter-system communication
- 🔄 Essential for [Scene Management](#12-scene-management)
- 🔄 Critical for [Game Flow](#2-game-flow) transitions

**Implementation**:

```gdscript
# EventBus.gd
# The 'extends' keyword is used for inheritance in GDScript
# 'Node' is the base class for all objects in the Godot scene tree
extends Node

# Signal definitions for scene management
# Signals are Godot's way of implementing the Observer pattern
# They allow decoupled communication between nodes

# Emitted when a full scene change is requested
# 'scene_path' is the path to the scene file to load
signal change_scene_to_file_requested(scene_path: String)

# Emitted when a scene should be loaded into a specific container
# 'scene_path' is the path to the scene file
# 'container' is the Node that will be the parent of the loaded scene
signal load_scene_in_container_requested(scene_path: String, container: Node)

# Emitted when the gacha machine inspection UI should be shown
# 'gacha_machine_id' identifies which machine is being inspected
# 'machine_global_position' is the screen position of the machine
# 'machine_size' is the size of the machine for UI positioning
signal gacha_inspection_requested(gacha_machine_id: String, machine_global_position: Vector2, machine_size: Vector2)
```

**Usage**:
- Components can emit events without knowing which other components are listening
- Reduces direct dependencies between game systems
- Makes the codebase more modular and maintainable

### 1.2 Scene Management

**Purpose**: Handles loading and transitioning between game scenes.

**Key Files**:
- `SceneManager.gd`
- `Main.gd` (partial)

**Related Features**:
- 🔄 Integrates with [Event Bus](#11-event-bus-system) for scene transition requests
- 🔄 Manages transitions for all game systems
- 🔄 Works with [UI Framework](#13-ui-framework) for container-based loading

**Implementation**:

```gdscript
# SceneManager.gd
# This script manages scene transitions and loading in the game
# It's a singleton (autoload) that handles all scene changes

extends Node

# Variable to keep track of the currently active scene
# The ': Node' is a type hint telling us this will store a Node
var _current_scene: Node

# _ready() is called when the node enters the scene tree for the first time
func _ready() -> void:
    # Connect to the EventBus signals we want to handle
    # When these signals are emitted, the corresponding functions will be called
    EventBus.change_scene_to_file_requested.connect(_on_change_scene_to_file_requested)
    EventBus.load_scene_in_container_requested.connect(_on_load_scene_in_container_requested)
    
    # Store a reference to the initial scene
    _current_scene = get_tree().current_scene

# Handler for full scene changes (e.g., from menu to game)
# 'scene_path' is the path to the new scene file
func _on_change_scene_to_file_requested(scene_path: String) -> void:
    # If there's a current scene, free it to free up memory
    # This is important to prevent memory leaks
    if _current_scene:
        _current_scene.queue_free()  # Queue the current scene for deletion
    
    # Load the new scene from the provided path
    # 'load()' loads the resource but doesn't create an instance yet
    var scene = load(scene_path)
    
    # Check if the scene was loaded successfully
    if scene:
        # Create an instance of the scene
        _current_scene = scene.instantiate()
        
        # Add the new scene as a child of the root node
        # get_tree().root gives us the root Viewport
        get_tree().root.add_child(_current_scene)
        
        # Update the current scene in the SceneTree
        get_tree().current_scene = _current_scene

# Handler for loading scenes into specific containers (e.g., UI elements)
# 'scene_path' is the path to the scene to load
# 'container' is the parent node that will contain the new scene
func _on_load_scene_in_container_requested(scene_path: String, container: Node) -> void:
    # First, remove any existing children from the container
    # This prevents multiple UI elements from stacking up
    for child in container.get_children():
        # Queue each child for deletion
        # Using queue_free() is safer than free() as it waits until it's safe to delete
        child.queue_free()
    
    # Load the new scene
    var scene = load(scene_path)
    if scene:
        # Create an instance of the scene
        var instance = scene.instantiate()
        container.add_child(instance)

**Features**:
- Full scene transitions (e.g., Title → Game)
- Dynamic content loading within containers
- Clean resource management

### 1.3 UI Framework

**Purpose**: Common UI patterns and components used throughout the game.

**Key Files**:
- `BottomBar.gd`
- `TopBar.gd`
- `PathOptions.gd`
- `BattleScene.gd`
- `ShopScene.gd`
- `RestScene.gd`
- `GachaMachineUI.gd`
- `GachaPoolInspection.gd`
- `GachaBallDefinition.gd`
- `PlaceholderUnit.gd`


**Related Features**:
- 🔄 Used by all UI-heavy systems ([Gacha](#3-gacha-system), [Battle](#4-battle-system), etc.)
- 🔄 Integrates with [Scene Management](#12-scene-management) for dynamic UI loading
- 🔄 Follows consistent theming and layout patterns

**Implementation Example - BottomBar.gd**:

```gdscript
# BottomBar.gd
# This script manages the bottom bar UI element that contains gacha machines
# It handles button presses and communicates with the EventBus

# 'extends Control' means this script inherits from Godot's base Control node
# Control is the base class for all UI elements in Godot
extends Control

# The '@onready' keyword means these variables will be initialized when the node is ready
# These variables store references to the gacha machine UI elements
# The '$' symbol is shorthand for get_node() in Godot
@onready var gacha_machine_1 = $HBoxContainer/GachaMachinesContainer/GachaMachine1
@onready var gacha_machine_2 = $HBoxContainer/GachaMachinesContainer/GachaMachine2
@onready var gacha_machine_3 = $HBoxContainer/GachaMachinesContainer/GachaMachine3

# _ready() is called when the node enters the scene tree for the first time
func _ready():
    # Connect each gacha machine's button press signal to the corresponding handler
    # This follows the observer pattern - the button is the subject, this script is the observer
    gacha_machine_1.gacha_body_button.pressed.connect(_on_gacha_machine_1_pressed)
    gacha_machine_2.gacha_body_button.pressed.connect(_on_gacha_machine_2_pressed)
    gacha_machine_3.gacha_body_button.pressed.connect(_on_gacha_machine_3_pressed)

# Called when the first gacha machine's button is pressed
func _on_gacha_machine_1_pressed():
    # Emit a signal through the EventBus to request gacha machine inspection
    # This follows the game's event-driven architecture
    EventBus.emit_signal(
        "gacha_inspection_requested",  # Signal name
        "gacha_machine_1",             # Machine identifier
        gacha_machine_1.global_position, # Screen position for UI placement
        gacha_machine_1.size           # Size for UI layout
    )

# Called when the second gacha machine's button is pressed
func _on_gacha_machine_2_pressed():
    # Same pattern as _on_gacha_machine_1_pressed but for the second machine
    EventBus.emit_signal(
        "gacha_inspection_requested",
        "gacha_machine_2",
        gacha_machine_2.global_position,
        gacha_machine_2.size
    )

# Called when the third gacha machine's button is pressed
func _on_gacha_machine_3_pressed():
    # Same pattern as above for the third machine
    EventBus.emit_signal(
        "gacha_inspection_requested",
        "gacha_machine_3",
        gacha_machine_3.global_position,
        gacha_machine_3.size
    )
```

**Common Patterns**:
- Button press handling
- Dynamic content loading
- Scene transitions
- Event-driven communication through signals

## 2. Game Flow

The game flow represents the player's journey through the game, from startup to gameplay and beyond.

### 2.1 Main Menu Flow

**Purpose**: Handles the initial game startup and main menu navigation.

**Key Files**:
- `Title.gd`
- `Loadout.gd`

**Implementation**:

```gdscript
# Title.gd
# This script manages the title screen and main menu
# It handles the initial user interaction when starting the game

# 'extends Control' means this script inherits from Godot's base Control node
# Control is the base class for all UI elements in Godot
extends Control

# _ready() is called when the node enters the scene tree for the first time
func _ready() -> void:
    # Connect the 'pressed' signal of the NewGameButton to our handler function
    # The '$' symbol is shorthand for get_node() in Godot
    # This connects the button press to the _on_new_game_pressed function
    $VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
    
    # In a full implementation, we might also:
    # 1. Add animation for the title screen
    # 2. Play background music
    # 3. Initialize game settings
    # 4. Check for saved games

# This function is called when the New Game button is pressed
func _on_new_game_pressed() -> void:
    # Emit a signal through the EventBus to request a scene change
    # This follows the game's event-driven architecture
    # The signal will be handled by the SceneManager
    EventBus.change_scene_to_file_requested.emit("res://scenes/Loadout.tscn")
    
    # Note: We don't directly load the scene here. Instead, we emit a signal
    # This keeps our code decoupled and makes it easier to change how scenes are loaded
```

```gdscript
# Loadout.gd
# This script manages the loadout/character selection screen
# It's a placeholder for character/loadout selection before starting the game

# 'extends Control' means this script inherits from Godot's base Control node
# This is a UI screen that will be shown after the title screen
extends Control

# In a full implementation, this would include:
# - Character selection UI
# - Loadout customization
# - Party management
# - Difficulty selection
# - Game start confirmation

# Example of what might be added:
# @onready var start_button = $VBoxContainer/StartButton
# var selected_character: String = ""
# 
# func _ready() -> void:
#     start_button.pressed.connect(_on_start_button_pressed)
#     # Setup character selection UI
#     # Load saved characters if they exist
# 
# func _on_start_button_pressed() -> void:
#     if selected_character:
#         GameState.selected_character = selected_character
#         EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")
#     else:
#         show_error("Please select a character first!")

# _ready() is called when the node enters the scene tree for the first time
func _ready() -> void:
    # Connect the 'pressed' signal of the StartButton to our handler function
    # The button is found using the node path from the scene tree
    $VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)
    
    # In a full implementation, we would also:
    # 1. Set up character selection UI
    # 2. Load any saved loadouts
    # 3. Initialize any game settings
    # 4. Connect additional UI signals

# This function is called when the Start button is pressed
func _on_start_button_pressed() -> void:
    # Emit a signal through the EventBus to start the main game
    # This follows the game's event-driven architecture
    # The signal will be handled by the SceneManager
    EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")
    
    # Note: In a full implementation, we would first:
    # 1. Validate the player's loadout
    # 2. Save the loadout to GameState
    # 3. Potentially show a loading screen
    # 4. Then transition to the main game
```

**Flow**:
1. Game starts at Title screen
2. Player clicks "New Game"
3. Loadout screen appears (placeholder for character selection)
4. Player clicks "Start" to begin the game

### Implemented Gacha System Features (as of 2025-06-15)

This section details the components of the Gacha System that have been implemented or significantly updated during recent development sessions. It complements any existing descriptions in sections 3.1, 3.2, and 3.3 by providing a consolidated summary of concrete implementations.

#### Core Data Structures:
- **`GachaBallDefinition.gd`**: (`scripts/Gacha/GachaBallDefinition.gd`)
  - A `Resource` script defining static properties: `id` (String), `display_name_key` (String), `description_key` (String), `icon_texture` (Texture2D), `tier` (int, e.g., 0 for Hero, 1-3 for gacha), `ball_category` (enum: UNIT, ITEM).
  - These are created as `.tres` files within the `res://resources/units/` and `res://resources/items/` directories.
  - Example: `res://resources/units/tier1_warrior.tres`.
- **`GachaBallInstance.gd`**: (`scripts/Gacha/GachaBallInstance.gd`)
  - A `Resource` script (class `GachaBallInstance`) representing a specific, dynamic instance of a `GachaBallDefinition`.
  - Holds a reference to its `definition: GachaBallDefinition`.
  - Will store instance-specific data (e.g., current HP, unique ID, location state) as the system evolves.

#### Database and Pool Management:
- **`Database.gd`**: (`scripts/Core/Database.gd`)
  - An autoload singleton (accessible globally as `Database`).
  - Responsible for loading all `GachaBallDefinition` resources from the `res://resources/` subdirectories (specifically `units` and `items`) at game startup.
  - Organizes these loaded definitions into its `gachaball_definitions` dictionary. This dictionary is keyed by `tier` (integer: 0, 1, 2, 3), and each value is an array of `GachaBallDefinition`s belonging to that tier.
  - This `Database.gachaball_definitions` effectively serves as the master list of all possible gacha outcomes and defined game entities.

#### Item/Unit Display Scenes:
- **`Unit.tscn` & `Unit.gd`**: (`scenes/Unit.tscn`, `scripts/Unit.gd`)
  - The scene and script pair for visually representing a single Unit.
  - `Unit.tscn` typically includes UI elements like a `Sprite2D` for the unit's art, a `Label` for its name, and another `Label` for its HP.
  - `Unit.gd` (class `Unit`) extends `Control` and provides an `initialize(instance: GachaBallInstance)` method. This method populates the UI elements using data from the provided `gacha_instance.definition`.
- **`Item.tscn` & `Item.gd`**: (`scenes/Item.tscn`, `scripts/Item.gd`)
  - The scene and script pair for visually representing a single Item.
  - `Item.tscn` typically includes a `Sprite2D` for the item's icon and a `Label` for its description or name.
  - `Item.gd` (class `Item`) extends `Control` and also features an `initialize(instance: GachaBallInstance)` method for UI population.
- **Texture Handling**: The `icon_texture` property in `GachaBallDefinition` (.tres files) should hold the direct `Texture2D` resource. Scene scripts (`Unit.gd`, `Item.gd`) assign this texture to their respective `Sprite2D` nodes. Initial issues with `preload()` in `.tscn` files were resolved by setting sprite textures to `null` in the scene files and relying on dynamic assignment or `.tres` file definitions.

#### Gacha Pool Inspection UI:
- **`GachaPoolInspection.tscn` & `GachaPoolInspection.gd`**: (`scenes/GachaPoolInspection.tscn`, `scripts/GachaPoolInspection.gd`)
  - A UI screen designed to display all available `GachaBallDefinition`s that have been loaded by the `Database`.
  - When activated, `GachaPoolInspection.gd`:
    1. Accesses `Database.gachaball_definitions`.
    2. Iterates through definitions for Tiers 1, 2, and 3. (Note: Display of Tier 0 definitions in this specific UI is pending user clarification).
    3. For each `GachaBallDefinition`, it creates a new `GachaBallInstance`.
    4. Determines if the definition is for a Unit or an Item using `instance.is_unit()` (derived from `ball_category`).
    5. Instantiates the corresponding scene (`Unit.tscn` or `Item.tscn`).
    6. Calls the `initialize(instance)` method on the newly created card scene to populate its visual elements.
    7. Adds the populated card scene to the appropriate tier-specific `GridContainer` within the `GachaPoolInspection.tscn` UI.
  - This screen serves as a crucial debugging and verification tool, ensuring that gacha definitions are correctly loaded and that their basic display scenes are functional.

---
## 4. Battle System

The Battle System manages combat encounters, including unit management and combat mechanics.

### 4.1 Battle Flow

**Purpose**: Manages the battle scene and combat mechanics.

**Key Files**:
- `BattleScene.gd`
- `PlaceholderUnit.gd`

**Implementation**:

```gdscript
# BattleScene.gd
# This script manages the main battle interface and flow
# It's a UI container that holds all battle-related UI elements

# 'extends VBoxContainer' means this script inherits from Godot's VBoxContainer node
# VBoxContainer automatically arranges its children vertically
# Note: In Godot, UI elements are typically organized in a tree structure
# with Control nodes like VBoxContainer, HBoxContainer, etc.
extends VBoxContainer

# The '@onready' keyword means this variable will be initialized when the node is ready
# '$' is shorthand for get_node(), so $BackButton gets a reference to the BackButton node
# This creates a reference to the BackButton that's a child of this node
@onready var back_button = $BackButton

# _ready() is called when the node enters the scene tree for the first time
func _ready():
    # Connect the 'pressed' signal of the back button to our _on_back_pressed function
    # This is how button clicks are handled in Godot
    back_button.pressed.connect(_on_back_pressed)

# This function is called when the back button is pressed
func _on_back_pressed():
    # Emit a signal through the EventBus to load the PathOptions scene
    # This demonstrates the event-driven architecture of the game
    # The signal includes:
    # 1. The path to the scene to load
    # 2. The parent container where the scene should be loaded
    EventBus.load_scene_in_container_requested.emit(
        "res://scenes/PathOptions.tscn",  # Path to the PathOptions scene
        get_parent()  # The parent container (where this scene was loaded into)
    )
    
    # Note: The actual scene change is handled by the SceneManager which listens to this signal
    # This is an example of loose coupling - BattleScene doesn't need to know about SceneManager
    # It just sends an event and lets the appropriate system handle it
```

**Features**:
- Basic scene structure for battles
- Back button to return to path selection
- Placeholder for battle mechanics

### 4.2 Unit Management

**Purpose**: Handles unit data and behavior in battles.

**Key Files**:
- `PlaceholderUnit.gd`

**Implementation**:

```gdscript
# PlaceholderUnit.gd
# This is a placeholder script for unit display in the battle system
# It's currently a simple UI container without game logic

# 'extends PanelContainer' means this inherits from Godot's PanelContainer
# PanelContainer is a UI control that displays a background panel
# It's often used as a container for other UI elements
extends PanelContainer

# This is a placeholder with no additional functionality yet
# In a full implementation, this would include:
# - Unit stats (health, attack, etc.)
# - Visual representation of the unit
# - Methods for handling unit actions (attack, defend, use ability)
# - Animation handling for unit actions
# - Event handlers for player interaction

# Example of what might be added in the future:
# @onready var health_label = $HealthLabel
# @onready var sprite = $Sprite2D
# 
# var max_health = 100
# var current_health = 100
# 
# func take_damage(amount: int) -> void:
#     current_health = max(0, current_health - amount)
#     update_health_display()
#     if current_health <= 0:
#         die()
# 
# func update_health_display() -> void:
#     health_label.text = str(current_health) + "/" + str(max_health)
# 
# func die() -> void:
#     # Play death animation
#     # Remove from battle
#     queue_free()
```

**Features**:
- Basic unit container
- Placeholder for unit stats and abilities
- Ready for future implementation

### 4.3 Combat Mechanics

**Purpose**: Manages the core combat loop and mechanics.

**Key Files**:
- `BattleScene.gd` (partial)
- `PlaceholderUnit.gd` (partial)

**Implementation Notes**:
- Combat system is currently in early development
- Uses a turn-based system
- Placeholder for damage calculation and ability effects

## 3. Gacha System

The Gacha System handles the random item/unit acquisition mechanics in the game.

### 3.1 Gacha Ball Definitions

**Purpose**: Defines the properties of gacha balls that can be obtained in the game.

**Key Files**:
- `GachaBallDefinition.gd`

**Implementation**:

```gdscript
# GachaBallDefinition.gd
# This script defines the properties of a gacha ball in the game
# It's a Resource that can be created in the Godot editor and saved as a .tres file

# 'extends Resource' means this script inherits from Godot's Resource class
# Resources are data containers that can be saved to disk and reused
# They're great for defining game data like items, characters, or in this case, gacha balls
extends Resource

# '@export' makes these properties visible and editable in the Godot editor
# This allows designers to create different types of gacha balls without touching code

# A unique identifier for this gacha ball type
# Used to reference this specific ball in code and save files
@export var id: String

# The rarity of the gacha ball (e.g., 1 = common, 2 = uncommon, 3 = rare, etc.)
# Higher rarities might have better rewards or be harder to obtain
@export var rarity: int

# Base health points for units that come from this ball
# This would be used if the gacha contains a unit character
@export var base_hp: int

# Base power/attack value for units from this ball
# Determines how strong the unit is in battle
@export var base_pwr: int

# The visual icon/texture for this gacha ball
# This is what players will see in the UI
@export var icon_texture: Texture2D

# Whether this ball contains an equippable item
# If true, the item can be equipped to characters
@export var is_equippable: bool

# Whether this ball contains a consumable item
# If true, the item is used up when activated
@export var is_consumable: bool

# Any restrictions on what can use this item
# For example, might restrict certain items to specific character types
@export var target_type_restriction: String

# In a full implementation, you might also have:
# - A list of possible rewards with drop rates
# - Visual effects when the ball is opened
# - Sound effects
# - Animation properties
# - Description text for the UI
# - Value/sell price
# - Other game-specific stats or properties
```

**Usage**:
1. Create a new Resource of type `GachaBallDefinition` in the Godot editor
2. Set the properties in the Inspector panel
3. Save as a .tres file in your project
4. Reference these definitions in your gacha machine logic

**Example**:
```gdscript
# Example of how you might use GachaBallDefinition in code
func get_random_gacha_ball() -> GachaBallDefinition:
    # In a real game, you'd have some logic to determine which balls are available
    # and their relative rarities
    var ball_definitions = [
        preload("res://resources/gacha/balls/common_ball.tres"),
        preload("res://resources/gacha/balls/uncommon_ball.tres"),
        preload("res://resources/gacha/balls/rare_ball.tres")
    ]
    
    # Simple random selection (in a real game, you'd want weighted randomness)
    var random_index = randi() % ball_definitions.size()
    return ball_definitions[random_index]
```

### 3.2 Gacha Machine UI

**Purpose**: Handles the visual representation and interaction with gacha machines.

**Key Files**:
- `GachaMachineUI.gd`
- `GachaPoolInspection.gd`

**Implementation**:

```gdscript
# GachaMachineUI.gd
# This script manages the UI for a single gacha machine in the game
# It handles the visual representation and user interaction with gacha machines

# 'extends Control' means this inherits from Godot's base Control node
# Control is the base class for all UI elements in Godot
extends Control

# The '@onready' keyword means these variables will be initialized when the node is ready
# This is commonly used for node references that are set up in the scene editor

# Reference to the title label that displays the machine's name
@onready var title_label: Label = $VBoxContainer/TitleLabel

# Reference to the main button representing the gacha machine's body
@onready var gacha_body_button: Button = $VBoxContainer/GachaBodyButton

# Reference to the draw button (currently not used in the implementation)
@onready var draw_button: Button = $VBoxContainer/DrawButton

# _ready() is called when the node enters the scene tree
func _ready():
    # Connect the gacha body button's 'pressed' signal to our handler function
    # This is how button clicks are handled in Godot
    gacha_body_button.pressed.connect(_on_gacha_body_button_pressed)
    
    # Note: The draw_button's signal is not connected in the current implementation
    # This might be for future functionality

# This function is called when the gacha machine's body button is pressed
func _on_gacha_body_button_pressed():
    # Emit a signal through the EventBus to request the gacha pool inspection UI
    # This follows the game's event-driven architecture
    # The signal includes:
    # 1. The name of this gacha machine (used as an identifier)
    # 2. The global position on screen (for UI placement)
    # 3. The size of this UI element (for layout purposes)
    EventBus.gacha_inspection_requested.emit(name, global_position, size)
    
    # In a full implementation, you might also want to:
    # 1. Play a sound effect
    # 2. Add visual feedback (like a button press animation)
    # 3. Check if the player has enough currency to draw
    # 4. Show a tooltip or information about the gacha machine
```

**Features**:
- Visual representation of a gacha machine
- Button press handling for interaction
- Integration with the event system
- Ready for future expansion (draw button not yet implemented)

**Usage Example**:
```gdscript
# Example of how you might extend GachaMachineUI
func _on_gacha_body_button_pressed():
    # Play a sound effect when the machine is pressed
    $ButtonPressSound.play()
    
    # Add a small scale animation for feedback
    var tween = create_tween()
    tween.tween_property(gacha_body_button, "scale", Vector2(0.9, 0.9), 0.1)
    tween.tween_property(gacha_body_button, "scale", Vector2(1.0, 1.0), 0.1)
    
    # Then emit the original signal
    EventBus.gacha_inspection_requested.emit(name, global_position, size)
```

### 3.3 Gacha Pool Management

**Purpose**: Manages the available items/units that can be obtained from gacha machines.

**Key Files**:
- `GachaPoolInspection.gd`

**Implementation**:

```gdscript
# GachaPoolInspection.gd
# This script manages the UI that appears when inspecting a gacha machine's pool
# It shows the available items/units that can be obtained from a gacha machine

# 'extends VBoxContainer' means this inherits from Godot's VBoxContainer
# VBoxContainer automatically arranges its children vertically
extends VBoxContainer

# The '@onready' keyword means these variables will be initialized when the node is ready
# These are references to UI elements set up in the scene editor

# Reference to a dummy UI element that represents the top bar area
@onready var top_bar_dummy: Control = $TopBarDummy

# Reference to a dummy UI element that represents the bottom bar area
@onready var bottom_bar_dummy: Control = $BottomBarDummy

# Reference to the container that will hold the gacha inventories
@onready var gacha_inventories_area: HBoxContainer = $GachaInventoriesArea

# _ready() is called when the node enters the scene tree
func _ready():
    # Set the mouse filter to stop input events from passing through this control
    # This ensures the panel can receive and handle input events
    mouse_filter = Control.MOUSE_FILTER_STOP
    
    # In a full implementation, you might also:
    # 1. Set up initial UI state
    # 2. Connect signals
    # 3. Initialize any dynamic content

# This function is called when the node receives GUI input events
func _gui_input(event: InputEvent) -> void:
    # Check if the event is a left mouse button press
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        # Check if the click occurred outside the GachaInventoriesArea
        if not gacha_inventories_area.get_global_rect().has_point(get_global_mouse_position()):
            # If clicked outside, hide the inspection UI
            hide()
            # Consume the event so it doesn't propagate to elements behind this UI
            accept_event()

# Sets up the gacha pool display
func setup_gacha_pool():
    # Clear existing children from each inventory tier
    for tier_container in gacha_inventories_area.get_children():
        if tier_container is GridContainer:
            for child in tier_container.get_children():
                # Queue each child for deletion
                # Using queue_free() is safer than free() as it waits until it's safe to delete
                child.queue_free()
    # The grids will remain empty for now, as this is a placeholder implementation
    
    # In a full implementation, you would:
    # 1. Load the available items/units for this gacha machine
    # 2. Create UI elements for each item/unit
    # 3. Organize them by rarity or other categories
    # 4. Set up any interaction handlers
```

**Features**:
- Modal UI that appears when inspecting a gacha machine
- Input handling to close when clicking outside the content area
- Placeholder for displaying available gacha items/units
- Clean organization of gacha items by tiers/rarity

**Usage Example**:
```gdscript
# Example of how you might extend GachaPoolInspection
func setup_gacha_pool():
    # First clear existing content
    .setup_gacha_pool()  # Call parent implementation
    
    # Example: Add sample items (in a real game, these would come from game data)
    var sample_items = [
        {"name": "Common Item", "rarity": 1, "texture": preload("res://icons/common_item.png")},
        {"name": "Rare Item", "rarity": 2, "texture": preload("res://icons/rare_item.png")},
        # Add more items...
    ]
    
    # Add items to the appropriate tier container
    for item in sample_items:
        var tier_container = gacha_inventories_area.get_node("Tier" + str(item.rarity))
        if tier_container:
            var item_texture = TextureRect.new()
            item_texture.texture = item.texture
            item_texture.tooltip_text = item.name
            tier_container.add_child(item_texture)
```

**Integration with GachaMachineUI**:
1. When a gacha machine is clicked, GachaMachineUI emits the `gacha_inspection_requested` signal
2. The game shows the GachaPoolInspection UI
3. GachaPoolInspection loads and displays the available items
4. The UI can be closed by clicking outside the content area

## 5. Shop System

The Shop System handles in-game purchases and item management.

### 5.1 Shop Interface

**Purpose**: Handles the shop UI and item purchasing.

**Key Files**:
- `ShopScene.gd`

**Implementation**:

```gdscript
# ShopScene.gd
# This script manages the shop interface where players can purchase items
# It's a UI container that displays available items and handles purchases

# 'extends VBoxContainer' means this script inherits from Godot's VBoxContainer node
# VBoxContainer automatically arranges its children vertically
# This is commonly used for UI layouts in Godot
extends VBoxContainer

# The '@onready' keyword means this variable will be initialized when the node is ready
# '$BackButton' is shorthand for get_node("BackButton")
# This creates a reference to the BackButton node that's a child of this node
@onready var back_button = $BackButton

# _ready() is called when the node enters the scene tree for the first time
func _ready():
    # Connect the 'pressed' signal of the back button to our _on_back_pressed function
    # This is the standard way to handle button clicks in Godot
    back_button.pressed.connect(_on_back_pressed)
    
    # In a full implementation, we would also:
    # 1. Load available items from a data file or game state
    # 2. Create UI elements for each item
    # 3. Set up purchase handlers
    # 4. Update player's currency display
    # Example:
    # load_shop_items()
    # update_currency_display()

# This function is called when the back button is pressed
func _on_back_pressed():
    # Emit a signal through the EventBus to return to the PathOptions scene
    # This follows the game's event-driven architecture
    # The signal includes:
    # 1. The path to the PathOptions scene
    # 2. The parent container where the scene should be loaded
    EventBus.load_scene_in_container_requested.emit(
        "res://scenes/PathOptions.tscn",  # Path to the PathOptions scene
        get_parent()  # The parent container (where this scene was loaded into)
    )

# Example of a function that might be added in the future:
# func load_shop_items() -> void:
#     # Clear any existing items
#     for child in $ItemContainer.get_children():
#         child.queue_free()
#     
#     # Load items from game data
#     for item_data in GameData.shop_items:
#         var item_button = preload("res://scenes/ShopItemButton.tscn").instantiate()
#         item_button.setup(item_data)
#         item_button.pressed.connect(_on_item_pressed.bind(item_data))
#         $ItemContainer.add_child(item_button)
# 
# func _on_item_pressed(item_data: Dictionary) -> void:
#     # Handle item purchase
#     if GameState.can_afford(item_data.cost):
#         GameState.spend_currency(item_data.cost)
#         GameState.add_to_inventory(item_data.id)
#         update_currency_display()
#     else:
#         show_error("Not enough currency!")
# 
# func update_currency_display() -> void:
#     $CurrencyLabel.text = str(GameState.currency)
```

**Features**:
- Basic shop interface
- Back button to return to path selection
- Placeholder for shop inventory and purchasing logic

## 6. Rest System

The Rest System allows players to recover and prepare between battles.

### 6.1 Rest Interface

**Purpose**: Handles the rest area where players can recover.

**Key Files**:
- `RestScene.gd`

**Implementation**:

```gdscript
# RestScene.gd
# This script manages the rest area where players can recover between battles
# It's a UI container that provides healing and other recovery options

# 'extends VBoxContainer' means this script inherits from Godot's VBoxContainer
# VBoxContainer automatically arranges its children vertically
# This is commonly used for UI layouts in Godot
extends VBoxContainer

# The '@onready' keyword means this variable will be initialized when the node is ready
# '$BackButton' is shorthand for get_node("BackButton")
# This creates a reference to the BackButton node that's a child of this node
@onready var back_button = $BackButton

# _ready() is called when the node enters the scene tree for the first time
func _ready():
    # Connect the 'pressed' signal of the back button to our _on_back_pressed function
    # This is the standard pattern for handling button clicks in Godot
    back_button.pressed.connect(_on_back_pressed)
    
    # In a full implementation, we would also:
    # 1. Set up healing mechanics
    # 2. Update UI to show current party status
    # 3. Handle any rest-related events or timers
    # Example:
    # update_party_status()
    # setup_rest_actions()

# This function is called when the back button is pressed
func _on_back_pressed():
    # Emit a signal through the EventBus to return to the PathOptions scene
    # This follows the game's event-driven architecture
    # The signal includes:
    # 1. The path to the PathOptions scene
    # 2. The parent container where the scene should be loaded
    EventBus.load_scene_in_container_requested.emit(
        "res://scenes/PathOptions.tscn",  # Path to the PathOptions scene
        get_parent()  # The parent container (where this scene was loaded into)
    )
    
    # Note: Any cleanup or saving of rest-related data would happen here
    # Example:
    # save_rest_changes()

# Example of functions that might be added in the future:
# func update_party_status() -> void:
#     # Update UI to show current party health and status
#     for i in range(party_members.size()):
#         var member = party_members[i]
#         var status_panel = $PartyContainer.get_child(i)
#         status_panel.update_display(member)
# 
# func _on_rest_button_pressed() -> void:
#     # Handle rest action (heal party, apply buffs, etc.)
#     for member in party_members:
#         member.current_health = min(member.max_health, member.current_health + calculate_healing())
#     update_party_status()
#     # Could also advance time, consume resources, etc.
#     GameState.time_of_day += 8  # Rest for 8 hours
# 
# func save_rest_changes() -> void:
#     # Save any changes made during rest
#     GameState.save_game()
#     # Could also trigger autosave or update game state
```

**Features**:
- Basic rest interface
- Back button to return to path selection
- Placeholder for rest mechanics (healing, buffs, etc.)

## 7. Analysis & Improvements

This section provides an overview of the codebase quality and potential areas for enhancement.

### Code Quality

**Strengths**:
- Clean, event-driven architecture
- Good separation of concerns
- Consistent coding style

**Areas for Improvement**:
- Add more error handling
- Reduce hardcoded values
- Improve resource management
- Add more documentation comments

### Performance Considerations
- Scene loading could benefit from object pooling
- Consider preloading frequently used resources
- Optimize signal connections
- Profile and optimize performance-critical sections

### Future Enhancements
- Implement save/load system
- Add sound effects and music
- Expand battle system mechanics
- Add more visual feedback for user actions
- Implement additional game modes
- Add more content (units, items, abilities)

## 8. Appendix

### Code Structure
```
scripts/
├── Core/
│   ├── EventBus.gd
│   ├── SceneManager.gd
│   └── Main.gd
├── UI/
│   ├── BottomBar.gd
│   ├── TopBar.gd
│   └── PathOptions.gd
├── Gacha/
│   ├── GachaMachineUI.gd
│   ├── GachaPoolInspection.gd
│   └── GachaBallDefinition.gd
├── Battle/
│   ├── BattleScene.gd
│   └── PlaceholderUnit.gd
├── Shop/
│   └── ShopScene.gd
└── Rest/
    └── RestScene.gd
```

### Dependencies
- Godot Engine 4.x
- GDScript
- No external dependencies required

---

*Documentation last updated: 2025-06-14*


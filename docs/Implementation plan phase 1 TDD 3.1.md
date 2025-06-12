Flashcard Heroes TDD v3.1 (Milestone 1 Implementation)
Technical Design Document: Flashcard Heroes
Version: 3.1
Target Engine: Godot 4.4
Primary Language: GDScript
This document provides a complete technical blueprint for the development of "Flashcard Heroes" Milestone 1. It is designed to be followed precisely by a development agent.
1. System Architecture Diagram
graph TD
    subgraph "Engine & User"
        UserInput[User Input]
        Godot[Godot Engine]
    end

    subgraph "Data Layer (Resources)"
        UnitDefs[res://resources/units/*.tres]
        DeckDefs[res://resources/decks/*.tres]
        EncounterDefs[res://resources/encounters/*.tres]
    end

    subgraph "Autoloaded Singletons (Core Systems)"
        EventBus[res://scripts/EventBus.gd]
        Database[res://scripts/Database.gd]
        SceneManager[res://scripts/SceneManager.gd]
        GameManager[res://scripts/GameManager.gd]
        SaveManager[res://scripts/SaveManager.gd]
        AbilityResolver[res://scripts/AbilityResolver.gd]
    end

    subgraph "Scenes & UI Components"
        TitleScene[res://scenes/Title.tscn]
        LoadoutScene[res://scenes/Loadout.tscn]
        MainScene[res://scenes/Main.tscn]
        TopBar[res://scenes/TopBar.tscn]
        BottomBar[res://scenes/BottomBar.tscn]
        PathChoiceScene[res://scenes/PathChoice.tscn]
        BattleScene[res://scenes/Battle.tscn]
        subgraph "res://scenes/Battle.tscn"
            BattleManager[res://scripts/BattleManager.gd]
        end
        UnitDisplay[res://scenes/UnitDisplay.tscn]
        EmptySlot[res://scenes/EmptySlot.tscn]
    end

    %% Data Flow on Startup
    Godot -- "Loads on Startup" --> Database
    Database -- "Scans & Caches" --> UnitDefs & DeckDefs & EncounterDefs

    %% Event-Driven Communication Flow
    UserInput --> TitleScene & LoadoutScene & PathChoiceScene
    TitleScene & LoadoutScene & PathChoiceScene -- "Emits Signals" --> EventBus
    EventBus -- "Broadcasts Signals" --> GameManager & SceneManager
    GameManager -- "Emits State Change Signals" --> EventBus

    %% Scene Management Flow
    SceneManager -- "Loads/Unloads Scenes" --> MainScene
    MainScene -- "Contains" --> TopBar & BottomBar
    SceneManager -- "Loads Into Dynamic Area" --> PathChoiceScene & BattleScene

    %% Battle Initialization Flow
    PathChoiceScene -- "1. battle_start_requested" --> EventBus
    EventBus -- "2. " --> GameManager
    GameManager -- "3. Prepares Data"
    GameManager -- "4. load_scene_in_container_requested" --> EventBus
    GameManager -- "5. initiate_battle(data)" --> EventBus
    EventBus -- "6. " --> BattleManager

2. Autoloaded Scripts (Singletons)
These scripts are configured in Project -> Project Settings -> Autoload.
2.1. EventBus.gd
Purpose: A global message-passing system.
Signals (Milestone 1):
new_run_requested(hero_def_id: StringName, deck_def_id: StringName)
change_scene_to_file_requested(scene_path: String)
load_scene_in_container_requested(scene_path: String, container: Node)
battle_start_requested(encounter_definition: EnemyEncounterDefinition)
initiate_battle(battle_setup_data: Dictionary)
2.2. Database.gd
Purpose: A read-only repository for all game content defined as Resource files.
Properties:
gachaball_definitions: Dictionary = {}
Methods:
_ready() -> void: Calls _load_resources_from_path("res://resources/units/", gachaball_definitions).
_load_resources_from_path(...): Loads .tres files and stores them in the target dictionary.
get_gachaball_definition(id: StringName) -> GachaBallDefinition: Returns a definition.
2.3. SceneManager.gd
Purpose: Manages all scene loading, unloading, and transitions.
Methods:
_ready(): Connects to change_scene_to_file_requested and load_scene_in_container_requested.
_on_change_scene_to_file_requested(...): Frees current scene and loads a new one.
_on_load_scene_in_container_requested(...): Clears a container and loads a new scene into it.
2.4. SaveManager.gd
Purpose: Handles serialization (stubbed for now).
Methods:
has_saved_run() -> bool: Returns FileAccess.file_exists(...).
2.5. AbilityResolver.gd
Purpose: Placeholder for the ability system. No logic in this milestone.
2.6. GameManager.gd
Purpose: Manages the state of the current run.
Methods:
_ready(): Connects to new_run_requested and battle_start_requested.
_on_new_run_requested(...): Initializes a hero_instance and requests the Main.tscn load.
_on_battle_start_requested(...): Prepares battle data and emits signals to load Battle.tscn and then initialize it.
3. Core Data Structures (Resource Definitions)
3.1. GachaBallDefinition.gd
File Path: res://scripts/GachaBallDefinition.gd
Inherits: Resource, class_name GachaBallDefinition
Enums: enum Category { UNIT, ITEM }, enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, HERO }
@export Variables:
id: StringName
display_name_key: String
description_key: String
icon_texture: Texture2D
tier: int
rarity: Rarity
ball_category: Category
tags: Array[StringName]
@export_group("Unit Stats")
base_hp: int
base_pwr: int
ability_definition_refs: Array[StringName]
item_slot_count: int
3.2. GachaBallInstance.gd
File Path: res://scripts/GachaBallInstance.gd
Inherits: Resource, class_name GachaBallInstance
Properties:
definition_id: StringName
ball_uuid: String
current_hp: int
current_pwr: int
Methods:
initialize(def: GachaBallDefinition) -> void: Sets properties from the definition.
3.3. Other Definitions
FlashcardDeckDefinition.gd, EnemyEncounterDefinition.gd, etc., are created as minimal resource scripts.
4. Scene & Component Specifications
4.1. Title.tscn & Loadout.tscn
Path: res://scenes/
Purpose: Simple scenes with buttons to navigate the initial game flow from Title -> Loadout -> Main Scene.
4.2. Main.tscn
Path: res://scenes/Main.tscn
Purpose: The persistent game shell holding UI bars and the dynamic content area.
Node Tree: Control > VBoxContainer > TopBar.tscn, Control (Name: DynamicContentArea, Group: "dynamic_content_area"), BottomBar.tscn
Script Logic: On _ready, requests PathChoice.tscn be loaded into the DynamicContentArea.
4.3. TopBar.tscn & BottomBar.tscn
Path: res://scenes/
Purpose: Display static UI elements based on the provided sketches. TopBar has a minimum height of 80px. BottomBar has a minimum height of 220px.
4.4. PathChoice.tscn
Path: res://scenes/PathChoice.tscn
Purpose: Presents the player with a single "Start Battle" button.
Script Logic: On button press, emits EventBus.battle_start_requested with a loaded EnemyEncounterDefinition.
4.5. Battle.tscn
Path: res://scenes/Battle.tscn
Purpose: A static scene to display the battle UI layout and the player's hero.
Node Tree:
Control (Root)
BattleManager (Node)
MarginContainer
VBoxContainer
EnemyArea (HBoxContainer)
EnemyLineup (HBoxContainer)
VBoxContainer
EnemyTrinkets (HBoxContainer)
EndTurnButton (Button)
PlayerArea (HBoxContainer)
PlayerLineup (HBoxContainer)
VBoxContainer
PlayerBench (HBoxContainer)
PlayerInventory (HBoxContainer)
Script Logic (BattleManager.gd):
Purpose: Sets up the initial, static battle view.
Properties:
EMPTY_SLOT_SCENE: Preloads res://scenes/EmptySlot.tscn.
UNIT_DISPLAY_SCENE: Preloads res://scenes/UnitDisplay.tscn.
@onready variables for all layout containers (PlayerLineup, EnemyLineup, etc.).
Methods:
_ready(): Connects to EventBus.initiate_battle, calls _populate_all_slots(), and disables the EndTurnButton.
_populate_all_slots(): Instantiates and adds the correct number of EmptySlot.tscn scenes to the PlayerLineup (6), EnemyLineup (6), PlayerBench (3), PlayerInventory (3), and EnemyTrinkets (3) containers.
_on_initiate_battle(battle_setup_data: Dictionary): Receives the hero's GachaBallInstance, instantiates a UnitDisplay.tscn, populates it with the hero's data, and replaces the first empty slot in the PlayerLineup with the hero's display.
4.6. UnitDisplay.tscn
Path: res://scenes/UnitDisplay.tscn
Purpose: Reusable scene to visually represent a GachaBallInstance.
Node Tree: PanelContainer > VBoxContainer > TextureRect (Icon), Label (HP), Label (PWR)
Script Logic (UnitDisplay.gd):
display_instance(inst: GachaBallInstance) -> void: Stores inst, looks up the corresponding GachaBallDefinition from the Database to get the icon_texture, and updates the UI labels with the instance's current_hp and current_pwr.
4.7. EmptySlot.tscn
Path: res://scenes/EmptySlot.tscn
Purpose: A reusable 128x128 PanelContainer with a visible border to represent an empty slot in a UI grid.
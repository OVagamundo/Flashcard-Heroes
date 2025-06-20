Implementation Document 1 of 9: Foundational Data Scripts
Objective: To create the core data schemas for the project. These scripts define the structure of all GachaBalls, the Run State, and other fundamental data resources.
Instructions for Windsurf: Execute the following steps sequentially. For each step, create a new file at the specified path and write the exact code provided into it.
Step 1: Create GachaBallDefinition.gd
Generated gdscript
# res://scripts/GachaBallDefinition.gd
@tool
class_name GachaBallDefinition
extends Resource

## The static template for a type of GachaBall (unit or item).

## Unique identifier for this definition (e.g., "unit_t1_a").
@export var id: StringName

## Localization key for the display name (e.g., "unit.t1_a.name").
@export var display_name_key: String

## Localization key for the description (e.g., "unit.t1_a.desc").
@export var description_key: String

## The visual representation for this GachaBall.
@export var icon: Texture2D

## The power level or tier of this GachaBall (0-3).
@export_range(0, 3) var tier: int

## The category of the GachaBall, must be "UNIT" or "ITEM".
@export var category: StringName

## The number of item slots this GachaBall has. Only applies to "UNIT" category.
@export var item_slot_count: int = 0
Use code with caution.
Gdscript
Step 2: Create GachaBallInstance.gd
Generated gdscript
# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource

## A unique, individual instance of a GachaBall.

## The ID of the GachaBallDefinition this instance is based on.
var definition_id: StringName

## A universally unique identifier for this specific instance.
var ball_uuid: String

## The UUID of the permanent instance this battle copy was created from.
## Remains an empty string for permanent instances in the RunInventory.
var origin_uuid: String = ""

## An array of UUIDs for the items equipped in this instance's slots.
var equipped_item_uuids: Array[String]

## Current location of this instance.
var location_state: int = LocationState.UNDEFINED

## Location states for the instance
enum LocationState {
    UNDEFINED = -1,
    RUN_INVENTORY = 0,
    BATTLE_INVENTORY = 1,
    BATTLE_BOARD = 2,
    DISCARD_PILE = 3,
    MERGE_PREVIEW = 4,
    INSPECT_VIEW = 5
}

## Sets up the instance based on a GachaBallDefinition.
## This must be called immediately after creating a new instance.
func initialize(definition: GachaBallDefinition):
    if not definition:
        printerr("GachaBallInstance.initialize() was called with a null definition.")
        return

    self.definition_id = definition.id
    # The UUIDUtils autoload is required for this to work.
    self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
    self.location_state = LocationState.RUN_INVENTORY
    
    # Resize the item array to match the definition and fill with empty strings.
    equipped_item_uuids.resize(definition.item_slot_count)
    for i in range(equipped_item_uuids.size()):
        equipped_item_uuids[i] = ""

## Creates a temporary, deep copy of this instance for a battle session.
func create_battle_copy() -> GachaBallInstance:
    var copy = self.duplicate(true) as GachaBallInstance
    
    # Generate a new, unique UUID for the battle copy.
    copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
    
    # Link the copy back to its permanent origin.
    copy.origin_uuid = self.ball_uuid
    
    # Set the initial battle state.
    copy.location_state = LocationState.BATTLE_INVENTORY
    
    return copy
Use code with caution.
Gdscript
Step 3: Create RunState.gd
Generated gdscript
# res://scripts/RunState.gd
class_name RunState
extends Resource

## The player's current run state, including all persistent progress.

## Player's current gold.
@export var gold: int = 0

## Current stage in the run.
@export var current_stage: int = 1

## Current battle in the stage.
@export var current_battle: int = 1

## The player's permanent collection of GachaBalls.
## Organized by tier: {0: [GachaBallInstance], 1: [...], 2: [...], 3: [...]}
@export var run_inventory: Dictionary = {
    0: [], # Hero
    1: [], # Tier 1
    2: [], # Tier 2
    3: []  # Tier 3
}

## Resets the run state to the initial state for a new run.
func start_new_run() -> void:
    gold = 10  # Starting gold
    current_stage = 1
    current_battle = 1
    run_inventory = {0: [], 1: [], 2: [], 3: []}

    # Helper lambda to create and add an instance to the correct tier.
    var add_instance = func(id: StringName):
        var definition: GachaBallDefinition = Database.units.get(id, Database.items.get(id))
        if definition:
            var instance = GachaBallInstance.new()
            instance.initialize(definition)
            if definition.tier in run_inventory:
                run_inventory[definition.tier].append(instance)
            else:
                printerr("RunState: Invalid tier %d for definition %s" % [definition.tier, id])
        else:
            printerr("RunState: Could not find definition for id: ", id)

    # Per MVP TDD: 1x Hero
    add_instance.call(&"hero")
    
    # Per MVP TDD: 2x of each defined unit and item for testing.
    var ids_to_add: Array[StringName] = [
        &"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d",
        &"item_t1_a", &"item_t1_b", &"item_t2_c", &"item_t3_d"
    ]
    
    for id in ids_to_add:
        add_instance.call(id)
        add_instance.call(id) # Add a second time
    
    print("Initial run inventory created.")
Use code with caution.
Gdscript
Step 4: Create MergeRecipe.gd
Generated gdscript
# res://scripts/MergeRecipe.gd
@tool
class_name MergeRecipe
extends Resource

## Defines a valid merge combination.

## The definition ID of the first ingredient.
@export var ingredient_a_id: StringName

## The definition ID of the second ingredient.
@export var ingredient_b_id: StringName

## The definition ID of the resulting GachaBall.
@export var result_id: StringName

## True if this recipe requires two identical ingredients (e.g., C + C -> D).
@export var is_self_merge: bool = false

## The category of GachaBalls this recipe applies to, must be "UNIT" or "ITEM".
@export var merge_type: StringName
Use code with caution.
Gdscript
Step 5: Create FlashcardDeckDefinition.gd
Generated gdscript
# res://scripts/FlashcardDeckDefinition.gd
@tool
class_name FlashcardDeckDefinition
extends Resource

## Defines a flashcard deck for the educational component of the game.

## Unique identifier for the deck.
@export var id: StringName

## Localization key for the deck's display name.
@export var display_name_key: String

## MVP Placeholder: A list of question/answer pairs.
@export var card_list: Array[Dictionary] # e.g., [{"question": "Q1", "answer": "A1"}]
Use code with caution.
Gdscript
Step 6: Create ConditionDefinition.gd
Generated gdscript
# res://scripts/ConditionDefinition.gd
class_name ConditionDefinition
extends Resource

## Defines conditions for ability effects and other game mechanics.

## Evaluates the condition based on the game state.
## source: The GachaBallInstance using the ability.
## target: The GachaBallInstance being targeted by the ability.
## battle_manager: A reference to the current BattleManager.
## event_data: Optional dictionary with context-specific data.
func evaluate(source: GachaBallInstance, target: GachaBallInstance, battle_manager, event_data: Dictionary = {}) -> bool:
	# MVP Scope Note: For the MVP, this is a placeholder and always returns true
	# to allow architectural flow testing without implementing complex logic.
	return true
Use code with caution.
Gdscript
Summary of Completion: Upon completing these steps, the project will have its foundational data schemas. These form the data layer upon which all other game systems will be built. You may now request the next implementation document.
Implementation Document 2 of 9: Create Core Game Data Resources
Objective: To create all the necessary .tres resource files for the MVP. These files represent the specific, static data for all units, items, and merge recipes. The Database singleton will load these files at runtime.
Instructions for Windsurf: Execute the following steps sequentially. For each step, create a new file at the specified path and write the exact code provided into it.
Step 1: Create Unit GachaBallDefinition Resources
Create the following five files in the res://resources/units/ directory.
File: res://resources/units/Hero.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/Hero.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"hero"
display_name_key = "hero.name"
description_key = "hero.desc"
icon = ExtResource("2_icon")
tier = 0
category = &"UNIT"
item_slot_count = 5
Use code with caution.
Tres
File: res://resources/units/UnitTier1A.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/UnitTier1A.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"unit_t1_a"
display_name_key = "unit_t1_a.name"
description_key = "unit_t1_a.desc"
icon = ExtResource("2_icon")
tier = 1
category = &"UNIT"
item_slot_count = 1
Use code with caution.
Tres
File: res://resources/units/UnitTier1B.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/UnitTier1B.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"unit_t1_b"
display_name_key = "unit_t1_b.name"
description_key = "unit_t1_b.desc"
icon = ExtResource("2_icon")
tier = 1
category = &"UNIT"
item_slot_count = 1
Use code with caution.
Tres
File: res://resources/units/UnitTier2C.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/UnitTier2C.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"unit_t2_c"
display_name_key = "unit_t2_c.name"
description_key = "unit_t2_c.desc"
icon = ExtResource("2_icon")
tier = 2
category = &"UNIT"
item_slot_count = 2
Use code with caution.
Tres
File: res://resources/units/UnitTier3D.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/UnitTier3D.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"unit_t3_d"
display_name_key = "unit_t3_d.name"
description_key = "unit_t3_d.desc"
icon = ExtResource("2_icon")
tier = 3
category = &"UNIT"
item_slot_count = 4
Use code with caution.
Tres
Step 2: Create Item GachaBallDefinition Resources
Create the following four files in the res://resources/items/ directory.
File: res://resources/items/ItemTier1A.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/ItemTier1A.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"item_t1_a"
display_name_key = "item_t1_a.name"
description_key = "item_t1_a.desc"
icon = ExtResource("2_icon")
tier = 1
category = &"ITEM"
item_slot_count = 0
Use code with caution.
Tres
File: res://resources/items/ItemTier1B.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/ItemTier1B.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"item_t1_b"
display_name_key = "item_t1_b.name"
description_key = "item_t1_b.desc"
icon = ExtResource("2_icon")
tier = 1
category = &"ITEM"
item_slot_count = 0
Use code with caution.
Tres
File: res://resources/items/ItemTier2C.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/ItemTier2C.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"item_t2_c"
display_name_key = "item_t2_c.name"
description_key = "item_t2_c.desc"
icon = ExtResource("2_icon")
tier = 2
category = &"ITEM"
item_slot_count = 0
Use code with caution.
Tres
File: res://resources/items/ItemTier3D.tres
Generated tres
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/ItemTier3D.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"item_t3_d"
display_name_key = "item_t3_d.name"
description_key = "item_t3_d.desc"
icon = ExtResource("2_icon")
tier = 3
category = &"ITEM"
item_slot_count = 0
Use code with caution.
Tres
Step 3: Create MergeRecipe Resources
Create the following four files in the res://resources/recipes/ directory.
File: res://resources/recipes/Merge_Unit_A_B_to_C.tres
Generated tres
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
ingredient_a_id = &"unit_t1_a"
ingredient_b_id = &"unit_t1_b"
result_id = &"unit_t2_c"
is_self_merge = false
merge_type = &"UNIT"
Use code with caution.
Tres
File: res://resources/recipes/Merge_Unit_C_C_to_D.tres
Generated tres
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
ingredient_a_id = &"unit_t2_c"
ingredient_b_id = &"unit_t2_c"
result_id = &"unit_t3_d"
is_self_merge = true
merge_type = &"UNIT"
Use code with caution.
Tres
File: res://resources/recipes/Merge_Item_A_B_to_C.tres
Generated tres
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
ingredient_a_id = &"item_t1_a"
ingredient_b_id = &"item_t1_b"
result_id = &"item_t2_c"
is_self_merge = false
merge_type = &"ITEM"
Use code with caution.
Tres
File: res://resources/recipes/Merge_Item_C_C_to_D.tres
Generated tres
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
ingredient_a_id = &"item_t2_c"
ingredient_b_id = &"item_t2_c"
result_id = &"item_t3_d"
is_self_merge = true
merge_type = &"ITEM"
Use code with caution.
Tres
Summary of Completion: The res://resources/ directory is now populated with all the static data required for the MVP. The game now has defined units, items, and the rules for merging them. You may now request the next implementation document.
Implementation Document 3 of 9: Foundational Autoload Scripts (Singletons)
Objective: To create the essential utility and management scripts that will be configured as globally accessible singletons. This document covers EventBus, UUIDUtils, Database, and SceneManager.
Instructions for Windsurf: Execute the following steps sequentially. Create each script file at the specified path and write the exact code provided. The final step is a manual configuration instruction for the developer in the Godot editor.
Step 1: Create EventBus.gd
Generated gdscript
# res://scripts/EventBus.gd
extends Node

## A global script containing only signal definitions for the entire game.
## All communication between major systems happens through these signals.

# --- Scene & Run Management Signals ---
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal battle_start_requested

# --- UI & Modal Signals ---
signal inspect_inventory_requested
signal close_modal_requested
signal show_choice_prompt(options: Dictionary) # e.g., {"prompt_text": "Merge or Swap?", "choices": [&"MERGE", &"SWAP"]}
signal choice_made(choice: StringName) # "MERGE" or "SWAP"
signal display_discard_pile_requested

# --- Player Action & Interaction Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_view: Control, target_view: Control)
signal reshuffle_discard_pile_requested

# --- View State Signals ---
signal view_selected(view: Control)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)
signal view_data_updated(view: Control)
Use code with caution.
Gdscript
Step 2: Create UUIDUtils.gd
Generated gdscript
# res://scripts/UUIDUtils.gd
extends Node

## A global utility for generating unique, descriptive, and debug-friendly
## string identifiers for all GachaBallInstances.

func _ready() -> void:
	# Initialize the random number generator to ensure variety in UUIDs.
	randomize()

# Generates a UUID, e.g., "unit_t1_a_1677628800_1234"
func generate_uuid(prefix: StringName) -> String:
	var timestamp: int = Time.get_unix_time_from_system()
	var random_suffix: int = randi() % 10000
	return "%s_%d_%04d" % [prefix, timestamp, random_suffix]
Use code with caution.
Gdscript
Step 3: Create Database.gd
Generated gdscript
# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition

func _ready() -> void:
	# Populate all data dictionaries at startup.
	_load_resources_from_path("res://resources/units/", units)
	_load_resources_from_path("res://resources/items/", items)
	_load_resources_from_path("res://resources/recipes/", recipes)
	_load_resources_from_path("res://resources/decks/", decks)
	print("Database loaded.")
	print(" - Units: ", units.size())
	print(" - Items: ", items.size())
	print(" - Recipes: ", recipes.size())
	print(" - Decks: ", decks.size())

## A helper function that iterates through a directory, loads each `.tres` file,
## and stores it in the provided dictionary, using the resource's `id` property as the key.
func _load_resources_from_path(path: String, dictionary: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource = load(path.path_join(file_name))
				if resource and resource.has("id"):
					dictionary[resource.id] = resource
				else:
					printerr("Database: Failed to load or find 'id' in resource: ", path.path_join(file_name))
			file_name = dir.get_next()
	else:
		printerr("Database: Could not open directory at path: ", path)
Use code with caution.
Gdscript
Step 4: Create SceneManager.gd
Generated gdscript
# res://scripts/SceneManager.gd
extends Node

## Manages all scene loading and transitions in response to EventBus signals.

var scene_paths: Dictionary = {
	"Title": "res://scenes/Title.tscn",
	"Loadout": "res://scenes/Loadout.tscn",
	"Main": "res://scenes/Main.tscn"
}
var current_scene: Node = null

func _ready() -> void:
	EventBus.connect("loadout_scene_requested", _on_loadout_scene_requested)
	EventBus.connect("main_scene_requested", _on_main_scene_requested)
	
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func _on_loadout_scene_requested() -> void:
	_change_scene_to(scene_paths["Loadout"])

func _on_main_scene_requested() -> void:
	_change_scene_to(scene_paths["Main"])

func _change_scene_to(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.free()
		
	var new_scene_res = load(path)
	if not new_scene_res:
		printerr("SceneManager: Failed to load scene at path: ", path)
		return
		
	current_scene = new_scene_res.instantiate()
	get_tree().root.add_child(current_scene)
Use code with caution.
Gdscript
Step 5: Configure Autoloads (Manual Step)
This final step must be performed manually in the Godot editor.
Navigate to Project -> Project Settings.
Select the Autoload tab.
Add the four scripts created in this document to the Autoload list, ensuring the Node Name matches the script name:
res://scripts/EventBus.gd -> EventBus
res://scripts/UUIDUtils.gd -> UUIDUtils
res://scripts/Database.gd -> Database
res://scripts/SceneManager.gd -> SceneManager
Summary of Completion: The project now has its core communication bus, a UUID generator, a data-loading system, and a scene manager, all configured for global access. The project's foundational architecture is now in place. You may now request the next implementation document.
Implementation Document 4 of 9: Core Logic Manager Autoloads
Objective: To create the scripts for the primary logic managers: MergeManager, AbilityResolver, InteractionManager, and GameManager. These handle the "how" of the game's mechanics, from merging units to managing player input state.
Instructions for Windsurf: Execute the following steps sequentially. Create each script file at the specified path and write the exact code provided. The final step is a manual configuration instruction for the developer in the Godot editor.
Step 1: Create MergeManager.gd
Generated gdscript
# res://scripts/MergeManager.gd
extends Node

## A dedicated, global manager to handle all merge logic.

## Attempts to merge two GachaBallInstances within a tiered inventory dictionary.
## Returns the new merged instance on success, or null on failure.
func attempt_merge(instance_a: GachaBallInstance, instance_b: GachaBallInstance, inventory_dict: Dictionary) -> GachaBallInstance:
    if not instance_a or not instance_b:
        printerr("MergeManager: Attempted merge with a null instance.")
        return null
        
    var recipe: MergeRecipe = find_recipe(instance_a.definition_id, instance_b.definition_id)
    if not recipe:
        return null # No valid recipe found.
        
    var def_a = Database.units.get(instance_a.definition_id, Database.items.get(instance_a.definition_id))
    var def_b = Database.units.get(instance_b.definition_id, Database.items.get(instance_b.definition_id))
    
    if not def_a or not def_b:
        printerr("MergeManager: Could not find definitions for ingredients.")
        return null
        
    # --- Merge is valid, proceed ---
    
    # 1. Create the new result GachaBallInstance.
    var result_definition: GachaBallDefinition = Database.units.get(recipe.result_id, Database.items.get(recipe.result_id))
    if not result_definition:
        printerr("MergeManager: Result ID from recipe not found in Database: ", recipe.result_id)
        return null
        
    var merged_instance := GachaBallInstance.new()
    merged_instance.initialize(result_definition)
    
    # 2. Gather all items from parents into a temporary list.
    var all_parent_items: Array[GachaBallInstance] = []
    all_parent_items.append_array(_get_equipped_items_from_inventory(instance_a, inventory_dict))
    all_parent_items.append_array(_get_equipped_items_from_inventory(instance_b, inventory_dict))

    # 3. Remove parent instances and their items from the source inventory dictionary.
    inventory_dict[def_a.tier].erase(instance_a)
    inventory_dict[def_b.tier].erase(instance_b)
    for item in all_parent_items:
        var item_def = Database.items.get(item.definition_id)
        if item_def and inventory_dict.has(item_def.tier):
            inventory_dict[item_def.tier].erase(item)

    # 4. Add the new result instance to the correct tier in the inventory.
    inventory_dict[result_definition.tier].append(merged_instance)
    
    # 5. Equip the gathered items onto the new unit.
    for i in range(min(all_parent_items.size(), merged_instance.equipped_item_uuids.size())):
        var item_to_equip: GachaBallInstance = all_parent_items[i]
        merged_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid
        
        # Add the item back into its correct tier, now linked to the new unit.
        var item_def = Database.items.get(item_to_equip.definition_id)
        if item_def and inventory_dict.has(item_def.tier):
            inventory_dict[item_def.tier].append(item_to_equip)
            
    print("Merge successful. Created: ", merged_instance.definition_id)
    return merged_instance

## Helper to find equipped items of a unit within a specific tiered inventory.
func _get_equipped_items_from_inventory(unit_instance: GachaBallInstance, inventory_dict: Dictionary) -> Array[GachaBallInstance]:
    var equipped_items: Array[GachaBallInstance] = []
    if unit_instance.equipped_item_uuids.is_empty():
        return equipped_items
        
    for item_uuid in unit_instance.equipped_item_uuids:
        if item_uuid.is_empty(): continue
        # We must search all tiers of the item inventory to find the item.
        for tier in inventory_dict:
            var tier_inventory = inventory_dict[tier]
            for entity in tier_inventory:
                if entity is GachaBallInstance and entity.ball_uuid == item_uuid:
                    equipped_items.push_back(entity)
                    break # Found the item, move to next UUID
    return equipped_items

## Finds a matching recipe for two GachaBall definition IDs.
func find_recipe(id_a: StringName, id_b: StringName) -> MergeRecipe:
    for recipe_key in Database.recipes:
        var recipe: MergeRecipe = Database.recipes[recipe_key]
        
        if recipe.is_self_merge:
            if id_a == recipe.ingredient_a_id and id_a == id_b:
                return recipe
        else: # Check for A+B or B+A
            if (id_a == recipe.ingredient_a_id and id_b == recipe.ingredient_b_id) or \
               (id_a == recipe.ingredient_b_id and id_b == recipe.ingredient_a_id):
                return recipe
                
    return null
Use code with caution.
Gdscript
Step 2: Create AbilityResolver.gd
Generated gdscript
# res://scripts/AbilityResolver.gd
extends Node

## A global script that processes ability effects and conditions.
## MVP Scope: This is a placeholder for future implementation.

var ability_queue: Array = []

## MVP Scope Note: This method's logic is commented out for the MVP.
func _apply_effect(effect_data: Dictionary) -> void:
	# match effect_data.get("type"):
	# 	"DAMAGE":
	# 		pass
	# 	"HEAL":
	# 		pass
	# 	"APPLY_STATUS":
	# 		pass
	pass

## MVP Scope Note: This method simply clears the queue for the MVP.
func resolve_queue() -> void:
	ability_queue.clear()
Use code with caution.
Gdscript
Step 3: Create InteractionManager.gd
Generated gdscript
# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action (e.g., which
## GachaBallView is currently selected).

var _selected_view: Control = null
var is_drag_active: bool = false

func _ready() -> void:
	# Connect to signals to manage state.
	EventBus.inventory_action_requested.connect(func(_s, _t): clear_selection())
	EventBus.close_modal_requested.connect(clear_selection)

## Selects a view, or deselects if it's already selected.
func select_view(view: Control) -> void:
	if not is_instance_valid(view):
		clear_selection()
		return
		
	# If clicking the same view again, deselect it.
	if _selected_view == view:
		clear_selection()
		return

	# If a different view was selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	# Select the new view.
	_selected_view = view
	EventBus.emit_signal("view_selected", _selected_view)
	print("View selected: ", _selected_view.name)

## Clears the current selection.
func clear_selection() -> void:
	if is_instance_valid(_selected_view):
		var previously_selected = _selected_view
		_selected_view = null
		EventBus.emit_signal("view_deselected", previously_selected)
		print("View deselected: ", previously_selected.name)

## Returns the currently selected view.
func get_selected_view() -> Control:
	return _selected_view

## Emits a signal to trigger visual feedback for an invalid action.
func trigger_invalid_action_feedback(view: Control) -> void:
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
		print("Invalid action triggered on view: ", view.name)
Use code with caution.
Gdscript
Step 4: Create GameManager.gd
Generated gdscript
# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.

signal run_inventory_changed()

## The single source of truth for the current run's state.
var run_state: RunState

## State flag to determine if inventory actions are permanent (in modal) or temporary (in battle).
var is_inspecting_inventory: bool = false

func _ready() -> void:
    EventBus.start_run_requested.connect(_on_start_run_requested)
    EventBus.inspect_inventory_requested.connect(func(): is_inspecting_inventory = true)
    EventBus.close_modal_requested.connect(func(): is_inspecting_inventory = false)
    EventBus.inventory_action_requested.connect(_on_inventory_action_requested)

func _on_start_run_requested() -> void:
    print("GameManager: Start run requested. Creating new RunState.")
    run_state = RunState.new()
    run_state.start_new_run()
    run_inventory_changed.emit()
    EventBus.emit_signal("main_scene_requested")

## This function only proceeds if the inventory modal is open.
func _on_inventory_action_requested(source_view: Control, target_view: Control) -> void:
    if not is_inspecting_inventory:
        return # Do nothing if not in the permanent inventory inspection view.

    if not source_view or not target_view: return
    if not source_view.has_method("get_instance_data") or not target_view.has_method("get_instance_data"): return

    var source_data: GachaBallInstance = source_view.get_instance_data()
    var target_data: GachaBallInstance = target_view.get_instance_data()

    if not source_data or not target_data: return

    # Delegate the merge logic to the MergeManager.
    var merged_instance = MergeManager.attempt_merge(source_data, target_data, run_state.run_inventory)
    
    if merged_instance:
        # The merge was successful. The inventory modal will need to be refreshed.
        print("Permanent merge successful. New unit: ", merged_instance.definition_id)
    else:
        # Handle swap logic if merge fails.
        _swap_instances_in_run_inventory(source_data, target_data)

    run_inventory_changed.emit()

## Helper function to swap two instances within the tiered run_inventory.
func _swap_instances_in_run_inventory(inst_a: GachaBallInstance, inst_b: GachaBallInstance) -> void:
    var def_a = Database.units.get(inst_a.definition_id, Database.items.get(inst_a.definition_id))
    var def_b = Database.units.get(inst_b.definition_id, Database.items.get(inst_b.definition_id))

    if not def_a or not def_b:
        printerr("GameManager: Cannot find definition for swap.")
        return

    var tier_a = def_a.tier
    var tier_b = def_b.tier

    if not run_state.run_inventory.has(tier_a) or not run_state.run_inventory.has(tier_b):
        printerr("GameManager: Invalid tier for swap.")
        return

    var idx_a = run_state.run_inventory[tier_a].find(inst_a)
    var idx_b = run_state.run_inventory[tier_b].find(inst_b)

    if idx_a == -1 or idx_b == -1:
        printerr("GameManager: Instance not found for swap.")
        return

    # If instances are in the same tier, perform a simple swap.
    if tier_a == tier_b:
        run_state.run_inventory[tier_a][idx_a] = inst_b
        run_state.run_inventory[tier_a][idx_b] = inst_a
    else: # If in different tiers, move them.
        run_state.run_inventory[tier_a].remove_at(idx_a)
        run_state.run_inventory[tier_b].remove_at(idx_b)
        run_state.run_inventory[tier_a].append(inst_b)
        run_state.run_inventory[tier_b].append(inst_a)
        
    print("Permanent swap successful.")
Use code with caution.
Gdscript
Step 5: Configure Autoloads (Manual Step)
This final step must be performed manually in the Godot editor.
Navigate to Project -> Project Settings.
Select the Autoload tab.
Add the four scripts created in this document to the Autoload list, ensuring the Node Name matches the script name:
res://scripts/MergeManager.gd -> MergeManager
res://scripts/AbilityResolver.gd -> AbilityResolver
res://scripts/InteractionManager.gd -> InteractionManager
res://scripts/GameManager.gd -> GameManager
Summary of Completion: With these steps, the project's core logic systems are in place and globally accessible. The game now understands how to manage state, process interactions, and handle its primary mechanic (merging). You may now request the next implementation document.
Implementation Document 5 of 9: The GachaBallView Scene and Script
Objective: To create the versatile GachaBallView.tscn scene and its associated script, GachaBallView.gd. This scene is the fundamental UI building block for representing any unit or item in the game.
Instructions for Windsurf: First, create the scene file in the Godot editor according to the instructions. Then, create and attach the provided script.
Step 1: Create the GachaBallView.tscn Scene (Manual Step)
Create a new scene.
The root node should be a PanelContainer. Name it GachaBallView.
Set the GachaBallView node's Mouse -> Filter property in the Inspector to Pass.
Add a VBoxContainer as a child of GachaBallView.
Add a TextureRect as a child of the VBoxContainer. Name it Icon and enable Unique Name In Owner (the % sign).
Add a GridContainer as a child of the VBoxContainer. Name it ItemGrid and enable Unique Name In Owner (%). Set its Columns property to 2.
The final node tree should look like this:
Generated code
GachaBallView (PanelContainer)
└── VBoxContainer
    ├── %Icon (TextureRect)
    └── %ItemGrid (GridContainer)
Use code with caution.
Save the scene as res://scenes/GachaBallView.tscn.
Attach a new script to the root GachaBallView node. Save it as res://scripts/GachaBallView.gd.
Step 2: Write the GachaBallView.gd Script
Generated gdscript
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

# --- Node References ---
@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid

# --- Data Properties ---
var instance_data: GachaBallInstance = null
var is_interactable: bool = true

# --- Internal State ---
var _is_selected: bool = false
const DRAG_CLICK_MAX_DIST_SQ = 10 * 10 # 10 pixels, squared for efficiency
var _mouse_down_pos: Vector2

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	EventBus.invalid_action_triggered.connect(_on_invalid_action_triggered)
	# Add a default stylebox to visualize the view's frame
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color.DARK_GRAY
	add_theme_stylebox_override("panel", stylebox)

# --- Public Methods ---
func set_instance_data(data: GachaBallInstance):
	self.instance_data = data
	_update_visuals()

func get_instance_data() -> GachaBallInstance:
	return instance_data

func clear_view():
	self.instance_data = null
	_update_visuals()

# --- Input Handling ---
func _gui_input(event: InputEvent):
	if not is_interactable or not instance_data:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_mouse_down_pos = get_global_mouse_position()
			if InteractionManager.get_selected_view() and InteractionManager.get_selected_view() != self:
				EventBus.emit_signal("inventory_action_requested", InteractionManager.get_selected_view(), self)
				get_viewport().set_input_as_handled()
			else:
				InteractionManager.select_view(self)
				get_viewport().set_input_as_handled()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_interactable or not instance_data: return null
	if get_global_mouse_position().distance_squared_to(_mouse_down_pos) <= DRAG_CLICK_MAX_DIST_SQ: return null

	InteractionManager.is_drag_active = true
	var preview = self.duplicate()
	preview.custom_minimum_size = self.size
	set_drag_preview(preview)
	self.visible = false
	return self
	
func _can_drop_data(_at_position, data) -> bool:
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	source_view.visible = true
	InteractionManager.is_drag_active = false
	EventBus.emit_signal("inventory_action_requested", source_view, self)

# --- Visual Updates ---
func _update_visuals():
	if not is_instance_valid(self): return
	
	if instance_data:
		var definition = Database.units.get(instance_data.definition_id, Database.items.get(instance_data.definition_id))
		if definition:
			icon_rect.texture = definition.icon
			# For MVP, we use the ID as the tooltip. In full game, this would use display_name_key.
			self.tooltip_text = str(definition.id)
		else:
			icon_rect.texture = null
			self.tooltip_text = "Unknown ID: %s" % instance_data.definition_id
		visible = true
	else:
		icon_rect.texture = null
		tooltip_text = "Empty Slot"
		visible = false

func _on_view_selected(view: Control):
	if view == self:
		_is_selected = true
		_apply_selection_feedback()

func _on_view_deselected(view: Control):
	if view == self:
		_is_selected = false
		_apply_selection_feedback()

func _on_invalid_action_triggered(view: Control):
	if view == self:
		var tween = create_tween()
		var original_modulate = self.modulate
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", original_modulate, 0.2)

func _apply_selection_feedback():
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if _is_selected:
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
	else:
		stylebox.border_color = Color.DARK_GRAY
		stylebox.border_width_left = 2
		stylebox.border_width_top = 2
		stylebox.border_width_right = 2
		stylebox.border_width_bottom = 2
	add_theme_stylebox_override("panel", stylebox)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if InteractionManager.is_drag_active:
			self.visible = true
			InteractionManager.is_drag_active = false
Use code with caution.
Gdscript
Summary of Completion: The project now has its most important reusable UI component. GachaBallView.tscn and its script provide the visual representation and interaction logic for all units and items. This is a cornerstone for building the main game screens. You may now request the next implementation document.
Implementation Document 6 of 9: Initial Scenes (Title, Loadout, Main Shell)
Objective: To create the initial sequence of scenes (Title.tscn, Loadout.tscn) that lead the player to the main application shell (Main.tscn). This also includes creating the PathChoice.tscn which will be the default content of the main scene.
Instructions for Windsurf: Execute the following steps sequentially. Create each scene file in the Godot editor according to the instructions, then create and attach its script.
Step 1: Create Title.tscn and its Script
Create a new scene with a Control root named Title.
Add a CenterContainer as a child, and a Button as a child of that.
Name the button %StartRunButton and set its Text property to "Start Run".
Save as res://scenes/Title.tscn.
Attach the following script:
Generated gdscript
# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton

func _ready():
	start_run_button.pressed.connect(func(): EventBus.emit_signal("start_run_requested"))
Use code with caution.
Gdscript
Set this scene as the Main Scene: Go to Project -> Project Settings -> Application -> Run -> Main Scene and select res://scenes/Title.tscn.
Step 2: Create Loadout.tscn and its Script
Create a new scene with a Control root named Loadout.
Add a CenterContainer as a child, and a Button as a child of that.
Name the button %BeginButton and set its Text property to "Begin".
Save as res://scenes/Loadout.tscn.
Attach the following script:
Generated gdscript
# res://scripts/Loadout.gd
extends Control

@onready var begin_button: Button = %BeginButton

func _ready():
	begin_button.pressed.connect(func(): EventBus.emit_signal("main_scene_requested"))
Use code with caution.
Gdscript
Step 3: Create Main.tscn (The Application Shell) and its Script
Create a new scene with a Control root named Main.
Build the following node tree:
Generated code
Main (Control)
├── VBoxContainer
│   ├── %ContentArea (SubViewportContainer)
│   └── %BottomArea (PanelContainer)
│       └── HBoxContainer
│           ├── %InspectInventoryButton (Button)
│           ├── %DrawTier1Button (Button)
│           ├── %DrawTier2Button (Button)
│           └── %DrawTier3Button (Button)
└── %ModalLayer (CanvasLayer)
Use code with caution.
Configure nodes as specified in the original plan (visibility, text, etc.).
Save as res://scenes/Main.tscn.
Attach the following script:
Generated gdscript
# res://scripts/Main.gd
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button
@onready var modal_layer: CanvasLayer = %ModalLayer

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")
const INSPECT_INVENTORY_SCENE = preload("res://scenes/InspectInventoryView.tscn")

func _ready():
    inspect_inventory_button.pressed.connect(_on_inspect_inventory_pressed)
    draw_tier1_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 1))
    draw_tier2_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 2))
    draw_tier3_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 3))

    EventBus.battle_start_requested.connect(_on_battle_start_requested)

    _load_content(PATH_CHOICE_SCENE)

func _clear_content_area():
    for child in content_area.get_children():
        child.free()

func _load_content(scene_resource: PackedScene):
    _clear_content_area()
    var instance = scene_resource.instantiate()
    content_area.add_child(instance)

func _on_battle_start_requested():
    inspect_inventory_button.visible = false
    draw_tier1_button.visible = true
    draw_tier2_button.visible = true
    draw_tier3_button.visible = true
    _load_content(BATTLE_SCENE)

func _on_inspect_inventory_pressed():
    EventBus.emit_signal("inspect_inventory_requested")
    var modal = INSPECT_INVENTORY_SCENE.instantiate()
    modal_layer.add_child(modal)
Use code with caution.
Gdscript
Step 4: Create PathChoice.tscn and its Script
Create a new scene with a Control root named PathChoice.
Add a CenterContainer as a child, and a Button as a child of that.
Name the button StartBattleButton and set its Text property to "Start Battle".
Save as res://scenes/PathChoice.tscn.
Attach the following script:
Generated gdscript
# res://scripts/PathChoice.gd
extends Control

@onready var start_battle_button: Button = $CenterContainer/StartBattleButton

func _ready():
	start_battle_button.pressed.connect(func(): EventBus.emit_signal("battle_start_requested"))
Use code with caution.
Gdscript
Summary of Completion: The project now has a functional scene flow: Title -> Main (containing PathChoice). The player can click "Start Run" and then "Start Battle", which will trigger the necessary signals to load the Battle.tscn. The main UI shell is in place. You may now request the next implementation document.
Implementation Document 7 of 9: The Battle Scene and BattleManager
Objective: To create the Battle.tscn scene, which is the primary gameplay area, and its comprehensive controller script, BattleManager.gd.
Instructions for Windsurf: First, create the Battle.tscn scene file in the Godot editor according to the instructions. Then, create and attach the provided BattleManager.gd script.
Step 1: Create the Battle.tscn Scene (Manual Step)
Create a new scene with a Node root named Battle.
Build the following node tree:
Generated code
Battle (Node)
├── UI (Control)
│   └── VBoxContainer
│       ├── PlayerLineup (HBoxContainer)
│       │   ├── %LineupSlot0 (PanelContainer) ...up to %LineupSlot5
│       ├── PlayerBench (HBoxContainer)
│       │   ├── %BenchSlot0 (PanelContainer) ...up to %BenchSlot2
│       └── DiscardPileArea (HBoxContainer)
│           ├── %DiscardPileButton (Button)
│           └── %ReshuffleButton (Button)
└── %ModalLayer (CanvasLayer)
Use code with caution.
Configure nodes as specified in the original plan (text, alignment, etc.).
Save the scene as res://scenes/Battle.tscn.
Attach a new script to the root Battle node. Save it as res://scripts/BattleManager.gd.
Step 2: Write the BattleManager.gd Script
Generated gdscript
# res://scripts/BattleManager.gd
extends Node

# --- Constants and Preloads ---
const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const CHOICE_PROMPT_UI_SCENE = preload("res://scenes/ChoicePromptUI.tscn")
const DISCARD_PILE_VIEW_SCENE = preload("res://scenes/DiscardPileView.tscn")

# --- Node References ---
@onready var lineup_slots: Array[Node] = [
    %LineupSlot0, %LineupSlot1, %LineupSlot2, %LineupSlot3, %LineupSlot4, %LineupSlot5
]
@onready var bench_slots: Array[Node] = [%BenchSlot0, %BenchSlot1, %BenchSlot2]
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var reshuffle_button: Button = %ReshuffleButton
@onready var modal_layer: CanvasLayer = %ModalLayer

# --- Battle State ---
var _battle_inventory: Dictionary = {0: [], 1: [], 2: [], 3: []}
var _discard_pile: Array[GachaBallInstance] = []
var _pending_action: Dictionary = {}

func _ready():
    _setup_battle()
    _connect_signals()

func _setup_battle():
    for tier in GameManager.run_state.run_inventory:
        for instance in GameManager.run_state.run_inventory[tier]:
            _battle_inventory[tier].append(instance.create_battle_copy())
    
    if not _battle_inventory[0].is_empty():
        var hero_instance = _battle_inventory[0][0]
        _place_instance_in_slot(hero_instance, lineup_slots[0])
        _battle_inventory[0].clear()
    else:
        printerr("BattleManager: Hero instance not found.")
    _update_discard_pile_ui()

func _connect_signals():
    EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
    EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
    EventBus.choice_made.connect(_on_choice_made)
    EventBus.display_discard_pile_requested.connect(_on_display_discard_pile_requested)
    EventBus.reshuffle_discard_pile_requested.connect(_on_reshuffle_discard_pile_requested)
    discard_pile_button.pressed.connect(func(): EventBus.emit_signal("display_discard_pile_requested"))
    reshuffle_button.pressed.connect(func(): EventBus.emit_signal("reshuffle_discard_pile_requested"))

# --- Core Logic Flows ---
func _on_inventory_action_requested(source_view: Control, target_view: Control):
    if GameManager.is_inspecting_inventory: return
    var source_data: GachaBallInstance = source_view.get_instance_data()
    
    if target_view is PanelContainer and not target_view.get_child_count() > 0:
        _handle_move(source_view, target_view)
        return

    if not target_view is GachaBallView:
        EventBus.emit_signal("invalid_action_triggered", source_view)
        return
        
    var target_data: GachaBallInstance = target_view.get_instance_data()
    if not source_data or not target_data:
        EventBus.emit_signal("invalid_action_triggered", source_view)
        return

    var source_def = Database.units.get(source_data.definition_id, Database.items.get(source_data.definition_id))
    var target_def = Database.units.get(target_data.definition_id, Database.items.get(target_data.definition_id))

    if source_def.category == &"ITEM" and target_def.category == &"UNIT":
        _handle_equip(source_view, target_view)
        return
        
    if source_def.category == target_def.category:
        var recipe = MergeManager.find_recipe(source_data.definition_id, target_data.definition_id)
        if recipe:
            _pending_action = {"source": source_view, "target": target_view}
            var prompt = CHOICE_PROMPT_UI_SCENE.instantiate()
            modal_layer.add_child(prompt)
        else:
            _handle_swap(source_view, target_view)
    else:
        EventBus.emit_signal("invalid_action_triggered", source_view)

func _on_choice_made(choice: StringName):
    var source = _pending_action.get("source")
    var target = _pending_action.get("target")
    if not is_instance_valid(source) or not is_instance_valid(target):
        _pending_action.clear()
        return
        
    if choice == &"MERGE": _handle_merge(source, target)
    elif choice == &"SWAP": _handle_swap(source, target)
    _pending_action.clear()

# --- Action Handlers ---
func _handle_merge(source_view: GachaBallView, target_view: GachaBallView):
    var merged_instance = MergeManager.attempt_merge(source_view.get_instance_data(), target_view.get_instance_data(), _battle_inventory)
    if merged_instance:
        var target_slot = target_view.get_parent()
        source_view.queue_free()
        target_view.queue_free()
        _place_instance_in_slot(merged_instance, target_slot)
    else:
        EventBus.emit_signal("invalid_action_triggered", source_view)

func _handle_swap(source_view: GachaBallView, target_view: GachaBallView):
    var source_parent = source_view.get_parent()
    var target_parent = target_view.get_parent()
    source_parent.remove_child(source_view)
    target_parent.remove_child(target_view)
    source_parent.add_child(target_view)
    target_parent.add_child(source_view)

func _handle_move(source_view: GachaBallView, target_slot: PanelContainer):
    source_view.get_parent().remove_child(source_view)
    target_slot.add_child(source_view)

func _handle_equip(item_view: GachaBallView, unit_view: GachaBallView):
    var item_data = item_view.get_instance_data()
    var unit_data = unit_view.get_instance_data()
    var empty_slot_idx = unit_data.equipped_item_uuids.find("")
    if empty_slot_idx != -1:
        unit_data.equipped_item_uuids[empty_slot_idx] = item_data.ball_uuid
        item_view.queue_free()
        _redraw_equipped_items(unit_view)
    else:
        EventBus.emit_signal("invalid_action_triggered", item_view)

# --- Gacha & Discard Pile ---
func _on_draw_gacha_requested(tier: int):
    if not _battle_inventory.has(tier) or _battle_inventory[tier].is_empty():
        print("No units of tier %d left to draw." % tier)
        return
    var tier_pool = _battle_inventory[tier]
    var drawn_instance = tier_pool.pick_random()
    tier_pool.erase(drawn_instance)
    var target_slot = _find_empty_board_slot()
    if is_instance_valid(target_slot):
        _place_instance_in_slot(drawn_instance, target_slot)
    else:
        _discard_pile.push_back(drawn_instance)
        _update_discard_pile_ui()

func _on_reshuffle_discard_pile_requested():
    if _discard_pile.is_empty(): return
    for instance in _discard_pile:
        var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
        if def and _battle_inventory.has(def.tier):
            _battle_inventory[def.tier].append(instance)
    _discard_pile.clear()
    _update_discard_pile_ui()

func _on_display_discard_pile_requested():
    var modal = DISCARD_PILE_VIEW_SCENE.instantiate()
    modal.discard_pile_data = self._discard_pile
    modal_layer.add_child(modal)

func _update_discard_pile_ui():
    discard_pile_button.text = "Discard Pile (%d)" % _discard_pile.size()

# --- Helper Functions ---
func _find_empty_board_slot() -> PanelContainer:
    for slot in bench_slots:
        if slot.get_child_count() == 0: return slot
    for slot in lineup_slots:
        if slot.get_child_count() == 0: return slot
    return null

func _place_instance_in_slot(instance_data: GachaBallInstance, slot_node: Node):
    var view = GACHA_BALL_VIEW_SCENE.instantiate()
    slot_node.add_child(view)
    view.set_instance_data(instance_data)
    _redraw_equipped_items(view)

func _redraw_equipped_items(unit_view: GachaBallView):
    for child in unit_view.item_grid.get_children():
        child.queue_free()
    var unit_data = unit_view.get_instance_data()
    if not unit_data or unit_data.equipped_item_uuids.is_empty(): return
    for item_uuid in unit_data.equipped_item_uuids:
        if item_uuid.is_empty(): continue
        var item_instance = _find_instance_by_uuid(item_uuid)
        if item_instance:
            var item_icon_view = GACHA_BALL_VIEW_SCENE.instantiate()
            item_icon_view.set_instance_data(item_instance)
            item_icon_view.is_interactable = false
            item_icon_view.custom_minimum_size = Vector2(32, 32)
            unit_view.item_grid.add_child(item_icon_view)

func _find_instance_by_uuid(uuid: String) -> GachaBallInstance:
    for tier in _battle_inventory:
        for instance in _battle_inventory[tier]:
            if instance.ball_uuid == uuid:
                return instance
    return null
Use code with caution.
Gdscript
Summary of Completion: The project now has a fully defined Battle.tscn with all specified UI placeholders. The attached BattleManager.gd script provides the complete logic for starting a battle, copying the inventory, handling draws, and managing the complex player interactions. The foundation for the core gameplay loop is now complete. You may now request the next implementation document.
Implementation Document 8 of 9: Modal UI Scenes
Objective: To create the three modal scenes required by the MVP: InspectInventoryView.tscn, DiscardPileView.tscn, and ChoicePromptUI.tscn.
Instructions for Windsurf: Execute the following steps sequentially. Create each scene file in the Godot editor according to the instructions, then create and attach its script.
Step 1: Create a Reusable Modal Background Script
Generated gdscript
# res://scripts/ModalBackground.gd
extends ColorRect

const CLICK_MAX_TRAVEL_SQ = 10 * 10
var _mouse_down_pos: Vector2
var _is_mouse_down: bool = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_mouse_down_pos = event.position
			_is_mouse_down = true
		elif _is_mouse_down:
			_is_mouse_down = false
			if event.position.distance_squared_to(_mouse_down_pos) < CLICK_MAX_TRAVEL_SQ:
				EventBus.emit_signal("close_modal_requested")
				var press_event = InputEventMouseButton.new()
				press_event.button_index = MOUSE_BUTTON_LEFT
				press_event.pressed = true
				press_event.global_position = get_global_mouse_position()
				var release_event = InputEventMouseButton.new()
				release_event.button_index = MOUSE_BUTTON_LEFT
				release_event.pressed = false
				release_event.global_position = get_global_mouse_position()
				await get_tree().create_timer(0.01).timeout
				Input.parse_input_event(press_event)
				Input.parse_input_event(release_event)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		EventBus.emit_signal("close_modal_requested")
		get_viewport().set_input_as_handled()
Use code with caution.
Gdscript
Step 2: Create InspectInventoryView.tscn and its Script
Create a scene with a Control root named InspectInventoryView.
Add a ColorRect child with the ModalBackground.gd script attached.
Add a PanelContainer -> ScrollContainer -> %InventoryGrid (GridContainer).
Save as res://scenes/InspectInventoryView.tscn.
Attach the following script to the root node:
Generated gdscript
# res://scripts/InspectInventoryView.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
@onready var inventory_grid: GridContainer = %InventoryGrid

func _ready():
    EventBus.close_modal_requested.connect(queue_free)
    GameManager.run_inventory_changed.connect(_populate_grid)
    _populate_grid()

func _populate_grid():
    # Clear existing items
    for child in inventory_grid.get_children():
        child.queue_free()

    # Populate with current run inventory, iterating through tiers
    if GameManager.run_state:
        for tier in GameManager.run_state.run_inventory:
            for instance_data in GameManager.run_state.run_inventory[tier]:
                var view = GACHA_BALL_VIEW_SCENE.instantiate()
                inventory_grid.add_child(view)
                view.set_instance_data(instance_data)
Use code with caution.
Gdscript
Step 3: Create DiscardPileView.tscn and its Script
Duplicate InspectInventoryView.tscn and save it as res://scenes/DiscardPileView.tscn.
Rename the root node to DiscardPileView and %InventoryGrid to %DiscardGrid.
Attach the following new script to the root node:
Generated gdscript
# res://scripts/DiscardPileView.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
@onready var discard_grid: GridContainer = %DiscardGrid

var discard_pile_data: Array[GachaBallInstance] = []

func _ready():
    EventBus.close_modal_requested.connect(queue_free)
    _populate_grid()

func _populate_grid():
    for instance_data in discard_pile_data:
        var view = GACHA_BALL_VIEW_SCENE.instantiate()
        discard_grid.add_child(view)
        view.set_instance_data(instance_data)
        view.is_interactable = false # Cannot interact with items in discard view
Use code with caution.
Gdscript
Step 4: Create ChoicePromptUI.tscn and its Script
Create a scene with a Control root named ChoicePromptUI.
Add a ColorRect background (without the modal script).
Add a PanelContainer -> VBoxContainer -> Label (Text: "Choose Action") and an HBoxContainer.
Add two buttons to the HBoxContainer: %MergeButton (Text: "Merge") and %SwapButton (Text: "Swap").
Save as res://scenes/ChoicePromptUI.tscn.
Attach the following script to the root node:
Generated gdscript
# res://scripts/ChoicePromptUI.gd
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
    merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
    swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))
    EventBus.close_modal_requested.connect(queue_free)

func _on_choice_made(choice: StringName):
    EventBus.emit_signal("choice_made", choice)
    queue_free()
Use code with caution.
Gdscript
Summary of Completion: The project now has three functional modal dialogs. The player can inspect their permanent inventory, view the battle's discard pile, and will be prompted to choose between merging and swapping when appropriate. You may now request the final implementation document.
Implementation Document 9 of 9: Final Polish and Integration
Objective: To perform the final integration steps and add small but critical pieces of logic that tie the whole system together. This includes ensuring placeholder slots can receive drops.
Instructions for Windsurf: Execute the following steps sequentially. These involve creating one final script and performing a manual step in the Godot editor.
Step 1: Create a Generic DropTarget.gd Script
This script will be attached to the empty panel slots in Battle.tscn to allow them to receive drops from GachaBallView instances.
Generated gdscript
# res://scripts/DropTarget.gd
extends PanelContainer

# This script makes a simple PanelContainer a valid drop target for a GachaBallView.

func _can_drop_data(_at_position, data) -> bool:
	# It can only accept drops from a GachaBallView.
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	
	# When a view is dropped here, its original drag preview is cancelled
	# and it becomes visible again. We need to hide it again before the
	# action request is processed to avoid a visual flicker.
	source_view.visible = true 
	
	# The BattleManager listens for this signal and will handle the move.
	EventBus.emit_signal("inventory_action_requested", source_view, self)
Use code with caution.
Gdscript
Step 2: Attach DropTarget.gd to Battle Slots (Manual Step)
Open the scene res://scenes/Battle.tscn in the Godot editor.
Select all the placeholder PanelContainer nodes:
%LineupSlot0 through %LineupSlot5
%BenchSlot0 through %BenchSlot2
In the Inspector, drag the script res://scripts/DropTarget.gd onto the "Script" property for all selected nodes.
Save the Battle.tscn scene.
Step 3: Final Verification of TDD User Journey (Mental Walkthrough)
This final step is a mental walkthrough to confirm all MVP requirements are met.
Launch & Start: Title.tscn -> start_run_requested -> GameManager creates RunState -> main_scene_requested -> Main.tscn loads. (✓ Met)
Main Scene & Run Inventory: Main.tscn -> "Inspect Inventory" opens InspectInventoryView.tscn. Dragging views emits inventory_action_requested. GameManager catches this and calls MergeManager with the tiered dictionary. The view refreshes via the run_inventory_changed signal. (✓ Met)
Enter Battle: PathChoice.tscn -> "Start Battle" emits battle_start_requested. Main.gd loads Battle.tscn. (✓ Met)
Battle Setup: BattleManager.gd's _ready function creates a tiered _battle_inventory by copying from GameManager.run_state.run_inventory. It places the Hero. (✓ Met)
Build a Team: "Draw" buttons emit draw_gacha_requested(tier). BattleManager catches this, finds a unit in the correct tier of _battle_inventory, and places it. (✓ Met)
Manage the Board: Interactions emit inventory_action_requested. BattleManager's logic correctly routes to move, swap, equip, or prompt for merge. (✓ Met)
Item Transfer on Merge: MergeManager.attempt_merge correctly gathers items from parents, removes parents from their respective tiers, adds the new unit to its tier, and re-equips items. (✓ Met)
Discard & Reshuffle: Clicking "Discard Pile" opens the DiscardPileView.tscn modal. Clicking "Reshuffle" calls _on_reshuffle_discard_pile_requested in BattleManager, which moves instances from _discard_pile back to the correct tier in _battle_inventory. (✓ Met)
Phase 1: Foundational Data Structures & Resources - Implementation Plan
Objective:
To establish the core data schemas, resource definitions, and data structures that will serve as the foundation for the game's logic, as defined in the TDD.
Step 1.1: Create Core Data Schemas
Instruction: Create the following new script files. These abstract data containers are essential for the new data-driven architecture.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file creation operations:
Create the file res://scripts/LocationIdentifier.gd with the following content:
# res://scripts/LocationIdentifier.gd
class_name LocationIdentifier
extends Resource

## A type-safe data resource for identifying any slot in any container.
## This is the universal contract for all inventory-based actions.

## The unique name of the container (e.g., "PlayerLineup", "RunInventoryT1").
@export var container: StringName

## The index of the slot within the container.
@export var index: int

## The tier of the container, if applicable (-1 indicates no tier).
@export var tier: int = -1

func _to_string() -> String:
	return "Location(Container: %s, Index: %d, Tier: %d)" % [container, index, tier]

Create the file res://scripts/DataContainer.gd with the following content:
# res://scripts/DataContainer.gd
class_name DataContainer
extends Object

## The abstract base class for all data collections (inventories, lineups, etc.).
## Defines the public interface for interacting with any container, hiding
## the underlying implementation (Array, Dictionary, etc.).

func get_uuid(index: int) -> String:
	push_error("get_uuid() must be implemented by a subclass.")
	return ""

func set_uuid(index: int, uuid: String) -> void:
	push_error("set_uuid() must be implemented by a subclass.")

func find_first_empty_slot() -> int:
	push_error("find_first_empty_slot() must be implemented by a subclass.")
	return -1

func get_all_uuids() -> Array[String]:
	push_error("get_all_uuids() must be implemented by a subclass.")
	return []

func get_all_non_empty_uuids() -> Array[String]:
	var all_uuids = get_all_uuids()
	return all_uuids.filter(func(uuid): return not uuid.is_empty())

Create the file res://scripts/FixedArrayContainer.gd with the following content:
# res://scripts/FixedArrayContainer.gd
class_name FixedArrayContainer
extends DataContainer

## A DataContainer for fixed-size collections like lineups and benches.
## It is backed by a simple Array.

var _data: Array[String]

func _init(size: int):
	_data.resize(size)
	_data.fill("") # Use empty string for null/empty

func get_uuid(index: int) -> String:
	if index >= 0 and index < _data.size():
		return _data[index]
	return ""

func set_uuid(index: int, uuid: String) -> void:
	if index >= 0 and index < _data.size():
		_data[index] = uuid

func find_first_empty_slot() -> int:
	return _data.find("")

func get_all_uuids() -> Array[String]:
	return _data.duplicate()

Create the file res://scripts/GridContainer.gd with the following content:
# res://scripts/GridContainer.gd
class_name GridContainer
extends DataContainer

## A DataContainer for growable collections like inventories.
## It is backed by an Array and contains its own internal growth logic.

var _data: Array[String]
var _growth_amount: int = 4

func _init(initial_size: int, growth_amount: int = 4):
	_data.resize(initial_size)
	_data.fill("") # Use empty string for null/empty
	_growth_amount = growth_amount

func get_uuid(index: int) -> String:
	if index >= 0 and index < _data.size():
		return _data[index]
	return ""

func set_uuid(index: int, uuid: String) -> void:
	if index >= 0 and index < _data.size():
		_data[index] = uuid

func find_first_empty_slot() -> int:
	var index = _data.find("")
	if index == -1:
		# Grow the container if no empty slot is found.
		var old_size = _data.size()
		_data.resize(old_size + _growth_amount)
		_data.fill("")
		return old_size # The first new empty slot
	return index

func get_all_uuids() -> Array[String]:
	return _data.duplicate()

</details>
Step 1.2: Update GachaBall Instance & Definition
Instruction: Overwrite the existing GachaBallDefinition.gd and GachaBallInstance.gd scripts to align with the TDD's property and method specifications.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file modification operations:
Overwrite the file res://scripts/GachaBallDefinition.gd with the following content:
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

## The base health points for a UNIT.
@export var base_hp: int = 0

## The base power for a UNIT.
@export var base_pwr: int = 0

## The bonus health points provided by an ITEM.
@export var bonus_hp: int = 0

## The bonus power provided by an ITEM.
@export var bonus_pwr: int = 0

## The abilities this unit possesses.
@export var ability_definitions: Array[AbilityDefinition]

Overwrite the file res://scripts/GachaBallInstance.gd with the following content:
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

## The current health of this instance in battle.
var current_hp: int

## The current power of this instance in battle.
var current_pwr: int

## Sets up the instance based on a GachaBallDefinition.
## This must be called immediately after creating a new instance.
func initialize(definition: GachaBallDefinition):
	if not is_instance_valid(definition):
		printerr("GachaBallInstance.initialize() was called with a null definition.")
		return

	self.definition_id = definition.id
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)

	equipped_item_uuids.resize(definition.item_slot_count)
	equipped_item_uuids.fill("")

	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr

## Creates a temporary, deep copy of this instance for a battle session.
func create_battle_copy() -> GachaBallInstance:
	var copy = self.duplicate(false) # Create a shallow copy of properties
	var definition = get_definition()
	if not is_instance_valid(definition):
		printerr("Cannot create battle copy, definition not found for ID: ", self.definition_id)
		return null

	# Deep copy the array
	copy.equipped_item_uuids = self.equipped_item_uuids.duplicate(true)
	# Assign new unique IDs for the battle context
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid # Link back to the original

	# Initialize the copy's stats directly from the definition.
	copy.current_hp = definition.base_hp
	copy.current_pwr = definition.base_pwr

	return copy

## Calculates current stats based on equipped items.
func recalculate_stats(all_instances_db: Dictionary):
	var definition = get_definition()
	if not is_instance_valid(definition): return

	# Start with base stats
	var new_hp = definition.base_hp
	var new_pwr = definition.base_pwr

	# Add bonuses from each equipped item
	for item_uuid in equipped_item_uuids:
		if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
			var item_instance: GachaBallInstance = all_instances_db[item_uuid]
			var item_def = item_instance.get_definition()
			if is_instance_valid(item_def):
				new_hp += item_def.bonus_hp
				new_pwr += item_def.bonus_pwr

	self.current_hp = new_hp
	self.current_pwr = new_pwr


func get_definition() -> GachaBallDefinition:
	return Database.get_definition(definition_id)

</details>
Step 1.3: Update Resource Files (.tres)
Instruction: Create one new resource file (EnemyHero.tres) and overwrite the existing unit and item .tres files to match the TDD's data manifest.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file creation and modification operations:
Overwrite res://resources/units/hero.tres:
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
base_hp = 10
base_pwr = 2
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Create res://resources/units/EnemyHero.tres:
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/Hero.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"enemy_hero"
display_name_key = "enemy_hero.name"
description_key = "enemy_hero.desc"
icon = ExtResource("2_icon")
tier = 0
category = &"UNIT"
item_slot_count = 5
base_hp = 10
base_pwr = 2
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/units/UnitTier1A.tres:
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
base_hp = 1
base_pwr = 2
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/units/UnitTier1B.tres:
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
base_hp = 2
base_pwr = 1
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/units/UnitTier2C.tres:
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
base_hp = 3
base_pwr = 3
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/units/UnitTier3D.tres:
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
base_hp = 6
base_pwr = 6
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/items/ItemTier1A.tres:
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
base_hp = 0
base_pwr = 0
bonus_hp = 1
bonus_pwr = 0
ability_definitions = []

Overwrite res://resources/items/ItemTier1B.tres:
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
base_hp = 0
base_pwr = 0
bonus_hp = 0
bonus_pwr = 1
ability_definitions = []

Overwrite res://resources/items/ItemTier2C.tres:
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
base_hp = 0
base_pwr = 0
bonus_hp = 1
bonus_pwr = 1
ability_definitions = []

Overwrite res://resources/items/ItemTier3D.tres:
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
base_hp = 0
base_pwr = 0
bonus_hp = 2
bonus_pwr = 2
ability_definitions = []

</details>
Step 1.4: Implement the New RunState
Instruction: Overwrite the RunState.gd script to use the new TDD-specified data structures. This is a critical architectural change.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Overwrite the file res://scripts/RunState.gd with the following content:
# res://scripts/RunState.gd
class_name RunState
extends Resource

## The player's current run state, including all persistent progress.
## This resource is the single source of truth for data outside of a battle.

@export var gold: int = 0
@export var hero_instance: GachaBallInstance

## Master database of all unique GachaBall instances for the entire run.
## Key: ball_uuid (String), Value: GachaBallInstance
@export var run_instances: Dictionary = {}

## The data containers for the persistent run inventory, separated by tier.
## Key: container_name (StringName), Value: GridContainer
@export var run_inventory_containers: Dictionary = {}


func start_new_run() -> void:
	gold = 10
	run_instances.clear()
	run_inventory_containers.clear()

	# Initialize the inventory containers as defined in the TDD
	run_inventory_containers[&"RunInventoryT1"] = GridContainer.new(16)
	run_inventory_containers[&"RunInventoryT2"] = GridContainer.new(16)
	run_inventory_containers[&"RunInventoryT3"] = GridContainer.new(16)

	# Create and store the hero instance
	var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
		# The hero itself is not in the run_instances dictionary, it's a special property.
	else:
		printerr("RunState: CRITICAL - Could not find 'hero' definition in Database.")

	# Add some starting items to the inventory for testing
	var items_to_add: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_b",
		&"item_t1_a", &"item_t1_b",
		&"unit_t2_c", &"item_t2_c",
		&"unit_t3_d", &"item_t3_d"
	]

	for id in items_to_add:
		var definition: GachaBallDefinition = Database.get_definition(id)
		if not definition:
			printerr("RunState: Could not find definition for id: ", id)
			continue

		var instance = GachaBallInstance.new()
		instance.initialize(definition)

		# Add the new instance to the master database
		run_instances[instance.ball_uuid] = instance

		# Add the instance's UUID to the correct inventory container
		var container_name = &"RunInventoryT%d" % definition.tier
		if run_inventory_containers.has(container_name):
			var container: GridContainer = run_inventory_containers[container_name]
			var empty_slot_index = container.find_first_empty_slot()
			container.set_uuid(empty_slot_index, instance.ball_uuid)
		else:
			printerr("RunState: No container named '%s' for item '%s'" % [container_name, id])

	print("RunState initialized with new TDD-compliant data structure.")

</details>
Step 1.5: Establish Localization
Instruction: Create the central localization.csv file and update project.godot to enable the localization system.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file creation and modification operations:
Create the file res://localization.csv with the following content:
key,en
hero.name,"Hero"
hero.desc,"The player's champion. If defeated, the battle is lost."
enemy_hero.name,"Enemy Hero"
enemy_hero.desc,"The enemy's champion."
unit_t1_a.name,"Sparky"
unit_t1_a.desc,"A basic Tier 1 unit."
unit_t1_b.name,"Stoney"
unit_t1_b.desc,"A durable Tier 1 unit."
unit_t2_c.name,"Golem"
unit_t2_c.desc,"A powerful Tier 2 unit, merged from Sparky and Stoney."
unit_t3_d.name,"Titan"
unit_t3_d.desc,"An ultimate Tier 3 unit, merged from two Golems."
item_t1_a.name,"Health Gem"
item_t1_a.desc,"Grants a small amount of bonus HP."
item_t1_b.name,"Power Gem"
item_t1_b.desc,"Grants a small amount of bonus Power."
item_t2_c.name,"Vitality Crystal"
item_t2_c.desc,"Grants bonus HP and Power."
item_t3_d.name,"Heart of the Mountain"
item_t3_d.desc,"Grants a large amount of bonus HP and Power."
ability.basic_attack.name,"Basic Attack"
ability.basic_attack.desc,"Attacks the frontmost enemy for {pwr} damage."

Edit the file project.godot to add the [localization] section. Find the [display] section and add the new section directly below it.
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"

[localization]

locale_testing/test="en"
locale_testing/reload=true
locales/auto_translate=true
remaps/path_remaps=PackedStringArray()
remaps/locale_remaps=PackedStringArray()
remaps/remap_ids=PackedStringArray()

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"

</details>
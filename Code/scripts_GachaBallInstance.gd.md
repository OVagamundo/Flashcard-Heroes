<!-- Original: scripts/GachaBallInstance.gd -->

```gdscript
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
	copy.definition_id = self.definition_id # Explicitly copy the definition ID
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

## Returns the UUID of an equipped item at a specific index.
func get_equipped_item_uuid_at_index(index: int) -> String:
	if index >= 0 and index < equipped_item_uuids.size():
		return equipped_item_uuids[index]
	return ""
```
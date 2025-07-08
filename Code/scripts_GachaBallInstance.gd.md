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


## TDD: Sets up the instance based on a GachaBallDefinition.
## This must be called immediately after creating a new instance.
func initialize(definition: GachaBallDefinition):
	if not definition:
		printerr("GachaBallInstance.initialize() was called with a null definition.")
		return

	self.definition_id = definition.id
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
	
	equipped_item_uuids.resize(definition.item_slot_count)
	equipped_item_uuids.fill("")
	
	# TDD Update: Initialize combat stats from the definition's base values.
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr


## TDD: Creates a temporary, deep copy of this instance for a battle session.
func create_battle_copy() -> GachaBallInstance:
	var copy = GachaBallInstance.new()
	var definition = get_definition()
	if not definition:
		printerr("Cannot create battle copy, definition not found for ID: ", self.definition_id)
		return null
	
	copy.definition_id = self.definition_id
	copy.equipped_item_uuids = self.equipped_item_uuids.duplicate(true)
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid
	
	# TDD Update: Initialize the copy's stats from the definition.
	copy.current_hp = definition.base_hp
	copy.current_pwr = definition.base_pwr
	
	return copy

## TDD Update: Calculates current stats based on equipped items.
func recalculate_stats(inventory_context: Dictionary):
	var definition = get_definition()
	if not definition: return

	# Start with base stats
	current_hp = definition.base_hp
	current_pwr = definition.base_pwr

	# Reuse existing helper to find equipped item instances
	var equipped_items: Array[GachaBallInstance] = MergeManager._get_equipped_item_instances(self, inventory_context)

	# Add bonuses from each equipped item
	for item_instance in equipped_items:
		var item_def = item_instance.get_definition()
		if item_def:
			current_hp += item_def.bonus_hp
			current_pwr += item_def.bonus_pwr
	
	# Notify the UI that stats have changed.
	EventBus.emit_signal("unit_stats_changed", self.ball_uuid)


func get_definition() -> GachaBallDefinition:
	return Database.get_definition(definition_id)
```
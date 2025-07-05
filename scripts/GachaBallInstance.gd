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


## TDD: Sets up the instance based on a GachaBallDefinition.
## This must be called immediately after creating a new instance.
func initialize(definition: GachaBallDefinition):
	if not definition:
		printerr("GachaBallInstance.initialize() was called with a null definition.")
		return

	self.definition_id = definition.id
	# The UUIDUtils autoload is required for this to work.
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
	
	# TDD: Resize the item array to match the definition and fill with empty strings ("").
	equipped_item_uuids.resize(definition.item_slot_count)
	equipped_item_uuids.fill("")


## TDD: Creates a temporary, deep copy of this instance for a battle session.
func create_battle_copy() -> GachaBallInstance:
	# A true deep copy is required to prevent battle modifications from
	# affecting the permanent run inventory instance.
	var copy = GachaBallInstance.new()
	
	# Manually copy all necessary data.
	copy.definition_id = self.definition_id
	copy.equipped_item_uuids = self.equipped_item_uuids.duplicate(true) # Deep copy array
	
	# Generate a new, unique UUID for the battle copy.
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	
	# Link the copy back to its permanent origin.
	copy.origin_uuid = self.ball_uuid
	
	return copy

func get_definition() -> GachaBallDefinition:
	return Database.units.get(definition_id, Database.items.get(definition_id))
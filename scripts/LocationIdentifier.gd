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

## (Optional) When referring to an equipped-item slot, this stores the parent unit's UUID.
@export var unit_uuid: String = ""

func _to_string() -> String:
	return "Location(Container: %s, Index: %d, Tier: %d)" % [container, index, tier]

func is_equal(other: LocationIdentifier) -> bool:
	if not is_instance_valid(other):
		return false
	return container == other.container and index == other.index and tier == other.tier

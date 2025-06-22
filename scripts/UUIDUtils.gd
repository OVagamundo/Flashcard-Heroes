# res://scripts/UUIDUtils.gd
extends Node

## A global utility for generating unique, descriptive, and debug-friendly
## string identifiers for all GachaBallInstances.

func _ready() -> void:
	# Initialize the random number generator to ensure variety in UUIDs.
	randomize()

# Generates a UUID, e.g., "unit_t1_a_1677628800_1234"
func generate_uuid(prefix: StringName) -> String:
	var timestamp: int = int(Time.get_unix_time_from_system())
	var random_suffix: int = randi() % 10000
	return "%s_%d_%04d" % [prefix, timestamp, random_suffix]

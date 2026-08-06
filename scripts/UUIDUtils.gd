extends Node

## A global utility for generating unique, descriptive, and debug-friendly
## string identifiers for all GachaBallInstances.

static var _counter: int = 0

# Generates a UUID, e.g., "unit_t1_a_1677628800_1_1234"
static func generate_uuid(prefix: StringName) -> String:
	_counter += 1
	var timestamp: int = int(Time.get_unix_time_from_system())
	var random_suffix: int = RNGManager.gacha_rng.randi() % 100000
	return "%s_%d_%d_%05d" % [prefix, timestamp, _counter, random_suffix]

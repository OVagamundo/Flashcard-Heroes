# res://scripts/systems/SeededRNG.gd
class_name SeededRNG
extends RefCounted

## A deterministic PRNG wrapper around Godot's RandomNumberGenerator.
## Provides the same API as native randi/randf/pick_random/shuffle
## but backed by a seeded, serializable state machine.

var _rng := RandomNumberGenerator.new()
var _name: StringName

func _init(stream_name: StringName, seed_value: int) -> void:
	_name = stream_name
	_rng.seed = seed_value

# =============================================================================
# CORE RANDOM GENERATION
# =============================================================================

func randi() -> int:
	return _rng.randi()

func randf() -> float:
	return _rng.randf()

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

# =============================================================================
# ARRAY HELPERS (replace Array.pick_random() and Array.shuffle())
# =============================================================================

## Pick a random element from an array. Asserts the array is non-empty.
func pick_random(array: Array) -> Variant:
	assert(not array.is_empty(), "SeededRNG.pick_random(): array must not be empty (stream: %s)" % _name)
	return array[_rng.randi() % array.size()]

## In-place Fisher-Yates shuffle using the seeded RNG.
func shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j = _rng.randi() % (i + 1)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp

# =============================================================================
# SERIALIZATION
# =============================================================================

func serialize() -> Dictionary:
	return {
		"name": String(_name),
		"seed": _rng.seed,
		"state": _rng.state,
	}

func deserialize(data: Dictionary) -> void:
	_rng.seed = data.get("seed", 0)
	_rng.state = data.get("state", 0)

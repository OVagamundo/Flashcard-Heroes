# res://scripts/systems/RNGManager.gd
extends Node

## Central manager for all deterministic PRNG streams.
## Each stream is isolated so that rolls in one subsystem
## never affect the sequence of another.

var _master_seed: int = 0

## Gameplay-critical streams
var map_rng: SeededRNG        ## Path gen, encounters, node selection, flashcards, deck ordering
var combat_rng: SeededRNG     ## Targeting, damage, status effects, bouncing, summons
var shop_rng: SeededRNG       ## Shop inventories, re-rolls
var reward_rng: SeededRNG     ## Post-combat loot, prize rolls, training outcomes
var gacha_rng: SeededRNG      ## Drawing from gachaball pools, UUID generation

## Non-gameplay stream (visual flair that must still replay identically)
var cosmetic_rng: SeededRNG   ## Audio pitch, screen shake, coin scatter, physics spread

func _ready() -> void:
	# Initialize immediately so streams are available before a run starts (e.g. for UI sounds)
	# When a run actually starts, GameManager will call initialize() again to reset them.
	initialize(-1)

## Initialize all streams from a master seed.
## Pass -1 to generate a random master seed (normal gameplay).
## Pass a specific seed for replays or deterministic testing.
func initialize(master_seed: int = -1) -> void:
	if master_seed == -1:
		# Use Godot's system-level randomness ONLY here, once, to pick the master seed.
		randomize()
		_master_seed = randi()
	else:
		_master_seed = master_seed

	map_rng      = SeededRNG.new(&"map",      _derive_seed("map"))
	combat_rng   = SeededRNG.new(&"combat",   _derive_seed("combat"))
	shop_rng     = SeededRNG.new(&"shop",     _derive_seed("shop"))
	reward_rng   = SeededRNG.new(&"reward",   _derive_seed("reward"))
	gacha_rng    = SeededRNG.new(&"gacha",    _derive_seed("gacha"))
	cosmetic_rng = SeededRNG.new(&"cosmetic", _derive_seed("cosmetic"))

	print("[RNGManager] Initialized with master seed: %d" % _master_seed)

## Get the master seed (for saving/display).
func get_master_seed() -> int:
	return _master_seed

## Deterministically derive a per-stream seed from the master seed.
func _derive_seed(stream_key: String) -> int:
	return hash(str(_master_seed) + "_" + stream_key)

# =============================================================================
# SERIALIZATION (for run saves and replay checkpoints)
# =============================================================================

func serialize() -> Dictionary:
	return {
		"master_seed": _master_seed,
		"streams": {
			"map":      map_rng.serialize(),
			"combat":   combat_rng.serialize(),
			"shop":     shop_rng.serialize(),
			"reward":   reward_rng.serialize(),
			"gacha":    gacha_rng.serialize(),
			"cosmetic": cosmetic_rng.serialize(),
		}
	}

func deserialize(data: Dictionary) -> void:
	_master_seed = data.get("master_seed", 0)

	# Re-create streams with derived seeds first, then restore their advanced state
	var streams: Dictionary = data.get("streams", {})

	map_rng      = SeededRNG.new(&"map",      _derive_seed("map"))
	combat_rng   = SeededRNG.new(&"combat",   _derive_seed("combat"))
	shop_rng     = SeededRNG.new(&"shop",     _derive_seed("shop"))
	reward_rng   = SeededRNG.new(&"reward",   _derive_seed("reward"))
	gacha_rng    = SeededRNG.new(&"gacha",    _derive_seed("gacha"))
	cosmetic_rng = SeededRNG.new(&"cosmetic", _derive_seed("cosmetic"))

	if streams.has("map"):      map_rng.deserialize(streams["map"])
	if streams.has("combat"):   combat_rng.deserialize(streams["combat"])
	if streams.has("shop"):     shop_rng.deserialize(streams["shop"])
	if streams.has("reward"):   reward_rng.deserialize(streams["reward"])
	if streams.has("gacha"):    gacha_rng.deserialize(streams["gacha"])
	if streams.has("cosmetic"): cosmetic_rng.deserialize(streams["cosmetic"])

	print("[RNGManager] Deserialized with master seed: %d" % _master_seed)

extends Node

var failures: int = 0
var encounters_checked: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_trinket_ties() -> void:
	# Neither unit activates a trait Crest. These three secondary trinkets tie.
	var board: Dictionary[int, StringName] = {0: &"ETnkPla", 1: &"WSupAni"}
	var candidates: Array[String] = ["trinket_purifying_pendant", "trinket_spiked_armor", "trinket_vengeance"]
	for seed_value: int in range(32):
		var expected_rng := SeededRNG.new(&"trinket_tie", seed_value)
		var actual_rng := SeededRNG.new(&"trinket_tie", seed_value)
		var expected: String = candidates[expected_rng.randi_range(0, candidates.size() - 1)]
		var actual: StringName = EncounterSynergyRegistry.select_best_voted_trinket(board, [], actual_rng)
		_check(String(actual) == expected, "Trinket tie must map the seeded index to alphabetical IDs (seed %d): expected %s, got %s" % [seed_value, expected, actual])
		_check(actual_rng.serialize() == expected_rng.serialize(), "Trinket tie consumed an unexpected number of RNG rolls")

func _test_filler_order() -> void:
	for trait_name: StringName in EnemyTraitBannerProfiles.TRAITS:
		var profile: EnemyTraitBannerProfile = EnemyTraitBannerProfiles.create(trait_name)
		var actual: Array[String] = []
		for unit_id: StringName in profile.filler_ids():
			actual.append(String(unit_id))
		var expected: Array[String] = actual.duplicate()
		expected.sort()
		_check(actual == expected, "%s banner filler IDs must be alphabetically ordered across processes" % trait_name)

func _snapshot(encounter: EncounterDefinition) -> Dictionary:
	return {
		"banner": String(encounter.banner_trinket_id),
		"entity": String(encounter.boss_or_elite_unit_id),
		"placements": encounter.enemy_placements.duplicate(true),
		"trinkets": encounter.enemy_trinket_ids.duplicate(),
		"player_slots": encounter.player_slot_effects.duplicate(),
		"enemy_slots": encounter.enemy_slot_effects.duplicate(),
		"rng": RNGManager.serialize(),
	}

func _restore(saved: Dictionary) -> void:
	# Use the same binary serialization as SaveManager, without touching the live save.
	var restored := RunState.new()
	restored.from_save_dict(bytes_to_var(var_to_bytes(saved)))
	GameManager.run_state = restored

func _test_restore() -> void:
	var snapshots: Array[Dictionary] = []
	for seed_value: int in [42, 3592919753]:
		RNGManager.initialize(seed_value)
		var run := RunState.new()
		GameManager.run_state = run
		run.initialize_run(&"hero_bounty_hunter", &"katakana_main")
		run.run_seed = seed_value
		run.day = 30
		run.record_regular_banner(&"trinket_banner_swarm")
		run.record_elite_encounter(&"elite_burnie")
		run.record_boss_encounter(&"boss_dustmon")
		var path := PathNodeDefinition.new()
		path.node_type = &"BATTLE"
		run.available_path_nodes = [path]
		var saved: Dictionary = run.to_save_dict()
		for budget: int in [8, 16, 32]:
			var banners: Array[StringName] = BannerDraftingRegistry.regular_banner_ids(budget)
			banners.append_array([&"trinket_banner_burnie", &"trinket_banner_slimeblob", &"trinket_banner_dustmon", &"trinket_banner_toughmon", &"trinket_banner_doppelkun"])
			for banner: StringName in banners:
				var expected: Dictionary = {}
				for attempt: int in range(3):
					_restore(saved)
					# Unseeded/cosmetic activity must not affect encounter generation.
					for noise: int in range(attempt * 7):
						randi()
						RNGManager.cosmetic_rng.randi()
					var encounter: EncounterDefinition = BannerDraftingRegistry.get_drafter(banner).draft_lineup(budget, {"daily_budget": budget})
					var actual: Dictionary = _snapshot(encounter)
					# Cosmetic state is deliberately allowed to differ.
					actual["rng"]["streams"].erase("cosmetic")
					if attempt == 0:
						expected = actual
						snapshots.append(actual)
					else:
						_check(actual == expected, "Restoring the same run changed %s at budget %d" % [banner, budget])
					encounters_checked += 1
			for mode: String in ["regular", "elite", "boss"]:
				var expected: Dictionary = {}
				for attempt: int in range(3):
					_restore(saved)
					var encounter: EncounterDefinition
					match mode:
						"regular": encounter = EncounterGenerator.generate_encounter(budget)
						"elite": encounter = EncounterGenerator.generate_elite_encounter(budget)
						"boss": encounter = EncounterGenerator.generate_boss_encounter(1, budget, run.day)
					var actual: Dictionary = _snapshot(encounter)
					if attempt == 0:
						expected = actual
						snapshots.append(actual)
					else:
						_check(actual == expected, "Continue changed the %s encounter at budget %d" % [mode, budget])
					encounters_checked += 1
	# An outer runner can compare this across fresh Godot processes.
	print("ENCOUNTER_RNG_FINGERPRINT=", JSON.stringify(snapshots).sha256_text())

func _run() -> void:
	_test_trinket_ties()
	_test_filler_order()
	_test_restore()
	print("ENCOUNTER RNG SUITE: %d encounters, %d failures" % [encounters_checked, failures])
	get_tree().quit(1 if failures > 0 else 0)

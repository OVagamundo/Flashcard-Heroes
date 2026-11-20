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

func _test_starting_loadout() -> void:
	for hero: GachaBallDefinition in Database.get_hero_definitions():
		for seed_value: int in [42, 3592919753]:
			var live_rng: Dictionary = RNGManager.serialize()
			var preview: RunState.StartingLoadout = RunState.preview_starting_loadout(hero.id, seed_value)
			_check(RNGManager.serialize() == live_rng, "Previewing %s must leave the live RNG untouched" % hero.id)
			for order: String in ["REGULAR", "RANDOM"]:
				RNGManager.initialize(seed_value)
				var run := RunState.new()
				GameManager.run_state = run
				run.run_seed = seed_value
				run.initialize_run(hero.id, &"katakana_main", order)
				var actual_starters: Array[StringName] = []
				for instance: GachaBallInstance in run.get_all_instances().values():
					if instance != run.hero_instance:
						actual_starters.append(instance.definition_id)
				var actual_traits: TagComponent = run.hero_instance.components[0] as TagComponent
				_check(actual_starters == preview.starter_ids, "%s preview must match starting inventory for %s deck order" % [hero.id, order])
				_check(actual_traits.tags_to_add == preview.hero_traits.tags_to_add, "%s preview must match starting Traits" % hero.id)
				_check(run.hero_element == preview.hero_element and run.dynamic_tag_overrides == preview.unit_tag_overrides, "%s preview must match starting Elemental Traits" % hero.id)

func _test_loadout_menu() -> void:
	var cached_seed: int = SaveManager._loadout_seed
	SaveManager._loadout_seed = 42
	var menu = preload("res://scenes/Loadout.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var expected: RunState.StartingLoadout = RunState.preview_starting_loadout(&"hero_starter", 42)
	var description: RichTextLabel = menu.get_node("%HeroDescription")
	var hero: GachaBallDefinition = Database.get_definition(&"hero_starter") as GachaBallDefinition
	_check(description.text == tr(hero.ability_definitions[0].description_key), "The hero panel describes only the hero's abilities")
	var portrait: TextureRect = menu.get_node("%HeroSprite")
	var traits: HFlowContainer = menu.get_node("%HeroTraitTags")
	var first_trait: Label = traits.get_child(0).get_child(0)
	var element: String = String(expected.hero_element).trim_prefix("SOUL_")
	var expected_trait: String = "3x %s" % tr(C.TRAIT_DEFINITIONS[element].display_name_key)
	_check(first_trait.text == expected_trait, "The tag under the portrait displays the rolled Elemental Trait")
	_check(traits.get_global_rect().position.y >= portrait.get_global_rect().end.y, "The Trait tags sit beneath the portrait")
	var starter_panels: Array[Node] = menu.get_node("%StartingSetContainer").find_children("*", "PanelContainer", true, false)
	var visible_ids: Array[StringName] = []
	for panel: Node in starter_panels:
		if not panel is SlotView:
			continue
		var slot: SlotView = panel as SlotView
		var view: GachaBallView = slot.get_node("GachaBallView")
		visible_ids.append(view.definition_id)
		var bounds: Rect2 = view.get_global_rect()
		var sprite: Rect2 = view.get_sprite_global_bounds()
		_check(is_equal_approx(bounds.get_center().x, sprite.get_center().x), "Starter art is centered in its cell for %s" % view.definition_id)
		var definition: Resource = Database.get_definition(view.definition_id)
		var inspection: Dictionary = WindowManager._derive_window_payload(slot._location, view)
		var inspect_instance: GachaBallInstance = inspection.get("context", {}).get("instance")
		_check(inspect_instance != null and inspect_instance.definition_id == view.definition_id, "The starter %s is inspectable" % view.definition_id)
		var badge: Label = slot.get_parent().get_node_or_null("Quantity")
		if badge != null:
			var badge_bounds: Rect2 = badge.get_global_rect()
			_check(badge_bounds.position.x > bounds.get_center().x, "The quantity sits at the lower right")
			_check(badge_bounds.end.x <= bounds.end.x and badge_bounds.end.y <= bounds.end.y, "The quantity stays inside its cell")
		if definition.category == &"UNIT":
			_check(sprite.size.is_equal_approx(Vector2.ONE * C.UNIT_SPRITE_SIZE), "Starter units match their deployed sprite size")
			var stats: HBoxContainer = view.get_node("%StatsContainer")
			var hp: HBoxContainer = view.get_node("%HPContainer")
			var pwr: HBoxContainer = view.get_node("%PWRContainer")
			var stat_icons: Rect2 = hp.get_global_rect().merge(pwr.get_global_rect())
			_check(absf(stat_icons.get_center().x - sprite.get_center().x) <= 1.0, "HP and PWR are centered below %s" % view.definition_id)
			if badge != null:
				_check(badge.get_global_rect().end.y < stats.get_global_rect().position.y, "The unit quantity sits above its HP and PWR")
		elif definition.category in [&"ITEM", &"CONSUMABLE"]:
			var capsule_item_size: float = roundf(32.0 * C.SHELF_CAPSULE_SCALE)
			_check(is_equal_approx(maxf(sprite.size.x, sprite.size.y), capsule_item_size), "Starter items match their Shelf capsule scale")
	for id: StringName in expected.bonus_starter_ids:
		_check(visible_ids.has(id), "The starter grid displays the rolled starter %s" % id)
	menu._select_hero_by_id(&"hero_bounty_hunter")
	menu._select_hero_by_id(&"hero_starter")
	first_trait = traits.get_child(0).get_child(0)
	_check(first_trait.text == expected_trait, "Switching heroes keeps the rolled Trait tags")
	menu.free()
	SaveManager._loadout_seed = cached_seed

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
	await _test_loadout_menu()
	_test_starting_loadout()
	_test_restore()
	print("ENCOUNTER RNG SUITE: %d encounters, %d failures" % [encounters_checked, failures])
	get_tree().quit(1 if failures > 0 else 0)

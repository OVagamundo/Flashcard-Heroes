extends Node

const C = preload("res://scripts/Constants.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")

var failures: int = 0
var drafts_checked: int = 0
var waves_checked: int = 0
var maximum_counts: Dictionary[StringName, int] = {}

func _ready() -> void:
	if SignalBus.main_scene_requested.is_connected(SceneManager._on_main_scene_requested):
		SignalBus.main_scene_requested.disconnect(SceneManager._on_main_scene_requested)
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _unit(data: Dictionary, summon: bool = false) -> EncounterDraftUnit:
	var unit := EncounterDraftUnit.new(data["unit_id"] if summon else data["id"], int(data["slot"] if summon else data["position"]))
	unit.level = int(data["level"])
	unit.items.assign(data["items"])
	unit.bonus_hp = int(data["bonus_hp"])
	unit.bonus_pwr = int(data["bonus_pwr"])
	return unit

func _validate(encounter: EncounterDefinition, profile: EnemyTraitBannerProfile, budget: int) -> Array[EncounterDraftUnit]:
	var units: Array[EncounterDraftUnit] = []
	var occupied: Array[int] = []
	var trait_count: int = 0
	var spent: int = 0
	var overflow_hp: int = 0
	var overflow_pwr: int = 0
	for data: Dictionary in encounter.enemy_placements:
		var unit: EncounterDraftUnit = _unit(data)
		_check(not occupied.has(unit.slot), "Overlapping banner slots")
		occupied.append(unit.slot)
		_check(unit.items.size() <= 1, "Banner exceeded one item slot")
		_check(EncounterSynergyRegistry.is_unit_enemy_draftable(unit.unit_id), "Player-only unit drafted")
		_check(unit.trait_count(profile.trait_name) > 0, "Drafted partner lacks banner emblem")
		if not profile.native_unit(unit.unit_id):
			_check(unit.items == [profile.emblem()], "Off-trait partner has incorrect equipment")
		trait_count += unit.trait_count(profile.trait_name)
		spent += unit.gold_cost()
		overflow_hp += unit.bonus_hp
		overflow_pwr += unit.bonus_pwr
		units.append(unit)
	_check(trait_count >= profile.threshold(), "%s missed its initial trait threshold" % profile.trait_name)
	maximum_counts[profile.trait_name] = maxi(maximum_counts.get(profile.trait_name, 0), trait_count)
	_check(encounter.enemy_trinket_ids.has(profile.crest()), "Missing free primary Crest")
	for id: StringName in encounter.enemy_trinket_ids:
		var trinket: TrinketDefinition = Database.get_definition(id) as TrinketDefinition
		_check(not trinket.is_player_exclusive, "Player-exclusive trinket drafted")
		if id != profile.crest() and not trinket.is_banner:
			spent += trinket.cost
	_check(spent + overflow_pwr == budget and overflow_hp == 2 * overflow_pwr, "Banner budget/overflow did not balance exactly")
	drafts_checked += 1
	return units

func _run() -> void:
	var start_ms: int = Time.get_ticks_msec()
	for trait_name: StringName in EnemyTraitBannerProfiles.TRAITS:
		var profile: EnemyTraitBannerProfile = EnemyTraitBannerProfiles.create(trait_name)
		var drafter: TraitBannerDrafter = BannerDraftingRegistry.get_drafter(profile.banner_id) as TraitBannerDrafter
		var minimum: int = drafter.minimum_budget()
		_check(not BannerDraftingRegistry.regular_banner_ids(minimum - 1).has(profile.banner_id), "Banner appears below viable budget")
		_check(BannerDraftingRegistry.regular_banner_ids(minimum).has(profile.banner_id), "Viable banner missing from pool")
		var resource: TrinketDefinition = Database.get_definition(profile.banner_id) as TrinketDefinition
		_check(resource.is_banner and resource.is_enemy_exclusive and not resource.is_player_exclusive, "Banner resource exclusivity")
		_check(resource.icon.get_width() == 64 and resource.icon.get_height() == 64, "Banner sprite dimensions")
		for seed_value: int in range(6):
			for budget: int in [minimum, minimum + 1, maxi(minimum, 8), 16, 32]:
				RNGManager.initialize(seed_value + 100)
				var first: EncounterDefinition = drafter.draft_lineup(budget)
				_validate(first, profile, budget)
				RNGManager.initialize(seed_value + 100)
				var second: EncounterDefinition = drafter.draft_lineup(budget)
				_check(first.enemy_placements == second.enemy_placements and first.enemy_trinket_ids == second.enemy_trinket_ids, "Seeded banner generation diverged")
		RNGManager.initialize(400)
		var full: EncounterDefinition = drafter.draft_lineup(32)
		var original: Array[EncounterDraftUnit] = _validate(full, profile, 32)
		# All casualty patterns exercise isolated holes, contiguous pairs, triplets, and a wiped board.
		for mask: int in range(1 << original.size()):
			var survivors: Array[EncounterDraftUnit] = []
			var ids: Dictionary = {}
			var empty: Array[int] = []
			for i: int in range(original.size()):
				if mask & (1 << i):
					survivors.append(original[i].copy())
					ids[original[i].slot] = original[i].unit_id
			for slot: int in range(5):
				if not ids.has(slot):
					empty.append(slot)
			var before: Array[Dictionary] = []
			for survivor: EncounterDraftUnit in survivors:
				before.append(survivor.placement())
			var wave_rng := SeededRNG.new(&"banner_wave_test", mask + 88)
			var wave: Array[Dictionary] = EncounterGenerator.generate_banner_reinforcements(profile.banner_id, 32, ids, empty, full.enemy_trinket_ids, wave_rng, survivors)
			var wave_cost: int = 0
			var wave_overflow: int = 0
			var wave_hp: int = 0
			for data: Dictionary in wave:
				var unit: EncounterDraftUnit = _unit(data, true)
				_check(empty.has(unit.slot), "Reinforcement overwrote a survivor")
				empty.erase(unit.slot)
				_check(unit.trait_count(trait_name) > 0 and unit.items.size() <= 1, "Invalid reinforcement emblem/equipment")
				wave_cost += unit.gold_cost()
				wave_overflow += unit.bonus_pwr
				wave_hp += unit.bonus_hp
			_check(wave_hp == wave_overflow * 2, "Wave stat overflow ratio")
			_check(wave_cost + wave_overflow <= maxi(1, int(floor(32 * profile.wave_fraction))), "Wave overspent")
			for i: int in range(survivors.size()):
				_check(survivors[i].placement() == before[i], "Reinforcement mutated surviving unit")
			waves_checked += 1
		print("BANNER ", trait_name, " minimum budget=", minimum, " maximum tested trait count=", maximum_counts[trait_name])
		if profile.threshold() == 2:
			_check(maximum_counts[trait_name] == 5, "%s could not build a full five-unit trait formation" % trait_name)
	_test_dependency_repair()
	_test_burnie()
	_test_dustmon_traits()
	_test_combat_triggers()
	_test_banner_effect_and_summon()
	print("TRAIT BANNER SUITE: ", drafts_checked, " drafts, ", waves_checked, " casualty patterns, ", failures, " failures; ", Time.get_ticks_msec() - start_ms, "ms")
	get_tree().quit(1 if failures > 0 else 0)

func _test_dependency_repair() -> void:
	var drafter: TraitBannerDrafter = BannerDraftingRegistry.get_drafter(&"trinket_banner_fire_phalanx") as TraitBannerDrafter
	var branblee := EncounterDraftUnit.new(&"EFTnkMec", 0)
	var survivors: Array[EncounterDraftUnit] = [branblee]
	var slots: Array[int] = [1, 2, 3, 4]
	for seed_value: int in range(20):
		var wave: Array[Dictionary] = drafter.draft_reinforcements_from_snapshot(8, survivors, slots, [&"trinket_trait_fire"], SeededRNG.new(&"repair", seed_value))
		var restored: bool = false
		for data: Dictionary in wave:
			if data["slot"] == 1:
				restored = data["unit_id"] == &"WSupAni" and data["items"] == [&"item_emblem_fire"]
		_check(restored, "Fire wave failed to repair Branblee's missing healing partner")

func _test_burnie() -> void:
	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(&"trinket_banner_burnie")
	for budget: int in [1, 3, 8, 16]:
		var encounter: EncounterDefinition = drafter.draft_lineup(budget, {"daily_budget": budget})
		var bosses: int = 0
		for placement: Dictionary in encounter.enemy_placements:
			if placement["id"] == &"elite_burnie":
				bosses += 1
				_check(placement["position"] == 2, "Burnie lost its reserved slot")
		_check(bosses == 1, "Burnie was duplicated or omitted")

func _combat_manager() -> BattleManager:
	var bm: BattleManager = BattleManagerScript.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	GameManager.register_battle_manager(bm)
	GameManager.is_in_battle = true
	return bm

func _test_dustmon_traits() -> void:
	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(&"trinket_banner_dustmon")
	for seed_value: int in range(20):
		RNGManager.initialize(seed_value)
		var encounter: EncounterDefinition = drafter.draft_lineup(12, {"daily_budget": 12})
		for id: StringName in encounter.enemy_trinket_ids:
			var definition: TrinketDefinition = Database.get_definition(id) as TrinketDefinition
			_check(not definition.is_player_exclusive, "Dustmon rolled a player-only trait Crest")

func _live_unit(bm: BattleManager, id: StringName, slot: int, item_id: StringName = &"", player: bool = false) -> GachaBallInstance:
	var unit := GachaBallInstance.new()
	unit.initialize(Database.get_definition(id))
	_check(bm._state.bm_add_instance(unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, slot), "Failed to place combat fixture")
	if item_id != &"":
		var item := GachaBallInstance.new()
		item.initialize(Database.get_definition(item_id))
		var events: Array[CombatEvent] = []
		bm.bm_register_and_equip_item(item, unit.ball_uuid, 0, true, events)
	unit.current_hp = 100
	return unit

func _hurt(bm: BattleManager, victim: GachaBallInstance, attacker: GachaBallInstance) -> Array[CombatEvent]:
	bm.apply_damage(victim, 1, C.DamageType.MELEE, attacker.ball_uuid)
	bm.trigger_on_hurt(victim.ball_uuid, 1, attacker.ball_uuid, C.CAUSE_ATTACK)
	var deaths: Dictionary = {}
	return bm._combat.process_reaction_queue(bm, deaths)

func _close_combat(bm: BattleManager) -> void:
	GameManager.unregister_battle_manager()
	GameManager.is_in_battle = false
	bm.free()

func _test_combat_triggers() -> void:
	# Fire: the actual ally-hurt reaction heals Branblee and produces Armor/Spikes.
	var bm: BattleManager = _combat_manager()
	var branblee: GachaBallInstance = _live_unit(bm, &"EFTnkMec", 0)
	_live_unit(bm, &"WSupAni", 1, &"item_emblem_fire")
	_live_unit(bm, &"FFigMec", 3)
	var attacker: GachaBallInstance = _live_unit(bm, &"ETnkPla", 4, &"", true)
	bm.register_test_trinket(&"trinket_trait_fire", true)
	_check(bm.get_active_traits("ENEMY")["FIRE"] == 3, "Equipped Fire Emblem did not activate live Fire threshold")
	var events: Array[CombatEvent] = _hurt(bm, branblee, attacker)
	_check(branblee.get_status_effect_amount(&"armor") > 0 and branblee.get_status_effect_amount(&"spikes") > 0, "Ripplepup healing did not activate Branblee")
	_check(not events.is_empty(), "Healing/Armor reaction omitted combat events")
	_close_combat(bm)

	# Food: the source heals backward into Pepspray; Nuton copies Pepspray's PWR buff.
	bm = _combat_manager()
	var stumpling: GachaBallInstance = _live_unit(bm, &"ETnkPla", 0, &"item_emblem_food")
	var pepspray: GachaBallInstance = _live_unit(bm, &"FWFigFod", 1)
	var nuton: GachaBallInstance = _live_unit(bm, &"FWWATnkFod", 2)
	var snapshot: EncounterDraftUnit = EncounterDraftUnit.from_live(nuton, bm.get_all_instances())
	_check(snapshot.trait_count(&"Water") == 2, "Live reinforcement snapshot lost a repeated Water soul")
	_live_unit(bm, &"ASpeFod", 3)
	attacker = _live_unit(bm, &"ETnkPla", 4, &"", true)
	bm.register_test_trinket(&"trinket_trait_food", true)
	var pwr_before: int = nuton.current_pwr
	_hurt(bm, stumpling, attacker)
	_check(pepspray.current_hp > 100 and attacker.get_status_effect_amount(&"burn") > 0, "Food healing failed to activate Pepspray's Burn")
	_check(nuton.current_pwr > pwr_before, "Nuton did not copy adjacent Pepspray's Food PWR buff")
	_close_combat(bm)

	# Animal: attacking heals converted Pepspray, which launches its own Burn ability.
	bm = _combat_manager()
	pepspray = _live_unit(bm, &"FWFigFod", 0, &"item_emblem_animal")
	_live_unit(bm, &"WSupAni", 1)
	attacker = _live_unit(bm, &"ETnkPla", 4, &"", true)
	bm.register_test_trinket(&"trinket_trait_animal", true)
	var basic: AbilityDefinition = bm.get_basic_attack_for(pepspray)
	var context := TriggerContext.new()
	context.is_simulation = true
	context.source_pwr = pepspray.current_pwr
	context.source_hp = pepspray.current_hp
	context.source_category = &"UNIT"
	context.trigger_cause = C.CAUSE_TURN
	var targets: Array[String] = [attacker.ball_uuid]
	bm.enqueue_effect_request(EffectRequest.new(pepspray.ball_uuid, basic.id, basic.effects[0], targets, context))
	var deaths: Dictionary = {}
	bm._combat.process_reaction_queue(bm, deaths)
	_check(pepspray.current_hp > 100 and attacker.get_status_effect_amount(&"burn") > 0, "Animal attack healing failed to activate Pepspray")
	_close_combat(bm)

	# Oakbark: the buff recipient, rather than just the buff source, is adjacent to Nuton.
	bm = _combat_manager()
	_live_unit(bm, &"ETnkPla", 0)
	var oakbark: GachaBallInstance = _live_unit(bm, &"EEFWSupPla", 1)
	_live_unit(bm, &"EWFigCos", 2)
	nuton = _live_unit(bm, &"FWWATnkFod", 3)
	attacker = _live_unit(bm, &"ETnkPla", 4, &"", true)
	pwr_before = nuton.current_pwr
	_hurt(bm, oakbark, attacker)
	_check(nuton.current_pwr == pwr_before + 1 and nuton.current_hp == 101, "Oakbark/Bogmantle/Nuton failed to copy the adjacent recipient's HP/PWR buffs")
	_close_combat(bm)

func _test_banner_effect_and_summon() -> void:
	var bm: BattleManager = _combat_manager()
	_live_unit(bm, &"EFTnkMec", 0)
	bm.register_test_trinket(&"trinket_trait_fire", true)
	var banner: GachaBallInstance = bm.register_test_trinket(&"trinket_banner_fire_phalanx", true)
	var definition: TrinketDefinition = Database.get_definition(banner.definition_id) as TrinketDefinition
	var ability: AbilityDefinition = definition.ability_definitions[0]
	var effect: EffectDefinition = ability.effects[0]
	var context := TriggerContext.new()
	context.is_simulation = true
	context.team = "ENEMY"
	context.current_day = 6 # Daily budget 8; Fire wave budget 4.
	context.turn = 2
	var targets: Array[String] = []
	var quiet: EffectResult = effect.execute(banner.ball_uuid, targets, bm, context)
	_check(quiet.summon_units_request.is_empty(), "Banner reinforced on an even turn")
	context.turn = 1
	var wave: EffectResult = effect.execute(banner.ball_uuid, targets, bm, context)
	_check(not wave.summon_units_request.is_empty(), "Odd-turn banner effect failed to produce reinforcements")
	var request := EffectRequest.new(banner.ball_uuid, ability.id, effect, targets, context)
	var command := SummonUnitsCommand.new(request, bm._combat, bm, wave)
	var events: Array[CombatEvent] = []
	var deaths: Dictionary = {}
	command.execute(events, deaths)
	var restored: GachaBallInstance = bm.get_instance_by_location(LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 1))
	_check(restored != null and restored.definition_id == &"WSupAni" and bm.has_trait(restored, "FIRE"), "Summon command lost the repaired healer's Fire Emblem. Planned: %s; actual slot 1: %s" % [wave.summon_units_request, restored.to_save_dict() if restored != null else {}])
	var summons: int = 0
	for event: CombatEvent in events:
		if event.type == CombatEvent.Type.SUMMON:
			summons += 1
	_check(summons > 0 and bm._state.validate_state_consistency(), "Banner summon omitted events or corrupted placement/equipment")
	_close_combat(bm)


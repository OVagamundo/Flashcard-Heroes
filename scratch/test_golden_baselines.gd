extends Node

const C = preload("res://scripts/Constants.gd")
const FORCE_RECORD_BASELINES: bool = false

func _ready() -> void:
	print("====================================================")
	print("Starting Golden Baseline Generation Harness (All 8 Encounters)")
	print("====================================================")
	call_deferred("_run_all_encounters")

func _run_all_encounters() -> void:
	var encounters = [
		run_encounter_1_guardian_sentinel,
		run_encounter_2_lethal_counter_attack,
		run_encounter_3_soul_echo_vs_death_summons,
		run_encounter_4_mimic_mirror_image,
		run_encounter_5_aegis_charm_lethal_save,
		run_encounter_6_melee_suicide_spikes,
		run_encounter_7_polished_plate_armor_decay,
		run_encounter_8_multi_stat_buff_projectiles
	]
	
	for i in range(encounters.size()):
		var enc_fn = encounters[i]
		var success: bool = enc_fn.call()
		if not success:
			print("FAILED at encounter index %d" % (i + 1))
			get_tree().quit(1)
			return

	print("\n====================================================")
	print(">>> ALL 8 GOLDEN BASELINE ENCOUNTERS GENERATED & VERIFIED! <<<")
	print("====================================================")
	get_tree().quit(0)

# ==============================================================================
# ENCOUNTER 1: Guardian Sentinel Interception
# ==============================================================================
func run_encounter_1_guardian_sentinel() -> bool:
	print("\n--- Running Encounter 1: Guardian Sentinel Interception ---")
	var bm = _create_test_battle_manager()
	
	var guardian = GachaBallInstance.new()
	var guardian_def: GachaBallDefinition = Database.get_definition(&"unit_t3_b")
	guardian.initialize(guardian_def)
	guardian.ball_uuid = "player_guardian"
	guardian.current_hp = 5
	guardian.current_pwr = 1
	bm.bm_add_instance(guardian, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	var ally = GachaBallInstance.new()
	var ally_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	ally.initialize(ally_def)
	ally.ball_uuid = "player_ally"
	ally.current_hp = 3
	ally.current_pwr = 1
	bm.bm_add_instance(ally, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)

	var enemy = GachaBallInstance.new()
	var enemy_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	enemy.initialize(enemy_def)
	enemy.ball_uuid = "enemy_attacker"
	enemy.current_hp = 10
	enemy.current_pwr = 4
	bm.bm_add_instance(enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	assert(ally.current_hp == 3, "Player ally should remain unharmed at 3 HP! Got %d" % ally.current_hp)
	assert(guardian.current_hp == 1, "Guardian should have absorbed hit (5 HP - 4 dmg = 1 HP), got %d" % guardian.current_hp)
	
	var intercept_evts = []
	for evt in turn_log:
		if evt.visual_payload and not evt.visual_payload.pre_impact_events.is_empty():
			for pie in evt.visual_payload.pre_impact_events:
				if pie.type == CombatEvent.Type.GUARDIAN_INTERCEPT:
					intercept_evts.append(pie)
	assert(not intercept_evts.is_empty(), "Must have emitted GUARDIAN_INTERCEPT event")

	var encounter_data = serialize_encounter_result("01_guardian_sentinel_intercept", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/01_guardian_sentinel_intercept.json", encounter_data)
	assert(matched, "Encounter 1 baseline regression failure!")
	print("PASS: Encounter 1 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 2: Lethal Counter-Attack (execute_on_lethal)
# ==============================================================================
func run_encounter_2_lethal_counter_attack() -> bool:
	print("\n--- Running Encounter 2: Lethal Counter-Attack (execute_on_lethal) ---")
	var bm = _create_test_battle_manager()
	
	var attacker = GachaBallInstance.new()
	var attacker_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	attacker.initialize(attacker_def)
	attacker.ball_uuid = "player_attacker"
	attacker.current_hp = 10
	attacker.current_pwr = 4
	bm.bm_add_instance(attacker, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	var counter_unit = GachaBallInstance.new()
	var counter_def: GachaBallDefinition = Database.get_definition(&"unit_t1_b")
	counter_unit.initialize(counter_def)
	counter_unit.ball_uuid = "enemy_counter"
	counter_unit.current_hp = 2
	counter_unit.current_pwr = 3
	bm.bm_add_instance(counter_unit, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	print("Encounter 2 turn_log count: ", turn_log.size())
	for e in turn_log:
		print(" - Enc 2 Evt: #%d %s | src=%s | tgts=%s | ability=%s | trigger=%s" % [e.event_id, e.get_type_name(), e.source_uuid, str(e.target_uuids), e.ability_id, e.trigger_type])
		if e.visual_payload and not e.visual_payload.impact_events.is_empty():
			for ie in e.visual_payload.impact_events:
				print("   * Impact: #%d %s | src=%s | tgts=%s | ability=%s" % [ie.event_id, ie.get_type_name(), ie.source_uuid, str(ie.target_uuids), ie.ability_id])

	assert(counter_unit.current_hp <= 0, "Counter unit must have received lethal damage")
	var death_events = turn_log.filter(func(e): return e.type == CombatEvent.Type.DEATH and e.target_uuids.has("enemy_counter"))
	assert(not death_events.is_empty(), "Must have emitted DEATH event for enemy_counter")
	
	var counter_hits = turn_log.filter(func(e): return e.type == CombatEvent.Type.DAMAGE and e.source_uuid == "enemy_counter")
	# Check if counter occurred via normal event or impact event
	var had_counter = not counter_hits.is_empty()
	if not had_counter:
		for e in turn_log:
			if e.visual_payload and not e.visual_payload.impact_events.is_empty():
				for ie in e.visual_payload.impact_events:
					if ie.source_uuid == "enemy_counter" or ie.ability_id == &"unit_tier1b_counter_on_hurt":
						had_counter = true
	assert(had_counter, "Counter unit must have executed retaliate counter before dying")

	var encounter_data = serialize_encounter_result("02_lethal_counter_attack", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/02_lethal_counter_attack.json", encounter_data)
	assert(matched, "Encounter 2 baseline regression failure!")
	print("PASS: Encounter 2 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 3: Soul Echo vs. On-Death Summons
# ==============================================================================
func run_encounter_3_soul_echo_vs_death_summons() -> bool:
	print("\n--- Running Encounter 3: Soul Echo vs. On-Death Summons ---")
	var bm = _create_test_battle_manager()
	
	# Equip Soul Echo on Player team
	TestModeHelpers.register_test_trinket(bm, &"trinket_soul_echo", false)

	# Slot 0: Living hero/ally so combat continues
	var hero = GachaBallInstance.new()
	var hero_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	hero.initialize(hero_def)
	hero.ball_uuid = "player_hero"
	hero.current_hp = 10
	hero.current_pwr = 0
	bm.bm_add_instance(hero, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	# Slot 1: Unit that dies and has on-death summon item
	var dying_unit = GachaBallInstance.new()
	var dying_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	dying_unit.initialize(dying_def)
	dying_unit.ball_uuid = "player_dying_unit"
	dying_unit.current_hp = 2
	dying_unit.current_pwr = 0
	bm.bm_add_instance(dying_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 1)

	# Equip ItemTier2A on dying unit (has ability_item_t2_c_summon, on_death summon)
	TestModeHelpers.register_test_item_on_unit(bm, &"item_t2_a", dying_unit.ball_uuid)

	# Enemy Attacker in slot 0 (10 HP, 6 PWR - lethal to dying unit in frontline slot 1)
	var enemy = GachaBallInstance.new()
	var enemy_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	enemy.initialize(enemy_def)
	enemy.ball_uuid = "enemy_attacker"
	enemy.current_hp = 10
	enemy.current_pwr = 6
	bm.bm_add_instance(enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Soul Echo must have resurrected first killed unit into slot 1
	var player_lineup = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var slot_1_uuid = player_lineup.get_uuid(1)
	assert(not slot_1_uuid.is_empty(), "Slot 1 must have resurrected unit")
	
	# 2. Item summon should be present in lineup
	var slot_2_uuid = player_lineup.get_uuid(2)
	assert(not slot_2_uuid.is_empty(), "Slot 2 must have item summon displaced to next slot")

	var encounter_data = serialize_encounter_result("03_soul_echo_vs_death_summons", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/03_soul_echo_vs_death_summons.json", encounter_data)
	assert(matched, "Encounter 3 baseline regression failure!")
	print("PASS: Encounter 3 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 4: Mimic Mirror Image (In-Place Turn Replacement)
# ==============================================================================
func run_encounter_4_mimic_mirror_image() -> bool:
	print("\n--- Running Encounter 4: Mimic Mirror Image ---")
	var bm = _create_test_battle_manager()
	
	# Player Mimic in Slot 0 (5 HP, 1 PWR)
	var mimic = GachaBallInstance.new()
	var mimic_def: GachaBallDefinition = Database.get_definition(&"unit_t3_mimic")
	mimic.initialize(mimic_def)
	mimic.ball_uuid = "player_mimic"
	mimic.current_hp = 5
	mimic.current_pwr = 1
	bm.bm_add_instance(mimic, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	# Opposing Enemy in Mirror Slot 4 (since 4 - 0 = 4)
	var enemy = GachaBallInstance.new()
	var enemy_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	enemy.initialize(enemy_def)
	enemy.ball_uuid = "enemy_mirror_target"
	enemy.current_hp = 10
	enemy.current_pwr = 1
	bm.bm_add_instance(enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 4)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Transform event was produced
	var transform_evts = turn_log.filter(func(e): return e.type == CombatEvent.Type.TRANSFORM or e.type == CombatEvent.Type.SUMMON)
	assert(not transform_evts.is_empty(), "Mimic must emit TRANSFORM or SUMMON event")

	# 2. Player Slot 0 now has transformed unit definition
	var player_lineup = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var transformed_uuid = player_lineup.get_uuid(0)
	var transformed_inst = bm.get_instance_by_uuid(transformed_uuid)
	assert(is_instance_valid(transformed_inst), "Slot 0 must contain valid transformed instance")
	assert(transformed_inst.definition_id == &"unit_t1_a", "Mimic must transform into mirror target unit_t1_a")

	var encounter_data = serialize_encounter_result("04_mimic_mirror_image", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/04_mimic_mirror_image.json", encounter_data)
	assert(matched, "Encounter 4 baseline regression failure!")
	print("PASS: Encounter 4 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 5: Aegis Charm Lethal Save
# ==============================================================================
func run_encounter_5_aegis_charm_lethal_save() -> bool:
	print("\n--- Running Encounter 5: Aegis Charm Lethal Save ---")
	var bm = _create_test_battle_manager()
	
	# Equip Aegis Charm
	TestModeHelpers.register_test_trinket(bm, &"trinket_aegis", false)

	# Player unit (3 HP, 0 PWR)
	var unit = GachaBallInstance.new()
	var unit_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	unit.initialize(unit_def)
	unit.ball_uuid = "player_hero"
	unit.current_hp = 3
	unit.current_pwr = 0
	bm.bm_add_instance(unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	# Enemy dealing lethal damage (10 PWR)
	var enemy = GachaBallInstance.new()
	var enemy_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	enemy.initialize(enemy_def)
	enemy.ball_uuid = "enemy_boss"
	enemy.current_hp = 20
	enemy.current_pwr = 10
	bm.bm_add_instance(enemy, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Unit HP clamped to 1 (not dead)
	assert(unit.current_hp == 1, "Aegis Charm must save unit at 1 HP! Got %d" % unit.current_hp)
	
	# 2. LETHAL_SAVE event exists (top-level or inside impact_events)
	var has_save := false
	for e in turn_log:
		if e.type == CombatEvent.Type.LETHAL_SAVE:
			has_save = true
			break
		if e.visual_payload and not e.visual_payload.impact_events.is_empty():
			for ie in e.visual_payload.impact_events:
				if ie.type == CombatEvent.Type.LETHAL_SAVE:
					has_save = true
					break
	assert(has_save, "Must emit LETHAL_SAVE event")

	# 3. No DEATH event for player_hero
	var death_evts = turn_log.filter(func(e): return e.type == CombatEvent.Type.DEATH and e.target_uuids.has("player_hero"))
	assert(death_evts.is_empty(), "Player hero must NOT die when saved by Aegis Charm")

	var encounter_data = serialize_encounter_result("05_aegis_charm_lethal_save", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/05_aegis_charm_lethal_save.json", encounter_data)
	assert(matched, "Encounter 5 baseline regression failure!")
	print("PASS: Encounter 5 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 6: Melee Suicide via Spikes
# ==============================================================================
func run_encounter_6_melee_suicide_spikes() -> bool:
	print("\n--- Running Encounter 6: Melee Suicide via Spikes ---")
	var bm = _create_test_battle_manager()
	
	# Player defender (10 HP, 0 PWR, 5 stacks of spikes)
	var defender = GachaBallInstance.new()
	var def_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	defender.initialize(def_def)
	defender.ball_uuid = "player_spikes_defender"
	defender.current_hp = 10
	defender.current_pwr = 0
	defender.add_status_effect(&"spikes", 5)
	bm.bm_add_instance(defender, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	# Enemy melee attacker (2 HP, 3 PWR)
	var attacker = GachaBallInstance.new()
	var atk_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	attacker.initialize(atk_def)
	attacker.ball_uuid = "enemy_attacker"
	attacker.current_hp = 2
	attacker.current_pwr = 3
	bm.bm_add_instance(attacker, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	bm._populate_actor_queue()
	var death_tracking: Dictionary = {}
	var turn_log: Array[CombatEvent] = bm._combat.execute_combat_turn(bm, death_tracking)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Defender took 3 damage (10 -> 7 HP), then UnitTier1A on_hurt passive heal restored 1 HP -> 8 HP
	assert(defender.current_hp == 8, "Defender should have 8 HP (10 - 3 + 1 heal), got %d" % defender.current_hp)
	
	# 2. Enemy attacker died from spikes reflection (2 HP - 5 spikes <= 0)
	assert(attacker.current_hp <= 0, "Attacker should have died from spikes reflection, got %d" % attacker.current_hp)
	
	var death_evts = turn_log.filter(func(e): return e.type == CombatEvent.Type.DEATH and e.target_uuids.has("enemy_attacker"))
	assert(not death_evts.is_empty(), "Must emit DEATH event for enemy attacker killed by spikes")

	var encounter_data = serialize_encounter_result("06_melee_suicide_spikes", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/06_melee_suicide_spikes.json", encounter_data)
	assert(matched, "Encounter 6 baseline regression failure!")
	print("PASS: Encounter 6 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 7: Polished Plate End-of-Turn Decay
# ==============================================================================
func run_encounter_7_polished_plate_armor_decay() -> bool:
	print("\n--- Running Encounter 7: Polished Plate End-of-Turn Decay ---")
	var bm = _create_test_battle_manager()
	
	# Equip Polished Plate on Player team
	TestModeHelpers.register_test_trinket(bm, &"trinket_polished_plate", false)

	# Player unit with 4 Armor
	var player_unit = GachaBallInstance.new()
	var p_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	player_unit.initialize(p_def)
	player_unit.ball_uuid = "player_armored"
	player_unit.current_hp = 5
	player_unit.current_pwr = 1
	player_unit.add_status_effect(&"armor", 4)
	bm.bm_add_instance(player_unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	# Enemy unit with 4 Armor (no Polished Plate)
	var enemy_unit = GachaBallInstance.new()
	var e_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	enemy_unit.initialize(e_def)
	enemy_unit.ball_uuid = "enemy_armored"
	enemy_unit.current_hp = 5
	enemy_unit.current_pwr = 1
	enemy_unit.add_status_effect(&"armor", 4)
	bm.bm_add_instance(enemy_unit, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	# Trigger End of Turn Decay directly
	var turn_log: Array[CombatEvent] = []
	bm._trigger_turn_end_abilities()
	# Collect events generated during turn end
	var end_turn_events = bm._combat.process_reaction_queue(bm, {})
	turn_log.append_array(end_turn_events)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Player unit armor preserved at 4
	var p_armor = player_unit.get_status_effect_amount(&"armor")
	assert(p_armor == 4, "Player armor must be preserved at 4 via Polished Plate! Got %d" % p_armor)

	# 2. Enemy unit armor decayed to 0
	var e_armor = enemy_unit.get_status_effect_amount(&"armor")
	assert(e_armor == 0, "Enemy armor must decay to 0! Got %d" % e_armor)

	var encounter_data = serialize_encounter_result("07_polished_plate_armor_decay", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/07_polished_plate_armor_decay.json", encounter_data)
	assert(matched, "Encounter 7 baseline regression failure!")
	print("PASS: Encounter 7 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# ENCOUNTER 8: Multi-Stat Buff Projectiles
# ==============================================================================
func run_encounter_8_multi_stat_buff_projectiles() -> bool:
	print("\n--- Running Encounter 8: Multi-Stat Buff Projectiles ---")
	var bm = _create_test_battle_manager()
	
	var unit = GachaBallInstance.new()
	var u_def: GachaBallDefinition = Database.get_definition(&"unit_t1_a")
	unit.initialize(u_def)
	unit.ball_uuid = "player_buffed_unit"
	unit.current_hp = 5
	unit.current_pwr = 2
	bm.bm_add_instance(unit, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	CombatEvent.reset_event_counter()
	var start_snapshot = bm.get_board_snapshot()

	# Trigger multi-stat buff via EffectModifyBothStats
	var effect = load("res://scripts/effects/EffectModifyBothStats.gd").new()
	effect.parameters = { "hp_value": 2, "pwr_value": 3 }
	var targets: Array[String] = ["player_buffed_unit"]
	var res = effect.execute("player_buffed_unit", targets, bm, {"is_simulation": true})

	var turn_log: Array[CombatEvent] = []
	turn_log.append_array(res.events)
	var end_snapshot = bm.get_board_snapshot()

	# Assertions:
	# 1. Stats updated to 7 HP (5+2) and 5 PWR (2+3)
	assert(unit.current_hp == 7, "Unit HP should be 7, got %d" % unit.current_hp)
	assert(unit.current_pwr == 5, "Unit PWR should be 5, got %d" % unit.current_pwr)

	# 2. Turn log has single BUFF event containing both hp and pwr amounts
	var buff_evts = turn_log.filter(func(e): return e.type == CombatEvent.Type.BUFF)
	assert(not buff_evts.is_empty(), "Must emit BUFF event")
	var payload = buff_evts[0].visual_payload
	assert(payload.hp_amount == 2 and payload.pwr_amount == 3, "Payload must carry both HP and PWR deltas")

	var encounter_data = serialize_encounter_result("08_multi_stat_buff_projectiles", start_snapshot, turn_log, end_snapshot)
	var matched: bool = verify_or_save_baseline("res://scratch/golden_baselines/08_multi_stat_buff_projectiles.json", encounter_data)
	assert(matched, "Encounter 8 baseline regression failure!")
	print("PASS: Encounter 8 baseline verified.")
	bm.free()
	return true

# ==============================================================================
# HELPER: BattleManager Setup
# ==============================================================================
func _create_test_battle_manager() -> BattleManager:
	RNGManager.initialize(12345)
	for existing in get_tree().get_nodes_in_group("battle_manager"):
		if is_instance_valid(existing):
			existing.free()
	var bm = BattleManager.new()
	bm.name = "BattleManager"
	bm.is_test_mode = true
	add_child(bm)
	bm._change_phase(bm.Phases.COMBAT)
	return bm

# ==============================================================================
# ==============================================================================
# CANONICAL UUID ENGINE
# ==============================================================================
static var _uuid_map: Dictionary = {}
static var _uuid_prefix_counters: Dictionary = {}
static var _uuid_regex: RegEx = null

static func reset_uuid_canonicalizer() -> void:
	_uuid_map.clear()
	_uuid_prefix_counters.clear()
	if _uuid_regex == null:
		_uuid_regex = RegEx.new()
		_uuid_regex.compile("^(.+)_\\d{9,12}_\\d+_\\d{4,6}$")

static func canonicalize_uuid(raw_id: String) -> String:
	if raw_id.is_empty():
		return ""
	if _uuid_map.has(raw_id):
		return _uuid_map[raw_id]
	if _uuid_regex != null:
		var match_res = _uuid_regex.search(raw_id)
		if match_res != null:
			var prefix = match_res.get_string(1)
			var next_idx = _uuid_prefix_counters.get(prefix, 0) + 1
			_uuid_prefix_counters[prefix] = next_idx
			var canonical = "dyn_%s_%d" % [prefix, next_idx]
			_uuid_map[raw_id] = canonical
			return canonical
	return raw_id

# ==============================================================================
# SERIALIZATION ENGINE
# ==============================================================================
static func serialize_encounter_result(encounter_name: String, start_snapshot: Dictionary, turn_log: Array[CombatEvent], end_snapshot: Dictionary) -> Dictionary:
	reset_uuid_canonicalizer()
	return {
		"encounter_name": encounter_name,
		"start_snapshot": serialize_snapshot(start_snapshot),
		"turn_log": serialize_turn_log(turn_log),
		"end_snapshot": serialize_snapshot(end_snapshot)
	}

static func serialize_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var sorted_keys = snapshot.keys()
	sorted_keys.sort()
	for k in sorted_keys:
		var val = snapshot[k]
		var canon_k = canonicalize_uuid(String(k))
		if val is Dictionary:
			var item_dict: Dictionary = {}
			var inner_keys = val.keys()
			inner_keys.sort()
			for ik in inner_keys:
				if ik == "icon":
					continue
				var inner_val = val[ik]
				if inner_val is StringName:
					item_dict[ik] = String(inner_val)
				elif inner_val is String:
					item_dict[ik] = canonicalize_uuid(inner_val)
				elif inner_val is Array:
					var arr: Array = []
					for item in inner_val:
						if item is String or item is StringName:
							arr.append(canonicalize_uuid(String(item)))
						else:
							arr.append(item)
					item_dict[ik] = arr
				else:
					item_dict[ik] = inner_val
			result[canon_k] = item_dict
		elif val is StringName or val is String:
			result[canon_k] = canonicalize_uuid(String(val))
		else:
			result[canon_k] = val
	return result

static func serialize_turn_log(turn_log: Array[CombatEvent]) -> Array:
	var result: Array = []
	for event in turn_log:
		result.append(serialize_event(event))
	return result

static func serialize_event(event: CombatEvent) -> Dictionary:
	var canon_targets: Array = []
	for t in event.target_uuids:
		canon_targets.append(canonicalize_uuid(t))
	var d: Dictionary = {
		"event_id": event.event_id,
		"type": event.get_type_name(),
		"action_type": String(event.action_type),
		"source_uuid": canonicalize_uuid(event.source_uuid),
		"target_uuids": canon_targets
	}
	if event.cause_event_id != -1:
		d["cause_event_id"] = event.cause_event_id
	if event.ability_id != &"":
		d["ability_id"] = String(event.ability_id)
	if event.trigger_type != &"":
		d["trigger_type"] = String(event.trigger_type)
	if not event.ability_holder_uuid.is_empty():
		d["ability_holder_uuid"] = canonicalize_uuid(event.ability_holder_uuid)
	if event.visual_payload != null:
		d["payload"] = serialize_payload(event.visual_payload)
	return d

static func serialize_payload(p: CombatPayload) -> Dictionary:
	var d: Dictionary = {}
	if p.action_type != &"":
		d["action_type"] = String(p.action_type)
	if p.amount != 0:
		d["amount"] = p.amount
	if p.hp_amount != 0:
		d["hp_amount"] = p.hp_amount
	if p.pwr_amount != 0:
		d["pwr_amount"] = p.pwr_amount
	if not p.stat.is_empty():
		d["stat"] = p.stat
	if not p.attack_type.is_empty() and p.attack_type != "melee":
		d["attack_type"] = p.attack_type
	elif p.action_type == C.ACTION_DAMAGE:
		d["attack_type"] = p.attack_type
	if not p.main_target_uuid.is_empty():
		d["main_target_uuid"] = canonicalize_uuid(p.main_target_uuid)
	if not p.original_target_uuid.is_empty():
		d["original_target_uuid"] = canonicalize_uuid(p.original_target_uuid)
	if not p.guardian_uuid.is_empty():
		d["guardian_uuid"] = canonicalize_uuid(p.guardian_uuid)
	if not p.saved_uuid.is_empty():
		d["saved_uuid"] = canonicalize_uuid(p.saved_uuid)
	if not p.origin_uuid.is_empty():
		d["origin_uuid"] = canonicalize_uuid(p.origin_uuid)
	if not p.old_unit_uuid.is_empty():
		d["old_unit_uuid"] = canonicalize_uuid(p.old_unit_uuid)
	if not p.new_unit_uuid.is_empty():
		d["new_unit_uuid"] = canonicalize_uuid(p.new_unit_uuid)
	if not p.targets_old_hp.is_empty():
		d["targets_old_hp"] = p.targets_old_hp.duplicate()
	if not p.targets_new_hp.is_empty():
		d["targets_new_hp"] = p.targets_new_hp.duplicate()
	if not p.targets_old_pwr.is_empty():
		d["targets_old_pwr"] = p.targets_old_pwr.duplicate()
	if not p.targets_new_pwr.is_empty():
		d["targets_new_pwr"] = p.targets_new_pwr.duplicate()
	if not p.targets_old_armor.is_empty():
		d["targets_old_armor"] = p.targets_old_armor.duplicate()
	if not p.targets_new_armor.is_empty():
		d["targets_new_armor"] = p.targets_new_armor.duplicate()
	if not p.armor_consumed.is_empty():
		d["armor_consumed"] = p.armor_consumed.duplicate()
	if not p.targets_old_burn.is_empty():
		d["targets_old_burn"] = p.targets_old_burn.duplicate()
	if not p.targets_new_burn.is_empty():
		d["targets_new_burn"] = p.targets_new_burn.duplicate()
	if not p.targets_old_val.is_empty():
		d["targets_old_val"] = p.targets_old_val.duplicate()
	if not p.targets_new_val.is_empty():
		d["targets_new_val"] = p.targets_new_val.duplicate()
	
	# Sub-phase events
	if not p.windup_events.is_empty():
		d["windup_events"] = serialize_turn_log(p.windup_events)
	if not p.pre_impact_events.is_empty():
		d["pre_impact_events"] = serialize_turn_log(p.pre_impact_events)
	if not p.impact_events.is_empty():
		d["impact_events"] = serialize_turn_log(p.impact_events)
	
	# Spikes
	if not p.spikes_data_list.is_empty():
		var spikes: Array = []
		for s in p.spikes_data_list:
			spikes.append({
				"attacker_uuid": canonicalize_uuid(s.attacker_uuid),
				"defender_uuid": canonicalize_uuid(s.defender_uuid),
				"spikes_damage": s.spikes_damage,
				"attacker_old_hp": s.attacker_old_hp,
				"attacker_new_hp": s.attacker_new_hp,
				"old_spikes": s.old_spikes,
				"new_spikes": s.new_spikes,
				"armor_consumed": s.armor_consumed
			})
		d["spikes_data"] = spikes

	return d

static func save_json(res_path: String, data: Dictionary) -> void:
	var global_path = ProjectSettings.globalize_path(res_path)
	var file = FileAccess.open(global_path, FileAccess.WRITE)
	assert(file != null, "Failed to open file for writing: %s" % global_path)
	var json_string = JSON.stringify(data, "  ")
	file.store_string(json_string)
	file.close()

static func load_json(res_path: String) -> Dictionary:
	var global_path = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(global_path):
		return {}
	var file = FileAccess.open(global_path, FileAccess.READ)
	assert(file != null, "Failed to open file for reading: %s" % global_path)
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	assert(parsed is Dictionary, "Invalid JSON in baseline: %s" % global_path)
	return parsed

static func verify_or_save_baseline(res_path: String, actual_data: Dictionary, force_record: bool = FORCE_RECORD_BASELINES) -> bool:
	var global_path = ProjectSettings.globalize_path(res_path)
	if force_record or not FileAccess.file_exists(global_path):
		save_json(res_path, actual_data)
		print("Recorded baseline: %s" % res_path)
		return true
	
	var expected_data = load_json(res_path)
	var diffs: Array[String] = []
	deep_compare(expected_data, actual_data, "", diffs)
	if not diffs.is_empty():
		print("\n[BASELINE REGRESSION DETECTED in %s]" % res_path)
		for d in diffs:
			print("  - " + d)
		return false
	return true

static func deep_compare(expected: Variant, actual: Variant, path: String, diffs: Array[String]) -> void:
	# String / StringName equivalence
	if (expected is String or expected is StringName) and (actual is String or actual is StringName):
		if String(expected) != String(actual):
			diffs.append("%s: string mismatch (expected %s, got %s)" % [path, str(expected), str(actual)])
		return

	# Numeric equivalence (JSON parses all numbers as float)
	if (expected is int or expected is float) and (actual is int or actual is float):
		if float(expected) != float(actual):
			diffs.append("%s: numeric mismatch (expected %s, got %s)" % [path, str(expected), str(actual)])
		return

	if typeof(expected) != typeof(actual):
		diffs.append("%s: type mismatch (expected %s, got %s)" % [path, type_string(typeof(expected)), type_string(typeof(actual))])
		return

	if expected is Dictionary:
		var exp_dict: Dictionary = expected
		var act_dict: Dictionary = actual
		var all_keys: Dictionary = {}
		for k in exp_dict.keys(): all_keys[k] = true
		for k in act_dict.keys(): all_keys[k] = true
		for k in all_keys.keys():
			var sub_path = path + "." + String(k) if not path.is_empty() else String(k)
			if not exp_dict.has(k):
				diffs.append("%s: unexpected extra key in actual" % sub_path)
			elif not act_dict.has(k):
				diffs.append("%s: missing key in actual" % sub_path)
			else:
				deep_compare(exp_dict[k], act_dict[k], sub_path, diffs)
	elif expected is Array:
		var exp_arr: Array = expected
		var act_arr: Array = actual
		if exp_arr.size() != act_arr.size():
			diffs.append("%s: array length mismatch (expected %d, got %d)" % [path, exp_arr.size(), act_arr.size()])
			return
		for i in range(exp_arr.size()):
			deep_compare(exp_arr[i], act_arr[i], "%s[%d]" % [path, i], diffs)
	else:
		if expected != actual:
			diffs.append("%s: value mismatch (expected %s, got %s)" % [path, str(expected), str(actual)])

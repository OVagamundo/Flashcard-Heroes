extends Node

const C = preload("res://scripts/Constants.gd")

func _ready() -> void:
	print("--- Starting Templar Dynamic Ability Verification in Scene ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. Verify Ability Definitions
	var t2_d_def: GachaBallDefinition = load("res://resources/units/UnitTier2D.tres")
	assert(is_instance_valid(t2_d_def), "UnitTier2D.tres failed to load")
	assert(t2_d_def.base_hp == 2, "Base HP must be 2")
	assert(t2_d_def.base_pwr == 3, "Base PWR must be 3")
	print("PASS: Templar base stats are 2 HP / 3 PWR")

	var ability_l1: AbilityDefinition = load("res://resources/abilities/Ability_Tier2D_Templar_Power.tres")
	var ability_l2: AbilityDefinition = load("res://resources/abilities/Ability_Tier2D_Templar_Power_L2.tres")
	var ability_l3: AbilityDefinition = load("res://resources/abilities/Ability_Tier2D_Templar_Power_L3.tres")

	assert(ability_l1.trigger == &"on_gacha_tokens_changed", "L1 trigger must be on_gacha_tokens_changed")
	assert(ability_l2.trigger == &"on_gacha_tokens_changed", "L2 trigger must be on_gacha_tokens_changed")
	assert(ability_l3.trigger == &"on_gacha_tokens_changed", "L3 trigger must be on_gacha_tokens_changed")
	print("PASS: All Templar abilities have trigger on_gacha_tokens_changed")

	# 2. Setup BattleManager in Scene
	var bm_scene = load("res://scenes/BattleManager.tscn")
	var bm = bm_scene.instantiate()
	bm.is_test_mode = true
	add_child(bm)

	# Set phase to MANAGEMENT
	bm._current_battle_phase = bm.Phases.MANAGEMENT

	# 3. Test Initial Board Entry for Player Templar
	bm._gacha_tokens = 5
	var player_templar = GachaBallInstance.new()
	player_templar.definition_id = &"unit_t2_d"
	player_templar.ball_uuid = "player_templar_1"
	player_templar.level = 1
	player_templar.current_hp = 2
	player_templar.current_pwr = 3
	player_templar.location_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	player_templar.location_slot_index = 0
	bm._battle_instances[player_templar.ball_uuid] = player_templar
	bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).add_instance(player_templar.ball_uuid, 0)

	# Fire on_board_enter
	AbilityResolver.process_trigger(&"on_board_enter", {"entered_uuid": player_templar.ball_uuid})
	var events = bm._combat.process_reaction_queue(bm, {})
	assert(events.size() == 1, "Expected 1 BUFF event on board enter, got %d" % events.size())
	assert(player_templar.current_pwr == 8, "Expected 3 + 5 = 8 PWR, got %d" % player_templar.current_pwr)
	assert(events[0].visual_payload.amount == 5, "Expected visual payload amount 5, got %d" % events[0].visual_payload.amount)
	print("PASS: Player Templar on_board_enter evaluates tokens (3 + 5 = 8 PWR)")

	# 4. Test Dynamic Token Increase
	bm._gacha_tokens = 7
	bm._on_gacha_tokens_changed(7)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(events.size() == 1, "Expected 1 BUFF event on token increase, got %d" % events.size())
	assert(player_templar.current_pwr == 10, "Expected 8 + 2 = 10 PWR, got %d" % player_templar.current_pwr)
	assert(events[0].visual_payload.amount == 2, "Expected delta +2, got %d" % events[0].visual_payload.amount)
	print("PASS: Player Templar scales up on token increase (8 -> 10 PWR, delta +2)")

	# 5. Test Dynamic Token Decrease
	bm._gacha_tokens = 3
	bm._on_gacha_tokens_changed(3)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(events.size() == 1, "Expected 1 BUFF event on token decrease, got %d" % events.size())
	assert(player_templar.current_pwr == 6, "Expected 10 - 4 = 6 PWR, got %d" % player_templar.current_pwr)
	assert(events[0].visual_payload.amount == -4, "Expected delta -4, got %d" % events[0].visual_payload.amount)
	print("PASS: Player Templar scales down on token decrease (10 -> 6 PWR, delta -4)")

	# 6. Test Token Reduction to 0
	bm._gacha_tokens = 0
	bm._on_gacha_tokens_changed(0)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(events.size() == 1, "Expected 1 BUFF event on token drop to 0, got %d" % events.size())
	assert(player_templar.current_pwr == 3, "Expected 6 - 3 = 3 base PWR, got %d" % player_templar.current_pwr)
	assert(events[0].visual_payload.amount == -3, "Expected delta -3, got %d" % events[0].visual_payload.amount)
	print("PASS: Player Templar returns cleanly to exact base stats (3 PWR) when tokens reach 0")

	# 7. Test Outside-Battle Trained Templar (+2 persistent upgrade)
	bm._gacha_tokens = 0
	var trained_templar = GachaBallInstance.new()
	trained_templar.definition_id = &"unit_t2_d"
	trained_templar.ball_uuid = "trained_templar_1"
	trained_templar.level = 1
	# Add outside-battle persistent training component
	trained_templar.add_or_update_stat_component(
		&"permanent_base_upgrade",
		&"PERMANENT_UPGRADE",
		"modify_unit_base_stats",
		0, # hp_delta
		2, # pwr_delta
		false
	)
	var effective_starting_pwr = trained_templar.get_effective_starting_pwr()
	assert(effective_starting_pwr == 5, "Trained Templar base starting PWR must be 5 (3 + 2), got %d" % effective_starting_pwr)
	trained_templar.current_hp = 2
	trained_templar.current_pwr = effective_starting_pwr
	trained_templar.location_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	trained_templar.location_slot_index = 1
	bm._battle_instances[trained_templar.ball_uuid] = trained_templar
	bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).add_instance(trained_templar.ball_uuid, 1)

	# Tokens change to 4
	bm._gacha_tokens = 4
	bm._on_gacha_tokens_changed(4)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(player_templar.current_pwr == 7, "player_templar expected 7 PWR, got %d" % player_templar.current_pwr)
	assert(trained_templar.current_pwr == 9, "trained_templar expected 5 + 4 = 9 PWR, got %d" % trained_templar.current_pwr)
	print("PASS: Trained Templar instance preserves +2 training bonus (5 + 4 = 9 PWR)")

	# Now tokens drop to 0
	bm._gacha_tokens = 0
	bm._on_gacha_tokens_changed(0)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(player_templar.current_pwr == 3, "player_templar must return to 3, got %d" % player_templar.current_pwr)
	assert(trained_templar.current_pwr == 5, "trained_templar must return to trained base 5, got %d" % trained_templar.current_pwr)
	print("PASS: Trained Templar instance returns to 5 PWR on 0 tokens (preserved Dojo training)")

	# 8. Test Enemy Templar Parity
	var enemy_templar = GachaBallInstance.new()
	enemy_templar.definition_id = &"unit_t2_d"
	enemy_templar.ball_uuid = "enemy_templar_1"
	enemy_templar.level = 1
	enemy_templar.current_hp = 2
	enemy_templar.current_pwr = 3
	enemy_templar.location_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	enemy_templar.location_slot_index = 0
	bm._battle_instances[enemy_templar.ball_uuid] = enemy_templar
	bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).add_instance(enemy_templar.ball_uuid, 0)

	# Player gains 6 tokens
	bm._gacha_tokens = 6
	bm._on_gacha_tokens_changed(6)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(enemy_templar.current_pwr == 9, "Enemy Templar must scale with player tokens to 3 + 6 = 9 PWR, got %d" % enemy_templar.current_pwr)
	print("PASS: Enemy Templar scales with player's current tokens (3 + 6 = 9 PWR)")

	# Player spends 5 tokens -> 1 token remains
	bm._gacha_tokens = 1
	bm._on_gacha_tokens_changed(1)
	events = bm._combat.process_reaction_queue(bm, {})
	assert(enemy_templar.current_pwr == 4, "Enemy Templar must drop to 3 + 1 = 4 PWR, got %d" % enemy_templar.current_pwr)
	assert(player_templar.current_pwr == 4, "Player Templar must drop to 3 + 1 = 4 PWR, got %d" % player_templar.current_pwr)
	assert(trained_templar.current_pwr == 6, "Trained Templar must drop to 5 + 1 = 6 PWR, got %d" % trained_templar.current_pwr)
	print("PASS: Enemy and Player Templars scale down identically with player tokens (PWR: 4, 4, 6)")

	# 9. Test Level 2 and Level 3 multipliers
	var templar_l2 = GachaBallInstance.new()
	templar_l2.definition_id = &"unit_t2_d"
	templar_l2.ball_uuid = "templar_l2"
	templar_l2.level = 2
	templar_l2.current_hp = 2
	templar_l2.current_pwr = 3
	templar_l2.location_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	templar_l2.location_slot_index = 2
	bm._battle_instances[templar_l2.ball_uuid] = templar_l2
	bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).add_instance(templar_l2.ball_uuid, 2)

	var templar_l3 = GachaBallInstance.new()
	templar_l3.definition_id = &"unit_t2_d"
	templar_l3.ball_uuid = "templar_l3"
	templar_l3.level = 3
	templar_l3.current_hp = 2
	templar_l3.current_pwr = 3
	templar_l3.location_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	templar_l3.location_slot_index = 3
	bm._battle_instances[templar_l3.ball_uuid] = templar_l3
	bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).add_instance(templar_l3.ball_uuid, 3)

	# Enter board with 4 tokens
	bm._gacha_tokens = 4
	AbilityResolver.process_trigger(&"on_board_enter", {"entered_uuid": templar_l2.ball_uuid})
	AbilityResolver.process_trigger(&"on_board_enter", {"entered_uuid": templar_l3.ball_uuid})
	events = bm._combat.process_reaction_queue(bm, {})

	# L2 with 4 tokens: 3 + floor(4 * 1.5) = 3 + 6 = 9 PWR
	# L3 with 4 tokens: 3 + floor(4 * 2.0) = 3 + 8 = 11 PWR
	assert(templar_l2.current_pwr == 9, "L2 Templar expected 9 PWR, got %d" % templar_l2.current_pwr)
	assert(templar_l3.current_pwr == 11, "L3 Templar expected 11 PWR, got %d" % templar_l3.current_pwr)
	print("PASS: Level 2 (150%) and Level 3 (200%) multipliers work correctly (9 and 11 PWR)")

	print("\n*** ALL TEMPLAR DYNAMIC ABILITY TESTS PASSED SUCCESSFULLY! ***")
	bm.queue_free()
	get_tree().quit(0)

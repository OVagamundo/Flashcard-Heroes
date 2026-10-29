extends Node

func _ready():
	print("--- Running Bug Hunter Script ---")
	GameManager.start_run_with_seed(&"hero_bounty_hunter", &"deck_nihongo_starter")
	
	var bm_script = preload("res://scripts/BattleManager.gd")
	var bm = bm_script.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	
	var encounter_def = EncounterGenerator.generate_encounter(1)
	GameManager.is_in_battle = true
	bm._setup_battle(encounter_def)
	bm.add_gacha_tokens(50)
	print("Initial Battle Consistency Check: ", bm._state.validate_state_consistency())
	
	# Draw everything from tier 1 until bench is full or pool is empty
	print("Drawing all from tier 1...")
	while true:
		var events = bm.bm_draw_gacha_instance(1)
		if events.is_empty():
			break
		if not bm._state.validate_state_consistency():
			print("FAILED AFTER DRAW!")
			get_tree().quit(1)
			return
	
	print("Pool emptied or bench full. Bench count: ", bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH).size())
	print("Discard count: ", bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).size())
	for inst in bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH):
		print("  Bench inst: ", inst.ball_uuid, " def: ", inst.definition_id)
	for inst in bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE):
		print("  Discard inst: ", inst.ball_uuid, " def: ", inst.definition_id)

	
	bm.queue_free()
	get_tree().quit(0)

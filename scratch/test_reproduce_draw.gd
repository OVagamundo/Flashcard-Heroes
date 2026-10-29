extends Node

func _ready():
	print("--- Starting Reproduction Script with hero_bounty_hunter ---")
	
	GameManager.start_run_with_seed(&"hero_bounty_hunter", &"deck_nihongo_starter")
	
	print("RunState instances:")
	for u in GameManager.run_state.get_all_instances().keys():
		var inst = GameManager.run_state.get_all_instances()[u]
		var loc = GameManager.run_state.get_location_for_uuid(u)
		var c = loc.container if loc else "NULL"
		var idx = loc.index if loc else -1
		print("  RunInst: %s (%s) -> %s:%d" % [u, inst.definition_id, c, idx])
	
	var bm_script = preload("res://scripts/BattleManager.gd")
	var bm = bm_script.new()
	add_child(bm)
	bm.add_to_group("battle_manager")
	
	var encounter_def = EncounterGenerator.generate_encounter(5)
	
	print("Setting up battle with generated encounter...")
	bm._setup_battle(encounter_def)
	
	print("Battle instances:")
	for u in bm.get_all_instances().keys():
		var inst = bm.get_all_instances()[u]
		var loc = inst.get_location()
		var c = loc.container if loc else "NULL"
		var idx = loc.index if loc else -1
		print("  BattleInst: %s (%s) -> %s:%d" % [u, inst.definition_id, c, idx])
	
	bm.queue_free()
	get_tree().quit(0)

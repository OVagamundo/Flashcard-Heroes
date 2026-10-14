extends Node

func _ready() -> void:
	ActionQueue.set_headless_mode(true)
	var replay_path = OS.get_environment("HOME") + "/Library/Application Support/Godot/app_userdata/Flashcard Heroes/replays/run_run_1791983073_18_33670.mcr"
	ReplayController.playback_error.connect(func(msg):
		print("\n=== PLAYBACK ERROR ===")
		print(msg)
		print("\n=== CURRENT SNAPSHOT ===")
		var snap = GameManager.get_replay_state_snapshot()
		print(JSON.stringify(snap, "\t"))
		get_tree().quit(1)
	)
	ReplayController.action_executing.connect(func(seq, act_type):
		if seq >= 166:
			print("[Seq %d] %s | phase=%d in_battle=%s" % [
				seq, act_type, 
				GameManager.get_battle_manager().get_current_phase() if GameManager.is_in_battle and GameManager.get_battle_manager() else -1,
				GameManager.is_in_battle
			])
	)
	ReplayController.play_file(replay_path)

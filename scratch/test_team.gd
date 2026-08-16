extends SceneTree

func _init():
	print("Testing _is_valid_count_target logic...")
	
	var containers = ["PlayerLineup", "PlayerBench", "PlayerTrinkets", "BattleInventoryT1", "PlayerDiscardT1"]
	
	for c in containers:
		var is_owned = c in ["PlayerLineup", "PlayerBench", "PlayerTrinkets"]
		print("Container: ", c, " | is_player_owned: ", is_owned)
	
	quit()

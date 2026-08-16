extends SceneTree

func _init():
	print("Testing Twin Charm logic...")
	
	var copy_counts = {"test_unit": 2}
	
	var last_bonus = 0
	var total_copies = int(copy_counts.get("test_unit", 0))
	var bonus_pwr = total_copies / 2
	var delta = bonus_pwr - last_bonus
	
	print("total_copies: ", total_copies)
	print("bonus_pwr: ", bonus_pwr)
	print("last_bonus: ", last_bonus)
	print("delta: ", delta)
	
	quit()

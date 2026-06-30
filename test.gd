extends SceneTree

func _init() -> void:
	var rs = preload("res://scripts/RunState.gd").new()
	rs.initialize_run("hero_timekeeper", "korean_hangul_main")
	print("Deck ID: ", rs.deck_def_id)
	print("Ordered pool size: ", rs.ordered_deck_pool.size())
	rs.check_deck_expansion()
	print("Active deck size: ", rs.active_deck_ids.size())
	if rs.active_deck_ids.size() > 0:
		print("First card: ", rs.active_deck_ids[0])
	quit()

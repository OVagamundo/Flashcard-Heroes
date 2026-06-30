extends SceneTree

func _init() -> void:
	var db = load("res://scripts/Database.gd").new()
	db._load_flashcard_definitions()
	
	var rs = load("res://scripts/RunState.gd").new()
	var err = rs.load_run_data()
	if err != OK:
		print("Failed to load save: ", err)
		quit()
		
	var active = rs.active_deck_ids
	print("Active deck size: ", active.size())
	for c in active:
		if not db.flashcard_definitions.has(c):
			print("MISSING CARD: ", c)
		else:
			pass
	print("Check done.")
	quit()

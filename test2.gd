extends MainLoop

func _process(delta: float) -> bool:
	print("Hello from MainLoop!")
	
	var db_script = load("res://scripts/Database.gd")
	if db_script == null:
		print("Failed to load Database.gd")
		return true
		
	var db = db_script.new()
	db._load_flashcard_definitions()
	print("Flashcards loaded: ", db.flashcard_definitions.size())
	
	var rs_script = load("res://scripts/RunState.gd")
	if rs_script:
		var rs = rs_script.new()
		rs.deck_def_id = "korean_hangul_main"
		rs.ordered_deck_pool = ["KOR_067", "KOR_066", "KOR_065"]
		rs.active_deck_ids = ["KOR_067"]
		print("Has KOR_067? ", db.flashcard_definitions.has("KOR_067"))
	
	return true

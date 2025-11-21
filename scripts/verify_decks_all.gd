extends SceneTree

func _init():
	print("Starting verification...")
	
	var database_script = load("res://scripts/Database.gd")
	var database = database_script.new()
	
	print("Loading flashcard definitions...")
	database._load_flashcard_definitions()
	
	var decks = database.get_all_deck_metadata()
	print("Loaded decks: ", decks.size())
	
	var expected_decks = ["katakana_main", "hiragana_main", "kanji_100"]
	var found_decks = []
	
	for deck in decks:
		print("Deck: ", deck.display_name, " (", deck.deck_id, ")")
		found_decks.append(deck.deck_id)
		var cards = database.get_cards_for_deck(deck.deck_id)
		print("  Card count: ", cards.size())
		if cards.size() > 0:
			print("  First card: ", cards[0])
			var card_def = database.get_flashcard_definition(cards[0])
			# print("  First card data: ", card_def)
			
	var all_found = true
	for expected in expected_decks:
		if not found_decks.has(expected):
			print("MISSING DECK: ", expected)
			all_found = false
			
	if all_found:
		print("VERIFICATION SUCCESS: All expected decks loaded.")
	else:
		print("VERIFICATION FAILED: Missing decks.")
	
	quit()

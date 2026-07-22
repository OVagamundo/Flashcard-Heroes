# res://scripts/debug_korean_deck.gd
extends SceneTree

func _init():
	print("--- STARTING KOREAN HANGUL DECK VERIFICATION ---")
	
	# Load Database
	var db = load("res://scripts/Database.gd").new()
	db._ready()
	
	# Check if deck definition is present
	var deck_id = &"korean_hangul_main"
	if not db.deck_definitions.has(deck_id):
		print("FAILURE: Deck 'korean_hangul_main' not found in database definitions.")
		quit(1)
		return
		
	var deck = db.deck_definitions[deck_id]
	print("SUCCESS: Korean deck found!")
	print("  - Display Name (raw): ", deck.display_name)
	print("  - Description (raw): ", deck.description)
	print("  - Card Count: ", deck.card_ids.size())
	
	# Validate card count
	if deck.card_ids.size() != 103:
		print("FAILURE: Expected 103 cards, but found ", deck.card_ids.size())
		quit(1)
		return
		
	# Verify all cards have definitions and audio files
	var missing_audio = 0
	var missing_defs = 0
	
	for c_id in deck.card_ids:
		var card_data = db.get_flashcard_definition(c_id)
		if card_data.is_empty():
			print("FAILURE: Card definition for ", c_id, " is empty!")
			missing_defs += 1
			continue
			
		# Check audio file existence
		var audio_path = "res://assets/audio/sfx/pronunciation/" + String(c_id) + ".mp3"
		if not FileAccess.file_exists(audio_path):
			print("FAILURE: Audio file for ", c_id, " not found at: ", audio_path)
			missing_audio += 1
			
	if missing_defs > 0 or missing_audio > 0:
		print("VERIFICATION FAILED: ", missing_defs, " missing definitions, ", missing_audio, " missing audio files.")
		quit(1)
		return
		
	print("SUCCESS: All 103 card definitions and audio files are present!")
	
	# Verify Localization keys
	TranslationServer.set_locale("en")
	var en_desc = tr("deck.korean_hangul.desc")
	print("  - English Description: ", en_desc)
	
	TranslationServer.set_locale("pt")
	var pt_desc = tr("deck.korean_hangul.desc")
	print("  - Portuguese Description: ", pt_desc)
	
	if en_desc == "deck.korean_hangul.desc" or pt_desc == "deck.korean_hangul.desc":
		print("FAILURE: Localization key 'deck.korean_hangul.desc' did not translate successfully!")
		quit(1)
		return
		
	print("SUCCESS: Localization translations resolved successfully!")
	print("--- VERIFICATION SUCCEEDED ---")
	quit(0)

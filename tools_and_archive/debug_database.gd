# res://scripts/debug_database.gd
extends SceneTree

func _init():
	# Wait for database autoload to be ready if needed, 
	# but in a script run via --script it might not be.
	# However, we can just load the file and call its load functions.
	var db = load("res://scripts/Database.gd").new()
	db._ready()
	
	print("--- DATABASE UNITS ---")
	for id in db.units.keys():
		print("ID: ", id)
	
	if db.units.has(&"unit_dust_elite_t3"):
		print("SUCCESS: unit_dust_elite_t3 found!")
		var def = db.units[&"unit_dust_elite_t3"]
		print("  - Display Name Key: ", def.display_name_key)
		print("  - Tier: ", def.tier)
		print("  - Abilities count: ", def.ability_definitions.size())
	else:
		print("FAILURE: unit_dust_elite_t3 NOT FOUND in units dictionary.")
		
	quit()

# res://scripts/debug_compile.gd
extends SceneTree

func _init():
	print("--- CHECKING COMPILATION ---")
	var scripts = [
		"res://scripts/Database.gd",
		"res://scripts/EncounterGenerator.gd",
		"res://scripts/battle/BattleSetup.gd",
		"res://scripts/effects/EffectDustEliteSpawn.gd"
	]
	
	for s in scripts:
		print("Checking: ", s)
		var res = load(s)
		if res == null:
			print("  FAILURE: Could not load ", s)
		elif not res.can_instantiate() and res is GDScript:
			# Not always true for static-only scripts, but usually works
			pass
		print("  Result: ", res)
		
	quit()

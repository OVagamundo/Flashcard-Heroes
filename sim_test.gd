extends SceneTree

func _init():
	var db = load("res://scripts/Database.gd").new()
	var gen = load("res://scripts/EncounterGenerator.gd").new()
	
	# Mock Database manually since it's a singleton in game
	gen.Database = db
	
	# Populate DB with some fake data if needed or try to use real data
	# Headless loading of resources might fail if we don't have the folders
	# Let's just mock the pools directly in EncounterGenerator for this test
	
	print("--- Day 1 Elite Simulation (Budget 6) ---")
	_run_sim(gen, 6)
	
	print("\n--- Day 3 Elite Simulation (Budget 14) ---")
	_run_sim(gen, 14)
	
	quit()

func _run_sim(gen, budget):
	# Mocking _create_resource_pools to be predictable
	var unit_t1 = {"id": "unit_t1", "cost": 1, "item_slot_count": 1, "category": "UNIT"}
	var unit_t2 = {"id": "unit_t2", "cost": 2, "item_slot_count": 2, "category": "UNIT"}
	var item_t1 = {"id": "item_t1", "cost": 1, "category": "ITEM"}
	var item_t2 = {"id": "item_t2", "cost": 2, "category": "ITEM"}
	
	var pools = {
		"units": [unit_t1, unit_t2],
		"items": [item_t1, item_t2],
		"trinkets": []
	}
	
	var build = gen._build_encounter_with_full_spend(budget, pools, 4, 5)
	print("Result: Spent %d/%d, Units %d, Items %d" % [build.spent, budget, build.units.size(), build.items.size()])

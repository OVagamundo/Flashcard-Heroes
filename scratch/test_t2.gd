extends SceneTree
func _init():
	Database._ready()
	var tier_2_units = []
	for unit_def in Database.units.values():
		if unit_def.tier == 2 and unit_def.category == &"UNIT" and not unit_def.is_hero:
			tier_2_units.append(unit_def)
	print("Found T2 units: ", tier_2_units.size())
	quit()

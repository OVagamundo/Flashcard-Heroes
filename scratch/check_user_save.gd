extends Node

func _ready():
	print("User dir check:")
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			print("  ", file_name)
			file_name = dir.get_next()
	else:
		print("  Failed to open user://")
	
	if FileAccess.file_exists("user://run_save.dat"):
		var f = FileAccess.open("user://run_save.dat", FileAccess.READ)
		if f:
			var data = f.get_var()
			f.close()
			if data is Dictionary:
				print("Saved run_id:", data.get("run_id"))
				print("Saved day:", data.get("day"))
				print("Saved gold:", data.get("gold"))
				print("Saved containers:", data.get("containers", {}).keys())
				var insts = data.get("instances", {})
				print("Saved instances count:", insts.size())
				for u in insts.keys():
					if "60_64245" in u or "104_14938" in u:
						print("FOUND SAVED INSTANCE:", u, insts[u])
	get_tree().quit(0)

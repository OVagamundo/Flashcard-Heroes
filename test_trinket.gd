extends SceneTree

func _init():
	var def = preload("res://resources/trinkets/trinket_twin_charm.tres")
	print("CATEGORY: ", def.category)
	quit()

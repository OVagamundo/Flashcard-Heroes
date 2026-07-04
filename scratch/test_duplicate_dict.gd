extends SceneTree

func _init():
	var dict = {"arr": [1, 2, 3]}
	var copy = dict.duplicate()
	
	print(copy)
	quit()

extends SceneTree

func _init():
	print("Test started")
	var scene = load("res://scenes/FlashcardMinigame.tscn")
	if not scene:
		print("Failed to load scene")
		quit()
		return
		
	var inst = scene.instantiate()
	root.add_child(inst)
	print("Scene instanced successfully")
	
	await root.get_tree().create_timer(0.5).timeout
	print("Finished")
	quit()

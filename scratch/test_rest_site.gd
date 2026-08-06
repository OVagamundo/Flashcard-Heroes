extends SceneTree

func _init():
	print("Test started")
	var rs_scene = load("res://scenes/RestSite.tscn")
	if not rs_scene:
		print("Failed to load scene")
		quit()
		return
		
	var rs = rs_scene.instantiate()
	root.add_child(rs)
	print("Scene instanced")
	
	# Try to press the button
	var study_btn = rs.get_node("%StudyButton")
	if not study_btn:
		print("Button not found")
		quit()
		return
		
	print("Button found, emitting pressed")
	study_btn.pressed.emit()
	print("Pressed emitted")
	
	# Give it a frame to process
	await root.get_tree().create_timer(0.5).timeout
	print("Finished")
	quit()

extends SceneTree

func _init():
	var scene = load("res://scenes/Main.tscn").instantiate()
	var layer = scene.get_node_or_null("PostProcessLayer")
	print("PostProcessLayer exists: ", layer != null)
	var rect = scene.get_node_or_null("PostProcessLayer/ColorGlowRect")
	print("ColorGlowRect exists: ", rect != null)
	if rect:
		print("Rect visible: ", rect.visible)
		print("Rect size: ", rect.size)
		if rect.size == Vector2.ZERO:
			print("WARNING: Rect size is ZERO!")
		var mat = rect.material
		print("Material exists: ", mat != null)
		if mat is ShaderMaterial:
			print("Mat is ShaderMaterial")
			if mat.shader:
				print("Shader is valid")
			else:
				print("Shader is null!")
		else:
			print("Material is not ShaderMaterial")
	quit()

@tool
extends SceneTree

func _init():
	var tex = load("res://assets/Realistic/ui/textures/UI Atlas plastic theme.png")
	if tex:
		print("IMAGE_SIZE:", tex.get_width(), "x", tex.get_height())
	else:
		print("FAILED_TO_LOAD")
	quit()

extends SceneTree
func _init():
	var a = [{'foo': 1}] if true else Array()
	var b = [{'foo': 1}] if true else Array()
	print('is same? ', a == b)
	quit()


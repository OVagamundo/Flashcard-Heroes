extends SceneTree

class TestResource extends Resource:
	var my_dict: Dictionary = {}

	func _init(p_context: Dictionary = {}):
		self.my_dict = p_context.get("my_dict", {})

func _init():
	var orig = TestResource.new({"my_dict": {"a": 1}})
	var copy = orig.duplicate(true)
	
	print("Orig Dict: ", orig.my_dict)
	print("Copy Dict: ", copy.my_dict)
	quit()

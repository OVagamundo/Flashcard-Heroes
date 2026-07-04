extends SceneTree

class TestResource extends Resource:
	var my_array: Array = [1, 2, 3]
	var my_dict: Dictionary = {"a": 1}
	var my_string: String = "hello"

func _init():
	var orig = TestResource.new()
	var copy = orig.duplicate(true)
	
	print("Array: ", copy.my_array)
	print("Dict: ", copy.my_dict)
	print("String: ", copy.my_string)
	quit()

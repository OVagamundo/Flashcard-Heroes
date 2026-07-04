extends SceneTree
class_name TestApp

func _init():
	var CombatEvent = load("res://scripts/CombatEvent.gd")
	var event = CombatEvent.new(0, {})
	var arr: Array = [event]
	
	var payload: Dictionary = { "events": arr }
	
	var raw = payload.get("events", [])
	
	print("raw type: ", typeof(raw))
	print("raw[0] type: ", typeof(raw[0]))
	print("is CombatEvent: ", raw[0] is Object and raw[0].get_class() == "RefCounted")
	
	var typed_arr = []
	for e in raw:
		typed_arr.append(e)
		
	if raw[0] != null:
		print("SUCCESS")
	else:
		print("FAILED")
		
	quit()

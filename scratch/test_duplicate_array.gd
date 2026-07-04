extends SceneTree

func _init():
	var CombatEvent = load("res://scripts/CombatEvent.gd")
	var event = CombatEvent.new(0, {})
	var arr: Array[Resource] = [event]
	
	var payload: Dictionary = { "events": arr }
	var parent_event = CombatEvent.new(0, payload)
	
	var copy = parent_event.duplicate(true)
	var raw = copy.visual_payload.get("events", [])
	
	print("raw type: ", typeof(raw))
	
	var typed_arr: Array[Resource] = []
	for e in raw:
		typed_arr.append(e as Resource)
		
	if raw[0] != null and typed_arr[0] != null:
		print("SUCCESS")
	else:
		print("FAILED")
		
	quit()

extends SceneTree

func _init():
	var CombatEvent = load("res://scripts/CombatEvent.gd")
	var event = CombatEvent.new(0, {})
	var payload: Dictionary = { "events": [event] }
	
	var raw = payload.get("events", [])
	
	for e in raw:
		var casted = e as Object
		var casted2 = e as RefCounted
		# We can't cast to a dynamically loaded script easily with 'as', 
		# but in the actual game, CombatEvent is a global class_name.
		print("casted Object: ", casted != null)
		print("casted RefCounted: ", casted2 != null)
		
	quit()

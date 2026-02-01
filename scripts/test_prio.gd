extends SceneTree

func _init():
	var sim = load("res://scripts/battle/CombatSimulator.gd").new()
	var req_high = load("res://scripts/EffectRequest.gd").new("src", "high", null, [], {}, 0)
	var req_low = load("res://scripts/EffectRequest.gd").new("src", "low", null, [], {}, -50)
	
	sim.enqueue_reaction(req_high)
	sim.enqueue_reaction(req_low)
	
	print("Pending reactions: ", sim._pending_reactions.size())
	
	# Manually sort (simulating execution loop)
	sim._pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
	
	var first = sim._pending_reactions[0]
	var second = sim._pending_reactions[1]
	
	print("First (High 0): ", first.ability_id, " Prio: ", first.priority)
	print("Second (Low -50): ", second.ability_id, " Prio: ", second.priority)
	
	quit()

extends SceneTree

func _init():
	print("Running debug script...")
	# I will just write a small test to see what CombatPayload.pwr_change outputs
	var payload = CombatPayload.pwr_change("source", 1, [], [2])
	print("Payload amount: ", payload.amount)
	print("Payload stat: ", payload.stat)
	print("Payload old_pwrs: ", payload.targets_old_pwr)
	print("Payload new_pwrs: ", payload.targets_new_pwr)
	
	var pwr_delta = 0
	var stat = payload.stat
	if not payload.targets_new_pwr.is_empty() and not payload.targets_old_pwr.is_empty():
		pwr_delta = payload.targets_new_pwr[0] - payload.targets_old_pwr[0]
	elif payload.pwr_amount != 0:
		pwr_delta = payload.pwr_amount
	elif stat == "pwr":
		pwr_delta = payload.amount
	
	print("Calculated pwr_delta: ", pwr_delta)
	
	quit()

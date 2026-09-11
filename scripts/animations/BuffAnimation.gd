class_name BuffAnimation
extends BattleAnimation

## BuffAnimation handles core stat buffs: HP and PWR only.
## Status effects (burn_stacks, armor_stacks) are handled by StatusEffectAnimation.

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: CombatPayload) -> void:
	var source_uuid = payload.source_uuid
	var amount = payload.amount
	var stat = payload.stat if not payload.stat.is_empty() else "pwr"
	
	if payload.skip_bump:
		# Silent immediate update without projectiles or animations
		var pwr_values = payload.targets_new_pwr
		var hp_values = payload.targets_new_hp
		for i in range(targets.size()):
			var target_uuid = targets[i]
			if stat == "hp":
				var new_hp = int(hp_values[i]) if not hp_values.is_empty() and i < hp_values.size() else payload.new_hp
				animator.apply_hp_delta(target_uuid, amount, new_hp)
			elif stat == "pwr":
				var new_pwr = int(pwr_values[i]) if not pwr_values.is_empty() and i < pwr_values.size() else payload.new_pwr
				animator.apply_pwr_delta(target_uuid, amount, new_pwr)
		return
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Extract exact deltas
	var hp_delta = 0
	if not payload.targets_new_hp.is_empty() and not payload.targets_old_hp.is_empty():
		hp_delta = payload.targets_new_hp[0] - payload.targets_old_hp[0]
	elif payload.hp_amount != 0:
		hp_delta = payload.hp_amount
	elif stat == "hp":
		hp_delta = payload.amount
		
	var pwr_delta = 0
	if not payload.targets_new_pwr.is_empty() and not payload.targets_old_pwr.is_empty():
		pwr_delta = payload.targets_new_pwr[0] - payload.targets_old_pwr[0]
	elif payload.pwr_amount != 0:
		pwr_delta = payload.pwr_amount
	elif stat == "pwr":
		pwr_delta = payload.amount

	var has_hp_buff = hp_delta > 0
	var has_pwr_buff = pwr_delta > 0
	var has_hp_debuff = hp_delta < 0
	var has_pwr_debuff = pwr_delta < 0
	
	# 1. Launch Projectiles ONLY for BUFFS
	var projectiles = []
	if has_hp_buff:
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, hp_delta, "hp", "green")
			if proj: projectiles.append(proj)
			
	if has_hp_buff and has_pwr_buff:
		await animator.get_tree().create_timer(0.15).timeout
			
	if has_pwr_buff:
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, pwr_delta, "pwr", "blue")
			if proj: projectiles.append(proj)
			
	# Determine combined flash and deform for the whole event
	var is_pure_debuff = (has_hp_debuff or has_pwr_debuff) and not (has_hp_buff or has_pwr_buff)
	
	# Wait for impact of all projectiles (skip delay for pure debuffs)
	if projectiles.is_empty():
		if not is_pure_debuff:
			await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout
	else:
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
				
	# 2. Apply Stat Buffs/Debuffs (HP and/or PWR)
	var final_target_uuid = ""
	var pwr_values = payload.targets_new_pwr
	var hp_values = payload.targets_new_hp
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		final_target_uuid = target_uuid
		
		# Apply HP
		if not hp_values.is_empty() and i < hp_values.size():
			var new_hp = int(hp_values[i])
			animator.apply_hp_delta(target_uuid, hp_delta, new_hp)
		elif stat == "hp" or stat == "hp_and_pwr":
			animator.apply_hp_delta(target_uuid, hp_delta, payload.new_hp)
			
		# Apply PWR
		if not pwr_values.is_empty() and i < pwr_values.size():
			var new_pwr = int(pwr_values[i])
			animator.apply_pwr_delta(target_uuid, pwr_delta, new_pwr)
		elif stat == "pwr" or stat == "hp_and_pwr":
			animator.apply_pwr_delta(target_uuid, pwr_delta, payload.new_pwr)
			
		# Visual Reactions are now handled directly by GachaBallView.animate_stat_change
		# This ensures that ALL stat changes (even those that bypass the VCR) trigger 
		# the correct hops, flashes, and floating debuff texts uniformly.
				
	# Wait for animation completion
	if final_target_uuid != "":
		# Always wait for at least a standard flash duration so the sequence doesn't blow past it
		await animator.wait_for_animation_completion("flash", final_target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat)


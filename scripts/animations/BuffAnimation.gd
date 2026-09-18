class_name BuffAnimation
extends BattleAnimation

## BuffAnimation handles core stat buffs: HP and PWR only.
## Status effects (burn_stacks, armor_stacks) are handled by StatusEffectAnimation.

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: CombatPayload) -> void:
	var source_uuid = payload.source_uuid
	var amount = payload.amount
	var stat = payload.stat if not payload.stat.is_empty() else "pwr"
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Extract exact deltas
	var hp_delta = 0
	if not payload.targets_new_hp.is_empty() and not payload.targets_old_hp.is_empty():
		hp_delta = payload.targets_new_hp[0] - payload.targets_old_hp[0]
	elif payload.hp_amount != 0:
		hp_delta = payload.hp_amount
	elif stat == "hp" or stat == "both" or stat == "hp_and_pwr":
		hp_delta = payload.amount
		
	var pwr_delta = 0
	if not payload.targets_new_pwr.is_empty() and not payload.targets_old_pwr.is_empty():
		pwr_delta = payload.targets_new_pwr[0] - payload.targets_old_pwr[0]
	elif payload.pwr_amount != 0:
		pwr_delta = payload.pwr_amount
	elif stat == "pwr" or stat == "both" or stat == "hp_and_pwr":
		pwr_delta = payload.amount

	var has_hp_buff = hp_delta > 0
	var has_pwr_buff = pwr_delta > 0
	var has_hp_debuff = hp_delta < 0
	var has_pwr_debuff = pwr_delta < 0
	
	# 1. Launch Projectiles ONLY for BUFFS
	var hp_projectiles = []
	var pwr_projectiles = []
	
	if has_hp_buff:
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, hp_delta, "hp", "green")
			if proj: hp_projectiles.append(proj)
			
	if has_hp_buff and has_pwr_buff:
		await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.15)).timeout
			
	if has_pwr_buff:
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, pwr_delta, "pwr", "blue")
			if proj: pwr_projectiles.append(proj)
			
	# Determine combined flash and deform for the whole event
	var is_pure_debuff = (has_hp_debuff or has_pwr_debuff) and not (has_hp_buff or has_pwr_buff)
	
	var pwr_values = payload.targets_new_pwr
	var hp_values = payload.targets_new_hp
	var final_target_uuid = ""
	if not targets.is_empty():
		final_target_uuid = targets[targets.size() - 1]
	
	# Wait for impact of all projectiles (skip delay for pure debuffs)
	if hp_projectiles.is_empty() and pwr_projectiles.is_empty():
		if not is_pure_debuff:
			await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout
	else:
		# Await HP projectiles and apply HP deltas immediately upon impact
		if not hp_projectiles.is_empty():
			for proj in hp_projectiles:
				if is_instance_valid(proj):
					await proj.impact
			for i in range(targets.size()):
				var target_uuid = targets[i]
				var target_hp_delta = payload.targets_new_hp[i] - payload.targets_old_hp[i] if (i < payload.targets_new_hp.size() and i < payload.targets_old_hp.size()) else hp_delta
				if not hp_values.is_empty() and i < hp_values.size():
					var new_hp = int(hp_values[i])
					animator.apply_hp_delta(target_uuid, target_hp_delta, new_hp)
				elif stat == "hp" or stat == "hp_and_pwr" or stat == "both":
					animator.apply_hp_delta(target_uuid, target_hp_delta, payload.new_hp)
					
		# Await PWR projectiles and apply PWR deltas immediately upon impact
		if not pwr_projectiles.is_empty():
			for proj in pwr_projectiles:
				if is_instance_valid(proj):
					await proj.impact
			for i in range(targets.size()):
				var target_uuid = targets[i]
				var target_pwr_delta = payload.targets_new_pwr[i] - payload.targets_old_pwr[i] if (i < payload.targets_new_pwr.size() and i < payload.targets_old_pwr.size()) else pwr_delta
				if not pwr_values.is_empty() and i < pwr_values.size():
					var new_pwr = int(pwr_values[i])
					animator.apply_pwr_delta(target_uuid, target_pwr_delta, new_pwr)
				elif stat == "pwr" or stat == "hp_and_pwr" or stat == "both":
					animator.apply_pwr_delta(target_uuid, target_pwr_delta, payload.new_pwr)
				
	# 2. Apply Stat Debuffs (negative stat deltas)
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# Apply HP debuff
		var target_hp_delta = payload.targets_new_hp[i] - payload.targets_old_hp[i] if (i < payload.targets_new_hp.size() and i < payload.targets_old_hp.size()) else hp_delta
		if target_hp_delta < 0:
			_spawn_floating_stat_debuff(animator, target_uuid, abs(target_hp_delta), "hp")
			if not hp_values.is_empty() and i < hp_values.size():
				var new_hp = int(hp_values[i])
				animator.apply_hp_delta(target_uuid, target_hp_delta, new_hp)
			elif stat == "hp" or stat == "hp_and_pwr" or stat == "both":
				animator.apply_hp_delta(target_uuid, target_hp_delta, payload.new_hp)
			
		# Apply PWR debuff
		var target_pwr_delta = payload.targets_new_pwr[i] - payload.targets_old_pwr[i] if (i < payload.targets_new_pwr.size() and i < payload.targets_old_pwr.size()) else pwr_delta
		if target_pwr_delta < 0:
			_spawn_floating_stat_debuff(animator, target_uuid, abs(target_pwr_delta), "pwr")
			if not pwr_values.is_empty() and i < pwr_values.size():
				var new_pwr = int(pwr_values[i])
				animator.apply_pwr_delta(target_uuid, target_pwr_delta, new_pwr)
			elif stat == "pwr" or stat == "hp_and_pwr" or stat == "both":
				animator.apply_pwr_delta(target_uuid, target_pwr_delta, payload.new_pwr)
				
	# Wait for animation completion
	if final_target_uuid != "":
		if has_hp_buff or has_pwr_buff:
			await animator.wait_for_animation_completion("move", final_target_uuid)
		else:
			await animator.wait_for_animation_completion("color_flash", final_target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat)

func _spawn_floating_stat_debuff(animator: Node, target_uuid: String, amount: int, type: String) -> void:
	if not VFXFactory.has_method("spawn_stat_number_on_layer"):
		return
	var target_view = animator._visual_registry.get(target_uuid)
	if not is_instance_valid(target_view):
		return
	var offset_y = 0.3 if type == "pwr" else 0.2
	var spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, offset_y))
	var color = Color(1.0, 0.0, 0.0) if type == "hp" else Color(0.0, 0.0, 0.0)
	VFXFactory.spawn_stat_number_on_layer(-amount, spawn_pos, color)


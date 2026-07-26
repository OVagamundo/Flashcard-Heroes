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
	
	# 1. Launch Projectiles (Simultaneous multi-stat launching)
	var projectiles = []
	var has_hp = not payload.targets_new_hp.is_empty() or stat == "hp"
	var has_pwr = not payload.targets_new_pwr.is_empty() or stat == "pwr"
	
	if has_hp:
		for target_uuid in targets:
			var hp_amount = payload.amount
			var proj = _launch_projectile(animator, source_uuid, target_uuid, hp_amount, "hp", "green")
			if proj: projectiles.append(proj)
			
	if has_pwr:
		for target_uuid in targets:
			var pwr_amount = payload.amount
			var proj = _launch_projectile(animator, source_uuid, target_uuid, pwr_amount, "pwr", "blue")
			if proj: projectiles.append(proj)
		
	# Wait for impact of all projectiles simultaneously
	if projectiles.is_empty():
		await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout
	else:
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
				
	# 2. Apply Stat Buffs (HP and/or PWR)
	var final_target_uuid = ""
	var pwr_values = payload.targets_new_pwr
	var hp_values = payload.targets_new_hp
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		final_target_uuid = target_uuid
		
		# Apply HP if present
		if not hp_values.is_empty() and i < hp_values.size():
			var new_hp = int(hp_values[i])
			animator.apply_hp_delta(target_uuid, amount, new_hp)
			var flash_color = Color.RED if amount < 0 else AnimationConstants.COLOR_HEAL_BUFF
			var deform_type = &"HIT_IMPACT" if amount < 0 else &"HOP_DEFORM"
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, deform_type)
			if SignalBus.has_signal("unit_move") and amount >= 0:
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		elif stat == "hp":
			animator.apply_hp_delta(target_uuid, amount, payload.new_hp)
			var flash_color = Color.RED if amount < 0 else AnimationConstants.COLOR_HEAL_BUFF
			var deform_type = &"HIT_IMPACT" if amount < 0 else &"HOP_DEFORM"
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, deform_type)
			if SignalBus.has_signal("unit_move") and amount >= 0:
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		
		# Apply PWR if present
		if not pwr_values.is_empty() and i < pwr_values.size():
			var new_pwr = int(pwr_values[i])
			if amount < 0:
				_spawn_floating_pwr_damage(animator, target_uuid, abs(amount))
			animator.apply_pwr_delta(target_uuid, amount, new_pwr)
			var flash_color = Color.RED if amount < 0 else AnimationConstants.COLOR_HEAL_BUFF
			var deform_type = &"HIT_IMPACT" if amount < 0 else &"HOP_DEFORM"
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, deform_type)
			if SignalBus.has_signal("unit_move") and amount >= 0:
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		elif stat == "pwr":
			if amount < 0:
				_spawn_floating_pwr_damage(animator, target_uuid, abs(amount))
			animator.apply_pwr_delta(target_uuid, amount, payload.new_pwr)
			var flash_color = Color.RED if amount < 0 else AnimationConstants.COLOR_HEAL_BUFF
			var deform_type = &"HIT_IMPACT" if amount < 0 else &"HOP_DEFORM"
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, deform_type)
			if SignalBus.has_signal("unit_move") and amount >= 0:
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)

	# Wait for hop animation completion
	if final_target_uuid != "" and amount >= 0:
		await animator.wait_for_animation_completion("move", final_target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat)

## Helper to spawn floating PWR damage number (Black)
func _spawn_floating_pwr_damage(animator: Node, target_uuid: String, amount: int) -> void:
	var target_view = animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
		found_pos = true
	else:
		var tgt_snap = animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y + tgt_snap.size.y * 0.3)
			found_pos = true
			
	if found_pos:
		# Use status effect style for PWR loss (size 32, black)
		var color = Color(0.0, 0.0, 0.0) # Pure Black
		VFXFactory.spawn_stat_number_on_layer(amount, spawn_pos, color)

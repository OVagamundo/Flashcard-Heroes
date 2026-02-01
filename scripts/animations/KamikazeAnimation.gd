class_name KamikazeAnimation
extends BattleAnimation

## Kamikaze Attack Animation for Death's Bargain item
## Flow: Dying unit lunges to target → applies damage → dies at target position (no return)

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	if source_uuid.is_empty() or targets.is_empty():
		return
	
	var target_uuid = targets[0]
	
	# Get position snapshots for lunge calculation
	var src_snap = animator.get_snapshot_position(source_uuid)
	var tgt_snap = animator.get_snapshot_position(target_uuid)
	
	if src_snap.is_empty() or tgt_snap.is_empty():
		# Fallback: Still play death at source's current position if we have a view
		var source_view = animator._visual_registry.get(source_uuid)
		if is_instance_valid(source_view):
			if SignalBus.has_signal("unit_death_fade"):
				SignalBus.emit_signal("unit_death_fade", source_uuid)
				await animator.wait_for_animation_completion("death_fade", source_uuid)
			if animator._visual_registry.has(source_uuid):
				animator._visual_registry.erase(source_uuid)
		return
	
	# Calculate lunge target position (same logic as DamageAnimation melee)
	var src_width = src_snap.size.x
	var is_attacking_right = src_snap.position.x < tgt_snap.position.x
	var target_position = Vector2.ZERO
	var head_y = tgt_snap.position.y
	var gap := -10.0 # Overlap slightly
	
	if is_attacking_right:
		target_position = Vector2(tgt_snap.position.x - src_width - gap, head_y)
	else:
		target_position = Vector2(tgt_snap.position.x + tgt_snap.size.x + gap, head_y)
	
	# 1. LUNGE TO TARGET
	if target_position != Vector2.ZERO:
		Audio.play_sfx("unit_toss")
		SignalBus.emit_signal("unit_melee_lunge", source_uuid, target_position)
		await animator.wait_for_animation_completion("melee_lunge", source_uuid)
	
	# 2. IMPACT - Apply damage at moment of contact
	await _apply_kamikaze_damage(animator, target_uuid, amount, payload)
	
	# 3. DEATH AT TARGET - No return, die where we are
	if SignalBus.has_signal("unit_death_fade"):
		SignalBus.emit_signal("unit_death_fade", source_uuid)
		await animator.wait_for_animation_completion("death_fade", source_uuid)
	
	# Cleanup from registry
	if animator._visual_registry.has(source_uuid):
		animator._visual_registry.erase(source_uuid)

func _apply_kamikaze_damage(animator: Node, target_uuid: String, amount: int, payload: Dictionary) -> void:
	var targets_new_hp = payload.get("targets_new_hp", [])
	var _targets_old_hp = payload.get("targets_old_hp", [])
	var armor_consumed_list = payload.get("armor_consumed", [])
	var targets_new_armor = payload.get("targets_new_armor", [])
	var spikes_data_list = payload.get("spikes_data_list", [])
	
	var new_hp = targets_new_hp[0] if not targets_new_hp.is_empty() else 0
	var armor_consumed = armor_consumed_list[0] if not armor_consumed_list.is_empty() else 0
	var new_armor = targets_new_armor[0] if not targets_new_armor.is_empty() else 0
	
	# Screen shake
	var shake_intensity = minf(float(abs(amount)) / 5.0, 1.0)
	if shake_intensity > 0.0:
		SignalBus.screen_shake_requested.emit(shake_intensity)
	
	# Audio
	Audio.play_sfx("combat_hit")
	
	# Get target view for damage number positioning
	var target_view = animator._visual_registry.get(target_uuid)
	
	# ARMOR EFFECTS FIRST (before HP)
	if armor_consumed > 0:
		if is_instance_valid(target_view) and target_view.is_inside_tree():
			var spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
			VFXFactory.spawn_damage_number_on_layer(armor_consumed, spawn_pos, true) # true = armor (grey)
		animator.apply_armor_delta(target_uuid, armor_consumed, new_armor)
		await animator.get_tree().create_timer(0.5).timeout
	
	# HP DAMAGE (if any after armor)
	var hp_damage = abs(amount) - armor_consumed
	if hp_damage > 0:
		if is_instance_valid(target_view) and target_view.is_inside_tree():
			var spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
			VFXFactory.spawn_damage_number_on_layer(hp_damage, spawn_pos, false) # red
		animator.apply_hp_delta(target_uuid, -hp_damage, new_hp)
	
	# Visual effects
	if SignalBus.has_signal("unit_color_flash"):
		SignalBus.emit_signal("unit_color_flash", target_uuid, Color.WHITE, AnimationConstants.FLASH_FADE_DURATION)
	if SignalBus.has_signal("unit_deform"):
		SignalBus.emit_signal("unit_deform", target_uuid, &"HIT_IMPACT")
	
	# Determine recoil direction
	var recoil_direction = Vector2.LEFT
	if is_instance_valid(target_view) and target_view is GachaBallView:
		if target_view.icon_rect and target_view.icon_rect.flip_h:
			recoil_direction = Vector2.RIGHT
	
	if SignalBus.has_signal("unit_move"):
		SignalBus.emit_signal("unit_move", target_uuid, &"RECOIL", recoil_direction)
	
	# SPIKES: When target has Spikes, decay stacks (attacker is dead so no damage shown)
	for spikes_data in spikes_data_list:
		var defender_uuid = String(spikes_data.get("defender_uuid", ""))
		var new_spikes = int(spikes_data.get("new_spikes", 0))
		
		# Update defender's Spikes stacks (attacker is dead, no HP update for them)
		if not defender_uuid.is_empty():
			animator.apply_spikes_stack(defender_uuid, new_spikes)
	
	await animator.wait_for_animation_completion("move", target_uuid)

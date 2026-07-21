class_name DamageAnimation
extends BattleAnimation

# NOTE: VFX scene preloads moved to VFXFactory autoload
# NOTE: Animation timing constants are in AnimationConstants.gd

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var skip_bump = bool(payload.get("skip_bump", false))
	var apply_burn = bool(payload.get("apply_burn", false))
	var is_burn_damage = bool(payload.get("is_burn_damage", false))
	var attack_type = String(payload.get("attack_type", "melee")) # Default to melee
	var main_target_uuid = String(payload.get("main_target_uuid", "")) # For multi-target attacks
	
	var _raw_wind = payload.get("windup_events", [])
	var windup_events: Array[CombatEvent] = []
	for e in _raw_wind: windup_events.append(e as CombatEvent)
	var _raw_pre = payload.get("pre_impact_events", [])
	var pre_impact_events: Array[CombatEvent] = []
	for e in _raw_pre: pre_impact_events.append(e as CombatEvent)
	var _raw_imp = payload.get("impact_events", [])
	var impact_events: Array[CombatEvent] = []
	for e in _raw_imp: impact_events.append(e as CombatEvent)
	
	# Ensure this is always a coroutine (GDScript quirk)
	await animator.get_tree().process_frame
	
	if OS.is_debug_build():
		pass
		# print("[DamageAnimation] Executing for targets: ", targets, " source: ", source_uuid, " attack_type: ", attack_type)
	
	# Get visual registry - ONLY used for view updates, NOT position lookups
	# Position data comes from animator.get_snapshot_position() for decoupling
	
	# Determine main target (first target if not specified)
	# GUARDIAN SENTINEL FIX: When Guardian intercepts, use original target position for melee lunge
	# This way the attacker still lunges to where the original target was, and Guardian leaps there
	var original_target_uuids = payload.get("original_target_uuids", [])
	var original_target_uuid = payload.get("original_target_uuid", "") # Single target (cascade damage)
	
	if main_target_uuid.is_empty():
		# Priority: original_target_uuids > original_target_uuid > targets[0]
		if not original_target_uuids.is_empty():
			main_target_uuid = String(original_target_uuids[0])
		elif not original_target_uuid.is_empty():
			main_target_uuid = String(original_target_uuid)
		elif not targets.is_empty():
			main_target_uuid = targets[0]
	
	# ------------------------------------------------------------------
	# MELEE ATTACK ANIMATION
	# ------------------------------------------------------------------
	if attack_type == "melee" and not source_uuid.is_empty() and not skip_bump:
		# DECOUPLING FIX: Use position snapshots instead of querying views
		var target_position = Vector2.ZERO
		var is_attacking_right = true # Default: player attacks right
		var src_width := 64.0 # Default width if not found
		
		# Get source position from snapshot (captured at animation start)
		var src_snap = animator.get_snapshot_position(source_uuid)
		var tgt_snap = animator.get_snapshot_position(main_target_uuid)
		
		if not src_snap.is_empty() and not tgt_snap.is_empty():
			src_width = src_snap.size.x
			# Determine attack direction from snapshotted positions
			is_attacking_right = src_snap.position.x < tgt_snap.position.x
			
			# Calculate target position from snapshot
			var head_y = tgt_snap.position.y # Top of sprite (head area)
			var gap := -10.0 # Negative gap to overlap/touch target
			
			if is_attacking_right:
				# Attacker coming from left: stop at target's left edge
				target_position = Vector2(tgt_snap.position.x - src_width - gap, head_y)
			else:
				# Attacker coming from right: stop at target's right edge
				target_position = Vector2(tgt_snap.position.x + tgt_snap.size.x + gap, head_y)
		
		# KEYFRAME 1: WIND-UP
		# Execute windup events before lunge
		if not windup_events.is_empty():
			await animator._animate_events(windup_events)
		if not pre_impact_events.is_empty():
			await animator._animate_events(pre_impact_events)
		
		# 1. Melee Lunge - attacker jumps to target
		if target_position != Vector2.ZERO:
			# AUDIO HOOK: Attack lunge whoosh (before movement starts)
			if OS.is_debug_build():
				pass
				# print("[DamageAnimation] Playing LUNGE sound: unit_toss")
			Audio.play_sfx("unit_toss")
			SignalBus.emit_signal("unit_melee_lunge", source_uuid, target_position)
			await animator.wait_for_animation_completion("melee_lunge", source_uuid)
		
		# 2. IMPACT! - Apply damage effects NOW (while attacker is at target)
		# This makes the hit feel impactful - recoil/flash happens at moment of contact
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)
		
		# 3. Return - attacker jumps back to original position
		SignalBus.emit_signal("unit_melee_return", source_uuid)
		await animator.wait_for_animation_completion("melee_return", source_uuid)
	
	# ------------------------------------------------------------------
	# TRINKET ACTIVATION AND PROJECTILE ANIMATION
	# ------------------------------------------------------------------
	elif attack_type == "trinket":
		# KEYFRAME 1: WIND-UP
		if not windup_events.is_empty():
			await animator._animate_events(windup_events)
		if not pre_impact_events.is_empty():
			await animator._animate_events(pre_impact_events)
			
		# 1. Activate the trinket view (play hop/bounce animation)
		if animator.has_method("play_trinket_activation"):
			animator.play_trinket_activation(source_uuid)
			
		# 2. Launch projectile from trinket position to target(s)
		var p_stat = String(payload.get("stat", "hp"))
		var p_amount = amount
		var projectiles = []
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(p_amount), p_stat, "red")
			if proj: projectiles.append(proj)
			
		# Wait for projectile impact
		if projectiles.is_empty():
			await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.6)).timeout
		else:
			for proj in projectiles:
				if is_instance_valid(proj):
					await proj.impact
		
		# 3. Apply damage impact (recoil, flashes, numbers)
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)
	
	# ------------------------------------------------------------------
	# RANGED ATTACK ANIMATION (Future - uses projectiles)
	# ------------------------------------------------------------------
	elif attack_type == "ranged":
		# KEYFRAME 1: WIND-UP
		if not windup_events.is_empty():
			await animator._animate_events(windup_events)
		if not pre_impact_events.is_empty():
			await animator._animate_events(pre_impact_events)
			
		# Trigger Bump (if applicable)
		var should_bump = (not skip_bump) and (not source_uuid.is_empty())
		if should_bump:
			var bump_dir = payload.get("bump_direction", Vector2.ZERO)
			if bump_dir != Vector2.ZERO:
				SignalBus.emit_signal("unit_bump_attack", source_uuid, bump_dir)
		
		# Launch Projectile (Parallel)
		var proj_data = payload.get("projectile_data", {})
		var projectiles = []
		if not proj_data.is_empty():
			var p_stat = String(proj_data.get("stat", "hp"))
			var p_amount = int(proj_data.get("amount", 0))
			var p_color = String(proj_data.get("color", "red"))
			
			for target_uuid in targets:
				var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(p_amount), p_stat, p_color)
				if proj: projectiles.append(proj)
		
		# Wait for Bump Impact OR Projectile Impact
		if should_bump:
			await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(AnimationConstants.BUMP_TOTAL_DURATION)).timeout
		elif not projectiles.is_empty():
			for proj in projectiles:
				if is_instance_valid(proj):
					await proj.impact
		
		# Apply Damage
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)
		
		# Wait for bump to fully return
		if should_bump:
			await animator.wait_for_animation_completion("bump", source_uuid)
	
	# ------------------------------------------------------------------
	# NO SOURCE (Burn damage, environmental) - just flash
	# ------------------------------------------------------------------
	else:
		# KEYFRAME 1: WIND-UP
		if not windup_events.is_empty():
			await animator._animate_events(windup_events)
		if not pre_impact_events.is_empty():
			await animator._animate_events(pre_impact_events)
			
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)

	# KEYFRAME 3: POST-RETURN (Impact Callback)
	# Execute on_hurt and on_kill events AFTER the primary attack sequence completes
	if not impact_events.is_empty():
		await animator._animate_events(impact_events)

func _apply_damage_effects(animator: Node, targets: Array[String], payload: Dictionary, apply_burn: bool, is_burn_damage: bool, amount: int) -> void:
	var targets_new_hp = payload.get("targets_new_hp", [])
	var targets_new_burn = payload.get("targets_new_burn", [])
	var armor_consumed_list = payload.get("armor_consumed", [])
	var targets_new_armor = payload.get("targets_new_armor", [])
	var targets_new_pwr = payload.get("targets_new_pwr", []) # Support for PWR damage
	var stat = String(payload.get("stat", "hp")) # Identify stat type
	var spikes_data_list = payload.get("spikes_data_list", []) # Spikes reflection data
	
	# Trigger screen shake based on total damage dealt
	# Intensity scales from 0.0 to 1.0, where 5+ damage = max shake
	var shake_intensity = minf(float(abs(amount)) / 5.0, 1.0)
	if shake_intensity > 0.0:
		SignalBus.screen_shake_requested.emit(shake_intensity)
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		var armor_consumed = armor_consumed_list[i] if i < armor_consumed_list.size() else 0
		var new_armor = targets_new_armor[i] if i < targets_new_armor.size() else 0
		
		# AUDIO HOOK: Damage sound for each target hit
		Audio.play_sfx("combat_hit")
		
		# PWR DAMAGE (Special case for Soul Siphon/stat damage)
		if stat == "pwr":
			var pwr_lost = abs(amount)
			var new_pwr = targets_new_pwr[i] if i < targets_new_pwr.size() else 0
			
			# Spawn floating damage number (black)
			_spawn_floating_pwr_damage(animator, target_uuid, pwr_lost)
			
			# Update PWR Label
			if animator.has_method("apply_pwr_delta"):
				animator.apply_pwr_delta(target_uuid, -pwr_lost, new_pwr)
		
		else:
			# STANDARD HP DAMAGE LOGIC
			# ARMOR EFFECTS FIRST (before HP)
			if armor_consumed > 0:
				# Spawn grey floating damage number for armor
				_spawn_floating_armor_damage(animator, target_uuid, armor_consumed)
				# Animate armor label countdown
				animator.apply_armor_delta(target_uuid, armor_consumed, new_armor)
				# Longer pause between armor and HP updates for player to register
				await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout
		
			# HP EFFECTS SECOND
			var hp_damage = abs(amount) - armor_consumed
			if hp_damage > 0:
				# Spawn floating damage number at target (red)
				_spawn_floating_damage(animator, target_uuid, hp_damage)
				# Update HP Label (Puppet Mode)
				animator.apply_hp_delta(target_uuid, -hp_damage, new_hp)
		
		# Apply Burn if needed
		if apply_burn:
			var new_burn = targets_new_burn[i] if i < targets_new_burn.size() else 0
			animator.apply_burn_stack(target_uuid, new_burn)
			# NOTE: Floating burn numbers removed - burn stacks now display in the
			# container label with pop animation (GachaBallView.animate_burn_change)
			
		# Trigger Composable Effects (run in parallel)
		var flash_color = Color.WHITE # White flash for hurt
		if is_burn_damage or apply_burn:
			flash_color = Color(1.0, 0.4, 0.0) # Orange for Burn (brighter than before)
		
		# Determine recoil direction based on team
		# Player units recoil LEFT (away from enemies on their right)
		# Enemy units recoil RIGHT (away from players on their left)
		var recoil_direction = Vector2.LEFT # Default for player units
		var target_view = animator._visual_registry.get(target_uuid)
		if is_instance_valid(target_view) and target_view is GachaBallView:
			# Check if sprite is flipped (enemies are flipped)
			if target_view.icon_rect and target_view.icon_rect.flip_h:
				recoil_direction = Vector2.RIGHT # Enemy recoils right
		
		# Color flash
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		
		# Deformation (hit impact)
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", target_uuid, &"HIT_IMPACT")
		
		# Movement (recoil back)
		if SignalBus.has_signal("unit_move"):
			SignalBus.emit_signal("unit_move", target_uuid, &"RECOIL", recoil_direction)
	
	# SPIKES DAMAGE: Apply reflection damage to attacker(s) at the same moment
	# This happens while the attacker is at the lunge peak (touching the target)
	for spikes_data in spikes_data_list:
		var attacker_uuid = String(spikes_data.get("attacker_uuid", ""))
		var spikes_damage = int(spikes_data.get("spikes_damage", 0))
		var attacker_new_hp = int(spikes_data.get("attacker_new_hp", 0))
		var _old_spikes = int(spikes_data.get("old_spikes", 0))
		var new_spikes = int(spikes_data.get("new_spikes", 0))
		var defender_uuid = String(spikes_data.get("defender_uuid", ""))
		var armor_consumed = int(spikes_data.get("armor_consumed", 0))
		var new_armor = int(spikes_data.get("new_armor", 0))
		
		if attacker_uuid.is_empty() or spikes_damage <= 0:
			continue
		
		# Play spike damage sound
		Audio.play_sfx("combat_hit")
		
		# ARMOR EFFECTS FIRST (before HP)
		if armor_consumed > 0:
			# Spawn grey floating damage number for armor
			_spawn_floating_armor_damage(animator, attacker_uuid, armor_consumed)
			# Animate armor label countdown
			animator.apply_armor_delta(attacker_uuid, armor_consumed, new_armor)
			# Longer pause between armor and HP updates for player to register
			await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout

		var hp_damage = spikes_damage - armor_consumed
		
		if hp_damage > 0:
			# Spawn floating damage number at attacker (white/spikes color)
			_spawn_floating_spikes_damage(animator, attacker_uuid, hp_damage)
			# Update attacker HP
			animator.apply_hp_delta(attacker_uuid, -hp_damage, attacker_new_hp)
		
		# Update defender's Spikes stacks
		if not defender_uuid.is_empty():
			animator.apply_spikes_stack(defender_uuid, new_spikes)
		
		# Flash the attacker white (spikes hit feedback)
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", attacker_uuid, Color.WHITE, AnimationConstants.FLASH_FADE_DURATION)
		
		# Slight recoil on the attacker
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", attacker_uuid, &"HIT_IMPACT")
	
	# Wait for movement completion (longest animation) - only once for all targets/spikes
	if not targets.is_empty():
		await animator.wait_for_animation_completion("move", targets[0])

func _spawn_floating_damage(_animator: Node, target_uuid: String, damage: int) -> void:
	# GUARDIAN FIX: Try to use live position first, as the unit might have moved (intercept)
	var target_view = _animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false

	if is_instance_valid(target_view) and target_view.is_inside_tree():
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
		found_pos = true
	else:
		# Fallback: Use snapshot (Safe mode)
		var tgt_snap = _animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y + tgt_snap.size.y * 0.3)
			found_pos = true
	
	if found_pos:
		VFXFactory.spawn_damage_number_on_layer(damage, spawn_pos, false)

func _spawn_floating_armor_damage(_animator: Node, target_uuid: String, damage: int) -> void:
	# GUARDIAN FIX: Try to use live position first
	var target_view = _animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
		found_pos = true
	else:
		# Fallback: Use snapshot
		var tgt_snap = _animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y + tgt_snap.size.y * 0.3)
			found_pos = true

	if found_pos:
		VFXFactory.spawn_damage_number_on_layer(damage, spawn_pos, true) # true = armor (grey)

## Helper to spawn floating PWR damage number (Black)
func _spawn_floating_pwr_damage(_animator: Node, target_uuid: String, amount: int) -> void:
	var target_view = _animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.5, 0.3))
		found_pos = true
	else:
		var tgt_snap = _animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y + tgt_snap.size.y * 0.3)
			found_pos = true
			
	if found_pos:
		# Use status effect style for PWR loss (size 32, black)
		var color = Color(0.0, 0.0, 0.0) # Pure Black
		VFXFactory.spawn_stat_number_on_layer(amount, spawn_pos, color)

## Helper to spawn floating burn stack number (Orange)
func _spawn_floating_burn_stacks(_animator: Node, target_uuid: String, amount: int) -> void:
	var target_view = _animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		# Offset slightly to assume damage number is center - put this to the right/up
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.8, 0.2))
		found_pos = true
	else:
		var tgt_snap = _animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x * 0.8, tgt_snap.position.y + tgt_snap.size.y * 0.2)
			found_pos = true
			
	if found_pos and amount != 0:
		VFXFactory.spawn_damage_number_on_layer(abs(amount), spawn_pos)

## Helper to spawn floating Spikes damage number (same style as regular damage)
func _spawn_floating_spikes_damage(_animator: Node, target_uuid: String, amount: int) -> void:
	# Use the same style as regular damage (red floating number)
	_spawn_floating_damage(_animator, target_uuid, amount)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat, true)

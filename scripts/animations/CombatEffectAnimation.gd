class_name CombatEffectAnimation
extends BattleAnimation

## CombatEffectAnimation handles combat effect stack changes.
## Provides visual feedback: projectiles (when sourced), colored flash, and floating stack number.
## Handles: burn_stacks, armor_stacks, spikes_stacks, static_stacks, and generic combat effects.

func execute(animator: Node, targets: Array[String], payload: CombatPayload) -> void:
	var amount: int = payload.amount
	var stat: String = payload.stat
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles (if source is provided and amount is positive)
	var projectiles: Array[Node] = []
	var source_uuid: String = payload.source_uuid
	var use_projectiles: bool = not source_uuid.is_empty() and amount > 0
	
	if use_projectiles:
		var color_hint: String = "gray"
		if stat == "armor_stacks" or stat == "armor":
			color_hint = "gray"
		elif stat == "spikes_stacks" or stat == "spikes":
			color_hint = "green"
		elif stat == "burn_stacks" or stat == "burn":
			color_hint = "orange"
		elif stat == "static_stacks" or stat == "static":
			color_hint = "yellow"
		
		for target_uuid in targets:
			var proj: Node = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), stat, color_hint)
			if proj != null:
				projectiles.append(proj)
			
	# Wait for impact if using projectiles
	if not projectiles.is_empty():
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.wait_for_impact()
	elif use_projectiles:
		# Fallback for missing snapshots when projectiles were intended
		await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.4)).timeout

	# 2. Apply Stat Buff / Combat Effect
	var stack_values: Array = payload.targets_new_val
	var status_id: StringName = StringName(stat.trim_suffix("_stacks"))
	var effect_def: CombatEffectDefinition = CombatEffectRegistry.get_definition(status_id)
	
	for i in range(targets.size()):
		var target_uuid: String = targets[i]
		
		var new_val: int = 0
		if not stack_values.is_empty() and i < stack_values.size():
			new_val = int(stack_values[i])
		else:
			new_val = payload.new_val
		
		var flash_color: Color = Color(0.65, 0.65, 0.65)
		if payload.status_color != Color.WHITE:
			flash_color = payload.status_color
		elif effect_def != null:
			flash_color = effect_def.color
		elif stat == "burn_stacks" or stat == "burn":
			flash_color = Color(1.0, 0.4, 0.0)
		elif stat == "armor_stacks" or stat == "armor":
			flash_color = Color(0.65, 0.65, 0.65)
		elif stat == "spikes_stacks" or stat == "spikes":
			flash_color = Color(0.2, 0.85, 0.2)
		elif stat == "static_stacks" or stat == "static":
			flash_color = Color(1.0, 0.85, 0.1)
		
		if stat == "burn_stacks" or stat == "burn":
			animator.apply_burn_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "burn")
		elif stat == "armor_stacks" or stat == "armor":
			animator.apply_armor_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "armor")
		elif stat == "spikes_stacks" or stat == "spikes":
			animator.apply_spikes_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "spikes")
		elif stat == "static_stacks" or stat == "static":
			animator.apply_status_stack(target_uuid, &"static", new_val)
			_spawn_floating_status(animator, target_uuid, amount, "static")
		else:
			animator.apply_status_stack(target_uuid, status_id, new_val)
			_spawn_floating_status(animator, target_uuid, amount, String(status_id))
		
		SignalBus.unit_color_flash.emit(target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		SignalBus.unit_deform.emit(target_uuid, &"SQUISH_BOUNCE")

	# Wait for visual effect completion
	await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.2)).timeout

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	var status_id: StringName = StringName(stat.trim_suffix("_stacks"))
	var projectile_stat: String = "hp"
	var is_attack: bool = false
	
	if status_id == &"armor":
		projectile_stat = "armor"
	elif status_id == &"burn":
		projectile_stat = "burn"
		is_attack = true
	elif status_id == &"spikes":
		projectile_stat = "spikes"
	elif status_id == &"static":
		projectile_stat = "static"
	else:
		var def: CombatEffectDefinition = CombatEffectRegistry.get_definition(status_id)
		if def != null:
			is_attack = def.is_negative
		projectile_stat = String(status_id)
		
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, projectile_stat, is_attack)

func _spawn_floating_status(animator: Node, target_uuid: String, amount: int, type: String) -> void:
	if amount == 0:
		return
	var pos_info: Dictionary = animator.get_live_position(target_uuid)
	if pos_info.is_empty():
		return
	var spawn_pos: Vector2 = Vector2(pos_info.position.x + pos_info.size.x * 0.5, pos_info.position.y + pos_info.size.y * 0.3)
	VFXFactory.spawn_status_effect_number_on_layer(abs(amount), type, spawn_pos)

class_name LethalSaveAnimation
extends BattleAnimation

## Animation for Aegis Charm preventing lethal damage.
## Unit floats up with golden glow, then lands back, surviving at 1 HP.

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	if targets.is_empty():
		push_warning("[LethalSaveAnimation] No targets provided")
		return
	
	var saved_uuid: String = targets[0]
	var heal_amount: int = int(payload.get("heal_amount", 1))
	
	# Ensure this is a coroutine
	await animator.get_tree().process_frame
	
	if OS.is_debug_build():
		print("[LethalSaveAnimation] Saving unit %s with Aegis Charm (heal_amount=%d)" % [saved_uuid.substr(0, 20), heal_amount])
	
	# Emit lethal save signal for visual effect (golden glow + float)
	if SignalBus.has_signal("unit_lethal_save"):
		SignalBus.emit_signal("unit_lethal_save", saved_uuid)
		await animator.wait_for_animation_completion("lethal_save", saved_uuid)
	
	# Unit survives at 1 HP (not heal_amount which is the delta)
	# heal_amount = 1 - old_hp, so if old_hp was -5, heal_amount is 6
	# But the unit survives with exactly 1 HP
	const SURVIVAL_HP: int = 1
	animator.apply_hp_delta(saved_uuid, heal_amount, SURVIVAL_HP)
	
	if OS.is_debug_build():
		print("[LethalSaveAnimation] Save animation complete, HP set to %d" % SURVIVAL_HP)

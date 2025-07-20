# res://scripts/BasicAttackEffect.gd
extends EffectDefinition

## An effect that deals damage equal to the source's power to the first target.

func execute(source, targets, _battle_manager):
	if targets.is_empty() or not is_instance_valid(targets[0]):
		return

	var target = targets[0]
	var damage = source.current_pwr
	target.set_current_hp(max(0, target.current_hp - damage))

	# Inform UI and log systems
	if Engine.has_singleton("EventBus"):
		var src_name = tr(source.get_definition().display_name_key)
		var tgt_name = tr(target.get_definition().display_name_key)
		var msg = "%s deals %d dmg to %s" % [src_name, damage, tgt_name]
		EventBus.emit_signal("battle_log_event", msg)
		EventBus.emit_signal("battle_inventory_changed")
		# Emit unit_stats_changed so UI updates HP in real time
		EventBus.emit_signal("unit_stats_changed", target.ball_uuid)

	print("BasicAttack: %s attacks %s for %d damage. Target HP is now %d." % [source.definition_id, target.definition_id, damage, target.current_hp])

# res://scripts/BasicAttackEffect.gd
extends "res://scripts/EffectDefinition.gd"

## An effect that deals damage equal to the source's power to the first target.

func execute(source, targets, _battle_manager):
	if targets.is_empty() or not is_instance_valid(targets[0]):
		return

	var target = targets[0]
	var damage = source.current_pwr
	target.current_hp -= damage
	
	print("BasicAttack: %s attacks %s for %d damage. Target HP is now %d." % [source.definition_id, target.definition_id, damage, target.current_hp])

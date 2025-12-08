# Helper functions for BattleAnimator
# This script is a static helper and cannot access the scene tree directly.

static func get_visual_state(instance: GachaBallInstance) -> Dictionary:
	var state = {}
	if is_instance_valid(instance):
		state["hp"] = instance.current_hp
		state["pwr"] = instance.current_pwr
		state["burn_stacks"] = instance.get_status_effect_amount(&"burn")
		state["def_id"] = instance.definition_id
	return state

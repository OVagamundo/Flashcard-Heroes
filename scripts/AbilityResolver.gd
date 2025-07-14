# res://scripts/AbilityResolver.gd
# This script is expected to be added to the AutoLoad list as "AbilityResolver"
# Do NOT give it a class_name to avoid hiding the autoload singleton.
@tool
extends Node

const EffectDefinition = preload("res://scripts/EffectDefinition.gd")

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

## Executes an effect immediately. The BattleManager is now responsible for
## queueing and pacing.
func execute_effect(effect: EffectDefinition, source: GachaBallInstance, targets: Array[GachaBallInstance], battle_manager):
	if effect == null:
		printerr("AbilityResolver: Tried to execute a null EffectDefinition.")
		return
	if not is_instance_valid(source):
		printerr("AbilityResolver: Source instance is invalid.")
		return

	# The core execution call.
	effect.execute(source, targets, battle_manager)

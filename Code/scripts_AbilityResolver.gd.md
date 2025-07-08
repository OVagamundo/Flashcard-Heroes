<!-- Original: scripts/AbilityResolver.gd -->

```gdscript
# res://scripts/AbilityResolver.gd
extends Node

const EffectDefinition = preload("res://scripts/EffectDefinition.gd")


## Manages ability queue and resolution.
## For the MVP, it will directly execute the provided effect.


## Executes the provided effect with the given source and targets.
## This is called by the BattleManager during the COMBAT phase.
## @param effect: The EffectDefinition resource to execute.
## @param source: The GachaBallInstance initiating the effect.
## @param targets: An array of GachaBallInstances being targeted.
## @param battle_manager: A reference to the current BattleManager.
func execute_effect(effect: EffectDefinition, source: GachaBallInstance, targets: Array[GachaBallInstance], battle_manager):
	if effect:
		effect.execute(source, targets, battle_manager)

```
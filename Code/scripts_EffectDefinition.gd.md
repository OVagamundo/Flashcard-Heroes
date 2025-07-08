<!-- Original: scripts/EffectDefinition.gd -->

```gdscript
# res://scripts/EffectDefinition.gd
class_name EffectDefinition
extends Resource

## The base class for all ability effects.
## Defines the contract for what an effect can do.

## Executes the effect's logic.
## @param source: The GachaBallInstance initiating the effect.
## @param targets: An array of GachaBallInstances being targeted.
## @param battle_manager: A reference to the current BattleManager.
func execute(_source, _targets, _battle_manager):
	pass

```
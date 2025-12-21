# res://scripts/EffectDefinition.gd
@tool
class_name EffectDefinition
extends Resource

## An abstract base class for any action that can occur in the game.
## Concrete effects (e.g., `EffectModifyStat`, `EffectDealDamage`) must inherit from this class and implement its `execute` method.

## A dictionary containing the specific parameters for this effect's execution.
## This supports both flat values (e.g., `{"damage": 3}`) and stat-scaling values. See TDD for stat-scaling structure.
@export var parameters: Dictionary
@export var target_type: StringName

## The core method that all concrete effect scripts must implement.
## It receives all necessary information to perform its action.
## @param source_uuid: String - The UUID of the GachaBallInstance initiating the effect.
## @param targets: Array[String] - An array of target UUIDs.
## @param battle_manager: BattleManager - A reference to the current BattleManager.
## @param context: Dictionary - The original context of the event that started this chain.
## @return EffectResult - Structured result containing events and trigger data.
##         Returns null for backwards compatibility during migration (treated as empty result).
func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: Dictionary) -> Variant:
	return null

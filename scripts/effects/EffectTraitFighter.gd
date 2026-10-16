# res://scripts/effects/EffectTraitFighter.gd
@tool
extends EffectDefinition

## Fighter trait mechanics are integrated directly into combat loops:
## - L1 (2 Units): BasicAttackEffect - Attacks deal +1 damage if target HP > Fighter HP
## - L2 (3 Units): BattleManager (trigger_on_hurt) - Retaliate with 1 ranged damage to attacker
## - L3 (4 Units): BasicAttackEffect - Half PWR cleave damage behind target
## - L4 (5 Units): BattleManager (trigger_on_kill) - +1 PWR and extra action on kill

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: Dictionary) -> EffectResult:
	return EffectResult.empty()

# res://scripts/effects/EffectTraitFire.gd
@tool
extends EffectDefinition

## Fire trait mechanics are integrated directly into combat loops:
## - L1 (3 Souls): BasicAttackEffect - 1 Burn stack on attack
## - L2 (6 Souls): BasicAttackEffect - +1 additional Burn if target holds Burn
## - L3 (12 Souls): BattleManager - Spread 1 Burn to adjacent allies on turn damage
## - L4 (20 Souls): BasicAttackEffect - Bonus damage equal to target's Burn stacks
## - L5 (32 Souls): BattleManager - Burn dispersion to adjacent enemies on kill

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: Dictionary) -> EffectResult:
	return EffectResult.empty()

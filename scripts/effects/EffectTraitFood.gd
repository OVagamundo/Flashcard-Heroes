# res://scripts/effects/EffectTraitFood.gd
@tool
extends EffectDefinition

## Food trait mechanics are reactive:
## - L1 (2 Units): on_hurt - Heals ally behind by 1 HP
## - L2 (3 Units): on_hurt - Heals ally behind by 2 HP
## - L3 (4 Units): on_hurt - Heals ally behind by 3 HP and grants +1 PWR
## - L4 (5 Units): on_hurt - Heals ally behind by 4 HP and grants +2 PWR
## - L4 Death Pass: on_death - Passes full current PWR to ally behind

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: Dictionary) -> EffectResult:
	return EffectResult.empty()

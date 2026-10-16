# res://scripts/effects/EffectTraitToy.gd
@tool
extends EffectDefinition

## Toy trait mechanics are reactive:
## - L1 (2 Units): BasicAttackEffect - When hit by melee attack, attacker receives 2 Static
## - L2 (3 Units): BasicAttackEffect - Attacker receives 3 Static
## - L3 (4 Units): BasicAttackEffect - Attacker receives 4 Static
## - L4 (5 Units): DeathProcessor - On death, detonates enemy holding highest Static stacks

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, _context: Dictionary) -> EffectResult:
	return EffectResult.empty()

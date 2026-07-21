class_name CombatProjectile
extends RefCounted

## Presentation data for a ranged combat projectile.
## Kept separate from CombatPayload so its contract is also type checked.

var stat: String = "hp"
var amount: int = 0
var color: String = "red"

func _init(p_stat: String = "hp", p_amount: int = 0, p_color: String = "red") -> void:
	stat = p_stat
	amount = p_amount
	color = p_color

func deep_clone() -> CombatProjectile:
	return CombatProjectile.new(stat, amount, color)

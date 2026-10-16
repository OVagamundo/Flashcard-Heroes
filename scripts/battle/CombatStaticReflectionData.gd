class_name CombatStaticReflectionData
extends RefCounted

## A single Static reflection (Toy trait) resolved at melee impact.

var attacker_uuid: String = ""
var defender_uuid: String = ""
var static_amount: int = 0
var attacker_old_static: int = 0
var attacker_new_static: int = 0

func deep_clone() -> CombatStaticReflectionData:
	var copy := CombatStaticReflectionData.new()
	copy.attacker_uuid = attacker_uuid
	copy.defender_uuid = defender_uuid
	copy.static_amount = static_amount
	copy.attacker_old_static = attacker_old_static
	copy.attacker_new_static = attacker_new_static
	return copy

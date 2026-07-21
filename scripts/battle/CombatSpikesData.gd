class_name CombatSpikesData
extends RefCounted

## A single Spikes reflection resolved by the simulator and displayed at impact.

var attacker_uuid: String = ""
var defender_uuid: String = ""
var spikes_damage: int = 0
var attacker_old_hp: int = 0
var attacker_new_hp: int = 0
var attacker_max_hp: int = 0
var old_spikes: int = 0
var new_spikes: int = 0
var armor_consumed: int = 0
var new_armor: int = 0

func deep_clone() -> CombatSpikesData:
	var copy := CombatSpikesData.new()
	copy.attacker_uuid = attacker_uuid
	copy.defender_uuid = defender_uuid
	copy.spikes_damage = spikes_damage
	copy.attacker_old_hp = attacker_old_hp
	copy.attacker_new_hp = attacker_new_hp
	copy.attacker_max_hp = attacker_max_hp
	copy.old_spikes = old_spikes
	copy.new_spikes = new_spikes
	copy.armor_consumed = armor_consumed
	copy.new_armor = new_armor
	return copy

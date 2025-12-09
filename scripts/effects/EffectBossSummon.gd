# res://scripts/effects/EffectBossSummon.gd
@tool
extends EffectDefinition

## Effect that summons units to fill empty enemy team slots using a budget system.
## Used by boss units at end of turn to call reinforcements.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> Dictionary:
	# 1. Get the boss instance
	var boss_inst = battle_manager.get_instance(source_uuid)
	if not is_instance_valid(boss_inst):
		return {}
	
	# 2. Get budget from parameters
	var budget: int = parameters.get("budget", 5)
	
	# 3. Count empty enemy lineup slots
	var enemy_lineup = battle_manager.get_instances_in_container(&"EnemyLineup")
	var max_slots: int = 5
	var filled_slots: int = enemy_lineup.size()
	var empty_slots: int = max_slots - filled_slots
	
	if empty_slots <= 0:
		return {}
	
	# 4. Generate summons within budget
	var summon_data: Array = _generate_summons(budget, empty_slots)
	
	if summon_data.is_empty():
		return {}
	
	# 5. Return summon instructions for BattleManager
	return {
		"summon_units": summon_data,
		"team": "ENEMY"
	}

func _generate_summons(budget: int, max_units: int) -> Array:
	# Get available units (exclude heroes and bosses)
	var available_units: Array = []
	for d in Database.units.values():
		# Skip hero units
		if d.id == &"hero" or d.id == &"enemy_hero":
			continue
		if d.is_hero:
			continue
		# Skip boss units
		if String(d.id).begins_with("boss_"):
			continue
		available_units.append(d)
	
	if available_units.is_empty():
		return []
	
	# Sort by cost ascending for budget optimization
	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	
	var summons: Array = []
	var spent: int = 0
	
	# Fill slots within budget
	while spent < budget and summons.size() < max_units:
		var affordable = available_units.filter(func(u): return u.cost <= (budget - spent))
		if affordable.is_empty():
			break
		var chosen = affordable.pick_random()
		summons.append({"unit_id": chosen.id})
		spent += chosen.cost
	
	return summons

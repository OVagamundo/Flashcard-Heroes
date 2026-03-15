# res://scripts/EffectBossSummon.gd
@tool
extends EffectDefinition

## Effect that summons units to fill empty enemy team slots using the encounter budget system.
## Used by boss units at end of turn to call reinforcements.
## 
## Budget: Half of daily budget (5 + (day - 1) * 1) / 2
## Summons include equipped items but NO trinkets.
##
## Note: This effect queries container state during end_of_turn, which is a stable game state.
## Container queries are valid here because we're not in a transitional death state.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	# 1. Get current day from context or battle state
	var current_day: int = 1
	if context.has("current_day"):
		current_day = context.current_day
	elif is_instance_valid(battle_manager) and battle_manager.has_method("get_current_day"):
		current_day = battle_manager.get_current_day()
	else:
		# Fallback: try to get from encounter metadata or GameManager
		if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			current_day = GameManager.run_state.day
	
	# 2. Count empty enemy lineup slots
	# Note: Container queries at end_of_turn are valid (stable game state)
	var enemy_container = battle_manager.get_container(&"EnemyLineup")
	if not is_instance_valid(enemy_container):
		return EffectResult.empty()
	
	var max_slots: int = 5
	var filled_slots: int = 0
	for i in range(max_slots):
		if not enemy_container.get_uuid(i).is_empty():
			filled_slots += 1
	var empty_slots: int = max_slots - filled_slots
	
	if empty_slots <= 0:
		return EffectResult.empty()
	
	# 3. Generate summons using EncounterGenerator (half daily budget, no trinkets)
	var summon_data: Array = EncounterGenerator.generate_boss_summons(current_day, empty_slots)
	
	if summon_data.is_empty():
		return EffectResult.empty()
	
	# 4. Return EffectResult with summon instructions
	var result := EffectResult.new()
	result.summon_units_request = summon_data
	result.summon_team = "ENEMY"
	return result

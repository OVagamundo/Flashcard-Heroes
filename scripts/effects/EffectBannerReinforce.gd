# res://scripts/effects/EffectBannerReinforce.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Authoritative reinforcement generator for Banner Trinkets.
## Fires on odd turns (1, 3, 5, 7...) at end of turn (SubPhase.END_OF_TURN_SUMMON = 250).
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	# 1. Cadence Guard: odd turns only
	var turn_num: int = context.turn if context.turn > 0 else int(battle_manager._current_turn)
	if turn_num % 2 == 0:
		return EffectResult.empty()

	# 2. Board Inspection
	var enemy_container = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if not is_instance_valid(enemy_container):
		return EffectResult.empty()

	var current_board: Dictionary = {} # slot_idx: int -> unit_def_id: StringName
	var board_snapshot: Array[EncounterDraftUnit] = []
	var empty_slots: Array[int] = []

	for i in range(5):
		var u_uuid: String = enemy_container.get_uuid(i)
		if u_uuid.is_empty():
			empty_slots.append(i)
		else:
			var u_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(u_uuid)
			if is_instance_valid(u_inst) and u_inst.current_hp > 0 and not battle_manager.is_dead_this_turn(u_uuid):
				current_board[i] = u_inst.definition_id
				board_snapshot.append(EncounterDraftUnit.from_live(u_inst, battle_manager.get_all_instances()))
			else:
				empty_slots.append(i)

	if empty_slots.is_empty():
		return EffectResult.empty()

	# 3. Active Secondary Trinkets
	var active_secondary_trinkets: Array[StringName] = []
	var et_container = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	if is_instance_valid(et_container):
		for i in range(et_container.get_size()):
			var t_uuid: String = et_container.get_uuid(i)
			if t_uuid.is_empty():
				continue
			var t_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t_uuid)
			if not is_instance_valid(t_inst):
				continue
			var t_def = t_inst.get_definition()
			if is_instance_valid(t_def) and not t_def.is_banner:
				active_secondary_trinkets.append(t_inst.definition_id)

	# 4. Resolve Banner Trinket ID & Daily Budget
	var source_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	var banner_id: StringName = source_inst.definition_id if is_instance_valid(source_inst) else &""

	var current_day: int = 1
	if context.current_day > 0:
		current_day = context.current_day
	elif is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		current_day = GameManager.run_state.day

	var daily_budget: int = 3 + (current_day - 1)

	# 5. Delegation to EncounterGenerator
	var summon_data: Array[Dictionary] = EncounterGenerator.generate_banner_reinforcements(
		banner_id,
		daily_budget,
		current_board,
		empty_slots,
		active_secondary_trinkets,
		RNGManager.combat_rng,
		board_snapshot
	)

	if summon_data.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	result.summon_units_request = summon_data
	result.summon_team = "ENEMY"
	return result

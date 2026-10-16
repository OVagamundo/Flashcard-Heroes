# res://scripts/effects/EffectTraitPlantTurnStart.gd
@tool
extends EffectDefinition

## Turn-Start Plant trait effect granted by Plant Trait Trinket.
## Triggered on_turn_start.
## Thresholds (Units):
##   L2 (3 Units): Lowest-HP Plant recovers 1 HP (ACTION_HEAL).
##   L4 (5 Units): All Plants gain 1 Spikes and recover 1 HP (ACTION_HEAL).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	var trinket = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(trinket):
		return EffectResult.empty()

	var team: String = context.get("team", "")
	if team.is_empty():
		var container_tag = trinket.location_container_tag
		if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			team = "ENEMY"
		else:
			team = "PLAYER"

	var is_player = (team == "PLAYER")
	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var plant_units: int = int(active_traits.get("PLANT", 0))
	if plant_units < 3:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	var living_plants: Array[GachaBallInstance] = []
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0 and battle_manager.has_trait(u, "PLANT"):
			living_plants.append(u)

	if living_plants.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_plant_turn_start")

	# L2 (3 Units): Lowest-HP Plant recovers 1 HP (ACTION_HEAL)
	living_plants.sort_custom(func(a, b):
		if a.current_hp != b.current_hp:
			return a.current_hp < b.current_hp
		if is_player:
			return a.location_slot_index > b.location_slot_index
		else:
			return a.location_slot_index < b.location_slot_index
	)
	var lowest_plant = living_plants[0]
	var old_h = lowest_plant.current_hp
	var new_h = battle_manager.apply_stat_delta(lowest_plant, "hp", 1, source_uuid, C.ACTION_HEAL)
	var lp_def = lowest_plant.get_definition()
	var max_h = lp_def.base_hp if is_instance_valid(lp_def) else 0

	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [lowest_plant.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal(source_uuid, 1, [old_h], [new_h], [max_h])
	}))

	# L4 (5 Units): All Plants gain 1 Spikes and recover 1 HP (ACTION_HEAL)
	if plant_units >= 5:
		for plant in living_plants:
			var old_spk = plant.get_status_effect_amount(&"spikes")
			var new_spk = battle_manager.apply_stat_delta(plant, "spikes_stacks", 1)
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [plant.ball_uuid],
				"ability_id": ability_id,
				"visual_payload": CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [old_spk], [new_spk])
			}))

			var p_old_h = plant.current_hp
			var p_new_h = battle_manager.apply_stat_delta(plant, "hp", 1, source_uuid, C.ACTION_HEAL)
			var p_def = plant.get_definition()
			var p_max_h = p_def.base_hp if is_instance_valid(p_def) else 0
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": source_uuid,
				"target_uuids": [plant.ball_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_HEAL,
				"visual_payload": CombatPayload.heal(source_uuid, 1, [p_old_h], [p_new_h], [p_max_h])
			}))

	result.state_applied = true
	return result

# res://scripts/effects/EffectTraitPlantPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Plant trait effect granted by Plant Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Frontmost Plant gains 1 Spikes.
##   L3 (4 Units): All Plants gain 1 Spikes and +1 HP (frontmost gains 2 Spikes total).

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
	if plant_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var frontmost_plant = battle_manager.get_frontmost_unit_on_team(is_player, "PLANT")
	if not is_instance_valid(frontmost_plant):
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_plant")

	# L1 (2 Units): Frontmost Plant gains 1 Spikes
	var old_spk = frontmost_plant.get_status_effect_amount(&"spikes")
	var new_spk = battle_manager.apply_stat_delta(frontmost_plant, "spikes_stacks", 1)
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [frontmost_plant.ball_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [old_spk], [new_spk])
	}))

	# L3 (4 Units): All Plants gain 1 Spikes and +1 HP
	if plant_units >= 4:
		for unit in units:
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				continue
			if not battle_manager.has_trait(unit, "PLANT"):
				continue

			var u_old_spk = unit.get_status_effect_amount(&"spikes")
			var u_new_spk = battle_manager.apply_stat_delta(unit, "spikes_stacks", 1)
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [unit.ball_uuid],
				"ability_id": ability_id,
				"visual_payload": CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [u_old_spk], [u_new_spk])
			}))

			var u_old_hp = unit.current_hp
			var u_new_hp = battle_manager.apply_stat_delta(unit, "hp", 1, source_uuid, C.ACTION_BUFF)
			var u_def = unit.get_definition()
			var u_max_hp = u_def.base_hp if is_instance_valid(u_def) else 0
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [unit.ball_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_BUFF,
				"visual_payload": CombatPayload.hp_change(source_uuid, 1, [u_old_hp], [u_new_hp], [u_max_hp])
			}))

	result.state_applied = true
	return result

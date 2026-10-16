# res://scripts/effects/EffectTraitMechaPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Mecha trait effect granted by Mecha Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): All Mechas gain 1 Spikes.
##   L2 (3 Units): All Mechas gain 1 Armor.

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
	var mecha_units: int = int(active_traits.get("MECHA", 0))
	if mecha_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_mecha")

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager.has_trait(unit, "MECHA"):
			continue

		# L1 (2 Units): 1 Spikes
		var old_spikes = unit.get_status_effect_amount(&"spikes")
		var new_spikes = battle_manager.apply_stat_delta(unit, "spikes_stacks", 1)
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": [unit.ball_uuid],
			"ability_id": ability_id,
			"visual_payload": CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [old_spikes], [new_spikes])
		}))

		# L2 (3 Units): 1 Armor
		if mecha_units >= 3:
			var old_armor = unit.get_status_effect_amount(&"armor")
			var new_armor = battle_manager.apply_stat_delta(unit, "armor_stacks", 1)
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [unit.ball_uuid],
				"ability_id": ability_id,
				"visual_payload": CombatPayload.status_change(source_uuid, 1, "armor_stacks", [old_armor], [new_armor])
			}))

	result.state_applied = true
	return result

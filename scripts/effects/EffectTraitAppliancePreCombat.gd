# res://scripts/effects/EffectTraitAppliancePreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Appliance trait effect granted by Appliance Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Appliances cleanse previously held Static stacks.
##   L2 (3 Units): Appliances also cleanse previously held Burn stacks.

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
	var appliance_units: int = int(active_traits.get("APPLIANCE", 0))
	if appliance_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	if units.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_appliance")

	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if not battle_manager.has_trait(unit, "APPLIANCE"):
			continue

		# L1 (2 Units): Cleanse Static
		var st_stacks = unit.get_status_effect_amount(&"static")
		if st_stacks > 0:
			unit.clear_status_effect(&"static")
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": trinket.ball_uuid,
				"target_uuids": [unit.ball_uuid],
				"ability_id": ability_id,
				"visual_payload": CombatPayload.status_change(trinket.ball_uuid, -st_stacks, "static_stacks", [st_stacks], [0])
			}))

		# L2 (3 Units): Cleanse Burn
		if appliance_units >= 3:
			var bn_stacks = unit.get_status_effect_amount(&"burn")
			if bn_stacks > 0:
				unit.clear_status_effect(&"burn")
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": trinket.ball_uuid,
					"target_uuids": [unit.ball_uuid],
					"ability_id": ability_id,
					"visual_payload": CombatPayload.status_change(trinket.ball_uuid, -bn_stacks, "burn_stacks", [bn_stacks], [0])
				}))

	result.state_applied = true
	return result

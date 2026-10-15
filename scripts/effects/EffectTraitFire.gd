# res://scripts/effects/EffectTraitFire.gd
@tool
extends EffectDefinition

## Start-of-Combat Fire trait effect granted by Fire Trait Trinket.
## Triggered on_pre_combat when the battle button is pressed.
## At 7+ Fire souls: Opposing team gets 2 Burn stacks at combat start.
## (Attack-based burn from 3+ / 5+ souls continues to apply during attacks via BasicAttackEffect).

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

	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var fire_souls: int = int(active_traits.get("FIRE", 0))
	if fire_souls < 7:
		return EffectResult.empty()

	var opposing_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var opposing_units = battle_manager.get_instances_in_container(opposing_container_tag)
	var fire_target_uuids: Array[String] = []
	var fire_old_vals: Array[int] = []
	var fire_new_vals: Array[int] = []

	for unit in opposing_units:
		if is_instance_valid(unit) and unit.current_hp > 0:
			var old_val = unit.get_status_effect_amount(&"burn")
			var new_val = battle_manager.apply_stat_delta(unit, "burn_stacks", 2)
			fire_target_uuids.append(unit.ball_uuid)
			fire_old_vals.append(old_val)
			fire_new_vals.append(new_val)

	if fire_target_uuids.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_fire")
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": fire_target_uuids,
		"ability_id": ability_id,
		"visual_payload": CombatPayload.status_change("", 2, "burn_stacks", fire_old_vals, fire_new_vals)
	}))

	result.state_applied = true
	return result

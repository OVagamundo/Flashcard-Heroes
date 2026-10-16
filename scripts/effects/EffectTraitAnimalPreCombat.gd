# res://scripts/effects/EffectTraitAnimalPreCombat.gd
@tool
extends EffectDefinition

## Start-of-Combat Animal trait effect granted by Animal Trait Trinket.
## Triggered on_pre_combat.
## Thresholds (Units):
##   L1 (2 Units): Random Animal gains +1 PWR.

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
	var animal_units: int = int(active_traits.get("ANIMAL", 0))
	if animal_units < 2:
		return EffectResult.empty()

	var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = battle_manager.get_instances_in_container(container_tag)
	var living_animals: Array[GachaBallInstance] = []
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0 and battle_manager.has_trait(u, "ANIMAL"):
			living_animals.append(u)

	if living_animals.is_empty():
		return EffectResult.empty()

	var chosen_animal: GachaBallInstance = RNGManager.combat_rng.pick_random(living_animals)
	if not is_instance_valid(chosen_animal):
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"ability_trait_animal")

	var old_pwr = chosen_animal.current_pwr
	var new_pwr = battle_manager.apply_stat_delta(chosen_animal, "pwr", 1, source_uuid, C.ACTION_BUFF)

	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [chosen_animal.ball_uuid],
		"ability_id": ability_id,
		"action_type": C.ACTION_BUFF,
		"visual_payload": CombatPayload.pwr_change(source_uuid, 1, [old_pwr], [new_pwr])
	}))

	result.state_applied = true
	return result

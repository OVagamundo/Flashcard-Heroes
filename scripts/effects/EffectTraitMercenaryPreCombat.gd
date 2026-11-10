# res://scripts/effects/EffectTraitMercenaryPreCombat.gd
@tool
class_name EffectTraitMercenaryPreCombat
extends EffectDefinition

## Pre-Combat Mercenary trait effect granted by Mercenary Trait Trinket (Mercenary Sigil).
## Triggered on_pre_combat.
## Thresholds (Units):
##   Gold (4 Units): Each Mercenary unit gains +1 Armor for every full 10 Gold held.
##   Prismatic (5 Units): Earn 1 Gold at pre-combat once per turn (triggers on_gold_earned).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	if not is_simulation:
		return EffectResult.empty()

	var trinket = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(trinket):
		return EffectResult.empty()

	var team: String = context.team
	if team.is_empty():
		var container_tag = trinket.location_container_tag
		if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			team = "ENEMY"
		else:
			team = "PLAYER"

	var is_player = (team == "PLAYER")
	var active_traits: Dictionary = battle_manager.get_active_traits(team)
	var mercenary_units: int = int(active_traits.get("MERCENARY", 0))
	if mercenary_units < 4:
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = (context.ability_id if context.ability_id != &"" else &"ability_trait_mercenary_pre_combat")

	# Prismatic (5 Units): Earn 1 Gold at pre-combat (resolves first so Gold threshold checks updated wallet)
	if mercenary_units >= 5 and is_player:
		battle_manager.earn_gold(1, source_uuid)

	# Gold (4 Units): Each Mercenary unit gains +1 Armor for every full 10 Gold held
	var gold: int = 0
	if is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold
	var armor_per_unit: int = int(gold / 10)

	if armor_per_unit > 0:
		var container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		var units = battle_manager.get_instances_in_container(container_tag)
		var target_uuids: Array[String] = []
		var old_vals: Array[int] = []
		var new_vals: Array[int] = []

		for unit in units:
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				continue
			if not battle_manager.has_trait(unit, "MERCENARY"):
				continue

			var old_armor: int = unit.get_status_effect_amount(&"armor")
			var new_armor: int = battle_manager.apply_stat_delta(unit, "armor_stacks", armor_per_unit)
			target_uuids.append(unit.ball_uuid)
			old_vals.append(old_armor)
			new_vals.append(new_armor)

		if not target_uuids.is_empty():
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Mercenary Gold tier grants +%d Armor to Mercenaries (%d Gold)" % [armor_per_unit, gold]
			}))
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": target_uuids,
				"ability_id": ability_id,
				"visual_payload": CombatPayload.status_change(source_uuid, armor_per_unit, "armor_stacks", old_vals, new_vals)
			}))

	result.state_applied = true
	return result

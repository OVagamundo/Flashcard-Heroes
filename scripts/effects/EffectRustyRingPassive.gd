# res://scripts/effects/EffectRustyRingPassive.gd
@tool
extends EffectDefinition

## Passive stat scaling effect for Rusty Ring trinket.
## Monitors equipment status for all team units on board changed:
## - Removes buff (-1 HP, -1 PWR) if unit equips any item.
## - Restores buff (+1 HP, +1 PWR) if unit unequips all items.
## - Normalizes stacks and stats from 2 to 1 if two buffed units merge.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation := bool(context.is_simulation)
	var all_instances: Dictionary = battle_manager.get_all_instances()
	
	# Resolve the trinket's team
	var trinket_team: String = context.team
	if trinket_team.is_empty():
		var trinket_instance = battle_manager.get_instance(source_uuid)
		if is_instance_valid(trinket_instance):
			trinket_team = _get_team_from_container(trinket_instance.location_container_tag)
			
	if trinket_team.is_empty():
		return EffectResult.empty()
		
	var aura_key: StringName = AuraEvaluator.make_key(&"rusty_ring", source_uuid)
	var changed_units := 0
	var total_hp_delta := 0
	var total_pwr_delta := 0

	var result := EffectResult.new()

	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst) or inst.current_hp <= 0 or battle_manager.is_dead_this_turn(uuid):
			continue
		if inst.location_container_tag not in [&"PlayerLineup", &"EnemyLineup"]:
			continue
		
		# Only process UNIT category on the same team
		var definition = inst.get_definition()
		if not is_instance_valid(definition) or definition.category != &"UNIT":
			continue
		if _get_team_from_container(inst.location_container_tag) != trinket_team:
			continue

		# Only process units that have been registered by the entry trigger
		if not inst.has_aura(aura_key):
			continue

		var has_equip: bool = AuraEvaluator._unit_has_equipment(inst)
		var target_val: int = 0 if has_equip else 1
		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			inst, aura_key, target_val, target_val,
			source_uuid, AuraEvaluator.KIND_RUSTY_RING,
			{"keep_registered": true, "silent": is_simulation}
		)
		if not rec_res.changed:
			continue

		if is_simulation:
			# If delta < 0 (debuff on equip): self debuff
			# If delta > 0 (buff on unequip): originates from Rusty Ring trinket
			var visual_source: String = source_uuid if rec_res.delta_hp > 0 else ""
			var multi_payload := CombatPayload.both_stats_change(
				visual_source, rec_res.delta_hp, rec_res.delta_pwr,
				[rec_res.old_hp], [rec_res.new_hp], [rec_res.old_pwr], [rec_res.new_pwr]
			)
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source,
				"target_uuids": [uuid],
				"ability_id": (context.ability_id if context.ability_id != &"" else &"rusty_ring_passive"),
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": source_uuid,
				"visual_payload": multi_payload
			}))

		changed_units += 1
		total_hp_delta += rec_res.delta_hp
		total_pwr_delta += rec_res.delta_pwr

	if changed_units == 0:
		return EffectResult.empty()

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Rusty Ring updated %d units (%+d HP, %+d PWR)" % [changed_units, total_hp_delta, total_pwr_delta]
	}))
	result.state_applied = true
	return result



# Helper to determine team from container tag
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerShelf":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""

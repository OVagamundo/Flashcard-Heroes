@tool
class_name EffectSlimeCellScaling
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var all_instances: Dictionary = battle_manager.get_all_instances()
	var source_item: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	assert(source_item != null, "EffectSlimeCellScaling: source item is not registered")
	assert(source_item.definition_id == &"item_t2_d", "EffectSlimeCellScaling: source must be a Slime Cell")

	var battle_cell_count: int = 0
	for candidate_uuid: String in all_instances:
		var candidate: GachaBallInstance = all_instances[candidate_uuid]
		if candidate.definition_id == &"item_t2_d":
			battle_cell_count += 1

	var active_holder_uuid: String = source_item.equipped_on_uuid
	var target_bonus: int = 0
	if not active_holder_uuid.is_empty():
		assert(all_instances.has(active_holder_uuid), "EffectSlimeCellScaling: source holder is not registered")
		var active_holder: GachaBallInstance = all_instances[active_holder_uuid]
		if active_holder.current_hp > 0 and _is_on_battle_board(active_holder):
			target_bonus = battle_cell_count

	var aura_key: StringName = AuraEvaluator.make_key(&"slime_cell", source_uuid)
	var result := EffectResult.new()
	var holder_updated: bool = false
	for instance_uuid: String in all_instances:
		var instance: GachaBallInstance = all_instances[instance_uuid]
		if instance_uuid == source_uuid:
			continue

		var desired_bonus: int = target_bonus if instance_uuid == active_holder_uuid else 0
		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			instance, aura_key, 0, desired_bonus, source_uuid, AuraEvaluator.KIND_SLIME_CELL,
			{"silent": true}
		)
		if not rec_res.changed:
			continue

		holder_updated = true
		if _is_on_battle_board(instance):
			var payload := CombatPayload.pwr_change(instance_uuid, rec_res.delta_pwr, [rec_res.old_pwr], [rec_res.new_pwr])
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": instance_uuid,
				"target_uuids": [instance_uuid],
				"ability_id": context.ability_id,
				"ability_holder_uuid": instance_uuid,
				"visual_payload": payload
			}))

	if not holder_updated:
		return EffectResult.empty()

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Slime Cell (%s) updated holder %s (%+d PWR, %d cells)" % [source_uuid, active_holder_uuid, target_bonus, battle_cell_count]
	}))
	result.state_applied = true
	return result

func _is_on_battle_board(instance: GachaBallInstance) -> bool:
	var container: StringName = instance.location_container_tag
	return (
		container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		or container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
		or container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		or container == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF
	)

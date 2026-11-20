# res://scripts/battle/BoardStatDiffBuilder.gd
class_name BoardStatDiffBuilder
extends RefCounted

## Pure simulation helper that captures pre-operation unit stat snapshots
## and diffs them into CombatEvents + stat-change triggers after inventory
## or board mutations. Zero SceneTree / UI / SignalBus dependencies.

const C = preload("res://scripts/Constants.gd")


static func _is_unit_instance(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var def: Resource = inst.get_definition()
	return def is GachaBallDefinition and (def as GachaBallDefinition).category == &"UNIT"


static func capture_all_unit_stats(battle_instances: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	for uuid in battle_instances:
		var inst: GachaBallInstance = battle_instances[uuid] as GachaBallInstance
		if _is_unit_instance(inst):
			stats[uuid] = {
				"hp": inst.current_hp,
				"pwr": inst.current_pwr,
				"burn_stacks": inst.get_status_effect_amount(&"burn"),
				"armor_stacks": inst.get_status_effect_amount(&"armor"),
				"spikes_stacks": inst.get_status_effect_amount(&"spikes"),
				"status_effects": inst.status_effects.duplicate(true)
			}
	return stats


static func apply_unit_stat_override(snapshot_unit: Dictionary, unit_override: Dictionary) -> void:
	if unit_override.has("hp"):
		snapshot_unit["hp"] = unit_override["hp"]
	if unit_override.has("pwr"):
		snapshot_unit["pwr"] = unit_override["pwr"]
	if unit_override.has("burn_stacks"):
		snapshot_unit["burn_stacks"] = unit_override["burn_stacks"]
	if unit_override.has("armor_stacks"):
		snapshot_unit["armor_stacks"] = unit_override["armor_stacks"]
	if unit_override.has("spikes_stacks"):
		snapshot_unit["spikes_stacks"] = unit_override["spikes_stacks"]
	if unit_override.has("status_effects"):
		snapshot_unit["status_effects"] = unit_override["status_effects"].duplicate(true)


static func generate_inventory_stat_events(pre_stats: Dictionary, battle_manager: Node) -> Dictionary:
	var extra_events: Array[CombatEvent] = []
	var pre_stats_override: Dictionary = {}

	for uuid in pre_stats:
		var inst: GachaBallInstance = battle_manager.get_instance(uuid)
		if not is_instance_valid(inst):
			continue
		var old_hp: int = int(pre_stats[uuid]["hp"])
		var old_pwr: int = int(pre_stats[uuid]["pwr"])
		var new_hp: int = inst.current_hp
		var new_pwr: int = inst.current_pwr
		var delta_hp: int = new_hp - old_hp
		var delta_pwr: int = new_pwr - old_pwr

		if delta_hp == 0 and delta_pwr == 0:
			continue

		pre_stats_override[uuid] = pre_stats[uuid].duplicate(true)

		if delta_hp > 0 and delta_pwr > 0:
			var both_payload := CombatPayload.both_stats_change(
				uuid, delta_hp, delta_pwr, [old_hp], [new_hp], [old_pwr], [new_pwr]
			)
			both_payload.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
			extra_events.append(_make_stat_event(CombatEvent.Type.BUFF, uuid, both_payload, C.ACTION_BUFF, true))
			_fire_stat_trigger(C.TRIGGER_ON_STAT_INCREASED, uuid, "hp", delta_hp, true)
			_fire_stat_trigger(C.TRIGGER_ON_STAT_INCREASED, uuid, "pwr", delta_pwr, true)
		elif delta_hp < 0 and delta_pwr < 0:
			var both_payload := CombatPayload.both_stats_change(
				uuid, delta_hp, delta_pwr, [old_hp], [new_hp], [old_pwr], [new_pwr]
			)
			both_payload.action_type = C.ACTION_DEBUFF
			both_payload.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
			extra_events.append(_make_stat_event(CombatEvent.Type.DEBUFF, uuid, both_payload, C.ACTION_DEBUFF, true))
			_fire_stat_trigger(C.TRIGGER_ON_STAT_DECREASED, uuid, "hp", abs(delta_hp), true)
			_fire_stat_trigger(C.TRIGGER_ON_STAT_DECREASED, uuid, "pwr", abs(delta_pwr), true)
		else:
			if delta_hp > 0:
				var hp_payload := CombatPayload.hp_buff(uuid, delta_hp, [old_hp], [new_hp])
				hp_payload.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
				extra_events.append(_make_stat_event(CombatEvent.Type.BUFF, uuid, hp_payload, C.ACTION_BUFF, true))
				_fire_stat_trigger(C.TRIGGER_ON_STAT_INCREASED, uuid, "hp", delta_hp, true)
			elif delta_hp < 0:
				var hp_payload := CombatPayload.hp_debuff(uuid, abs(delta_hp), [old_hp], [new_hp])
				hp_payload.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
				extra_events.append(_make_stat_event(CombatEvent.Type.DEBUFF, uuid, hp_payload, C.ACTION_DEBUFF, true))
				_fire_stat_trigger(C.TRIGGER_ON_STAT_DECREASED, uuid, "hp", abs(delta_hp), true)

			if delta_pwr > 0:
				var pwr_payload := CombatPayload.pwr_buff(uuid, delta_pwr, [old_pwr], [new_pwr])
				pwr_payload.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
				extra_events.append(_make_stat_event(CombatEvent.Type.BUFF, uuid, pwr_payload, C.ACTION_BUFF, true))
				_fire_stat_trigger(C.TRIGGER_ON_STAT_INCREASED, uuid, "pwr", delta_pwr, true)
			elif delta_pwr < 0:
				var pwr_payload := CombatPayload.pwr_debuff(uuid, abs(delta_pwr), [old_pwr], [new_pwr])
				extra_events.append(_make_stat_event(CombatEvent.Type.DEBUFF, uuid, pwr_payload, C.ACTION_DEBUFF, false))
				_fire_stat_trigger(C.TRIGGER_ON_STAT_DECREASED, uuid, "pwr", abs(delta_pwr), false)

	return {
		"events": extra_events,
		"pre_stats": pre_stats_override
	}


static func _make_stat_event(event_type: CombatEvent.Type, uuid: String, payload: CombatPayload, action_type: StringName, is_conditional: bool) -> CombatEvent:
	var data: Dictionary = {
		"source_uuid": uuid,
		"target_uuids": [uuid],
		"ability_holder_uuid": uuid,
		"visual_payload": payload,
		"action_type": action_type
	}
	if is_conditional:
		data["buff_subgroup"] = C.BUFF_SUBGROUP_CONDITIONAL
	return CombatEvent.new(event_type, data)


static func _fire_stat_trigger(trigger_type: StringName, uuid: String, stat_name: String, amount: int, is_conditional: bool) -> void:
	var ctx := TriggerContext.new()
	ctx.unit_uuid = uuid
	ctx.triggering_uuid = uuid
	ctx.source_uuid = uuid
	ctx.stat = stat_name
	ctx.amount = amount
	ctx.is_simulation = true
	if is_conditional:
		ctx.is_stackable = false
		ctx.buff_subgroup = C.BUFF_SUBGROUP_CONDITIONAL
	AbilityResolver.process_trigger(trigger_type, ctx)

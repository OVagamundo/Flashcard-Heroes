# res://scripts/battle/AuraEvaluator.gd
class_name AuraEvaluator
extends RefCounted

## Single source of truth for continuous derived stat auras across combat,
## merging, transforms, trinket removal, and inspection tooltips.
## Pure simulation class (zero SceneTree / SignalBus / UI dependencies).

const C = preload("res://scripts/Constants.gd")

const KIND_RUSTY_RING: StringName = &"RUSTY_RING"
const KIND_INSIGNIA: StringName = &"INSIGNIA"
const KIND_TWIN_CHARM: StringName = &"TWIN_CHARM"
const KIND_DOPPLEGANGER: StringName = &"DOPPLEGANGER"
const KIND_SLIME_CELL: StringName = &"SLIME_CELL"
const KIND_GOLDEN_SEAL: StringName = &"GOLDEN_SEAL"
const KIND_TEMPLAR_TOKENS: StringName = &"TEMPLAR_TOKENS"


class ReconcileResult:
	extends RefCounted
	var changed: bool = false
	var delta_hp: int = 0
	var delta_pwr: int = 0
	var old_hp: int = 0
	var new_hp: int = 0
	var old_pwr: int = 0
	var new_pwr: int = 0


static func make_key(prefix: StringName, discriminator: String = "") -> StringName:
	if discriminator.is_empty():
		return prefix
	return StringName("%s:%s" % [String(prefix), discriminator])


## Reconciles a unit's materialized contribution for `aura_key` to `(target_hp, target_pwr)`.
## Computes exact deltas against `unit.active_auras[aura_key]` and applies them with
## `merge_source_type = &"AURA"` so merges and transforms automatically exclude continuous auras.
static func reconcile_aura(
	unit: GachaBallInstance,
	aura_key: StringName,
	target_hp: int,
	target_pwr: int,
	source_uuid: String,
	aura_kind: StringName,
	options: Dictionary = {},
	battle_manager: Node = null
) -> ReconcileResult:
	assert(is_instance_valid(unit), "AuraEvaluator.reconcile_aura: unit must be valid")
	var res := ReconcileResult.new()
	res.old_hp = unit.current_hp
	res.old_pwr = unit.current_pwr

	var prev_hp: int = unit.get_aura_hp(aura_key)
	var prev_pwr: int = unit.get_aura_pwr(aura_key)
	var keep_registered: bool = bool(options.get("keep_registered", false))
	var silent: bool = bool(options.get("silent", true))
	var emit_stat_triggers: bool = bool(options.get("emit_stat_triggers", false))

	if target_hp == 0 and target_pwr == 0 and not keep_registered:
		unit.erase_aura_record(aura_key)
	else:
		var existing: Dictionary = unit.get_aura(aura_key)
		var meta: Dictionary = existing.get("meta", {}).duplicate(true)
		if options.has("meta") and options["meta"] is Dictionary:
			meta.merge(options["meta"] as Dictionary, true)
		unit.set_aura_record(aura_key, {
			"hp": target_hp,
			"pwr": target_pwr,
			"source_uuid": source_uuid,
			"aura_kind": aura_kind,
			"keep_registered": keep_registered,
			"pending_expire": bool(options.get("pending_expire", false)),
			"meta": meta,
		})

	res.delta_hp = target_hp - prev_hp
	res.delta_pwr = target_pwr - prev_pwr
	res.changed = (res.delta_hp != 0 or res.delta_pwr != 0)

	if res.delta_hp != 0:
		if emit_stat_triggers and is_instance_valid(battle_manager):
			var hp_action: StringName = C.ACTION_BUFF if res.delta_hp > 0 else C.ACTION_DEBUFF
			battle_manager.apply_stat_delta(
				unit, "hp", res.delta_hp, source_uuid, hp_action, false,
				&"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL
			)
		else:
			unit.apply_hp_delta(res.delta_hp, {
				"silent": silent,
				"merge_source_type": &"AURA",
			})

	if res.delta_pwr != 0:
		if emit_stat_triggers and is_instance_valid(battle_manager):
			var pwr_action: StringName = C.ACTION_BUFF if res.delta_pwr > 0 else C.ACTION_DEBUFF
			battle_manager.apply_stat_delta(
				unit, "pwr", res.delta_pwr, source_uuid, pwr_action, false,
				&"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL
			)
		else:
			unit.apply_pwr_delta(res.delta_pwr, {
				"silent": silent,
				"merge_source_type": &"AURA",
			})

	res.new_hp = unit.current_hp
	res.new_pwr = unit.current_pwr
	return res


## Removes all active auras originating from `source_uuid` across all battle instances.
static func clear_auras_for_source(source_uuid: String, all_instances: Dictionary, silent: bool = false) -> void:
	if source_uuid.is_empty():
		return
	for uuid: Variant in all_instances:
		var unit: GachaBallInstance = all_instances[uuid] as GachaBallInstance
		if not is_instance_valid(unit) or unit.active_auras.is_empty():
			continue
		var keys_to_clear: Array[StringName] = []
		for aura_key: Variant in unit.active_auras.keys():
			var rec: Dictionary = unit.active_auras[aura_key]
			if String(rec.get("source_uuid", "")) == source_uuid:
				keys_to_clear.append(StringName(aura_key))
		for aura_key: StringName in keys_to_clear:
			var rec: Dictionary = unit.get_aura(aura_key)
			reconcile_aura(
				unit, aura_key, 0, 0, source_uuid,
				StringName(rec.get("aura_kind", &"")),
				{"keep_registered": false, "silent": silent}
			)


## Generic level-up merge aura continuity:
## Inspects active auras on `instance_a` and `instance_b` and cleanly transfers or schedules
## expiry on `merged_instance` without hardcoding trinket/unit compensation in MergeManager.
static func prepare_level_up_auras(
	instance_a: GachaBallInstance,
	instance_b: GachaBallInstance,
	merged_instance: GachaBallInstance,
	all_instances_db: Dictionary,
	has_incoming_equipment: bool = false
) -> void:
	var combined_auras: Dictionary = {}
	if is_instance_valid(instance_b):
		for aura_key: Variant in instance_b.active_auras.keys():
			combined_auras[StringName(aura_key)] = (instance_b.active_auras[aura_key] as Dictionary).duplicate(true)
	if is_instance_valid(instance_a):
		for aura_key: Variant in instance_a.active_auras.keys():
			var key_sn: StringName = StringName(aura_key)
			var rec_a: Dictionary = (instance_a.active_auras[aura_key] as Dictionary).duplicate(true)
			if combined_auras.has(key_sn):
				var rec_b: Dictionary = combined_auras[key_sn]
				if int(rec_b.get("hp", 0)) > int(rec_a.get("hp", 0)):
					rec_a["hp"] = rec_b["hp"]
				if int(rec_b.get("pwr", 0)) > int(rec_a.get("pwr", 0)):
					rec_a["pwr"] = rec_b["pwr"]
			combined_auras[key_sn] = rec_a

	for aura_key: StringName in combined_auras.keys():
		var rec: Dictionary = combined_auras[aura_key]
		var aura_kind: StringName = StringName(rec.get("aura_kind", &""))
		var source_uuid: String = String(rec.get("source_uuid", ""))
		var meta: Dictionary = rec.get("meta", {})
		var parent_hp: int = int(rec.get("hp", 0))
		var parent_pwr: int = int(rec.get("pwr", 0))

		match aura_kind:
			KIND_RUSTY_RING:
				var has_equip: bool = has_incoming_equipment or _unit_has_equipment(merged_instance)
				var target_hp: int = 0 if has_equip else int(meta.get("hp_amount", 1))
				var target_pwr: int = 0 if has_equip else int(meta.get("pwr_amount", 1))
				reconcile_aura(merged_instance, aura_key, target_hp, target_pwr, source_uuid, KIND_RUSTY_RING, {
					"keep_registered": true,
					"silent": true,
					"meta": meta,
				})

			KIND_INSIGNIA:
				var target_level: int = int(meta.get("target_level", 0))
				var target_tier: int = int(meta.get("target_tier", 0))
				var target_trait: String = String(meta.get("target_trait", ""))
				if target_trait.is_empty() and target_tier == 0 and target_level > 0 and merged_instance.level != target_level:
					# Level-bound insignia (e.g. Apprentice L1 -> L2, Veteran L2 -> L3):
					# Carry parent bonus into landing stats and schedule explicit expiry DEBUFF.
					if parent_hp > 0 or parent_pwr > 0:
						reconcile_aura(merged_instance, aura_key, parent_hp, parent_pwr, source_uuid, KIND_INSIGNIA, {
							"keep_registered": true,
							"pending_expire": true,
							"silent": true,
							"meta": meta,
						})

			KIND_TWIN_CHARM:
				var team: String = String(meta.get("team", _infer_team(instance_a, all_instances_db)))
				var pool_count: int = maxi(2, _count_team_unit_copies(instance_a.definition_id, team, all_instances_db))
				var post_merge_count: int = maxi(0, pool_count - 1)
				var post_merge_bonus: int = int(post_merge_count / 2)
				if post_merge_bonus < parent_pwr:
					# Pair threshold dropped (e.g. 2 -> 1): carry parent_pwr so EffectTwinCharmScaling
					# emits the explicit -1 PWR debuff on board-state-changed.
					reconcile_aura(merged_instance, aura_key, 0, parent_pwr, source_uuid, KIND_TWIN_CHARM, {
						"silent": true,
						"meta": meta,
					})
				elif post_merge_bonus > 0:
					reconcile_aura(merged_instance, aura_key, 0, post_merge_bonus, source_uuid, KIND_TWIN_CHARM, {
						"silent": true,
						"meta": meta,
					})

			KIND_DOPPLEGANGER:
				var team: String = _infer_team(instance_a, all_instances_db)
				var pool_count: int = maxi(2, _count_team_unit_copies(instance_a.definition_id, team, all_instances_db))
				var post_merge_count: int = maxi(0, pool_count - 1)
				var scale_amount: int = _get_doppleganger_scale_amount(merged_instance, all_instances_db)
				var post_merge_bonus: int = maxi(0, (post_merge_count - 1) * scale_amount)
				if post_merge_bonus > 0:
					reconcile_aura(merged_instance, aura_key, 0, post_merge_bonus, merged_instance.ball_uuid, KIND_DOPPLEGANGER, {
						"silent": true,
						"meta": meta,
					})


## Drains any aura marked `pending_expire` on `unit` after a level-up merge lands,
## stripping its stats cleanly and appending explicit DEBUFF CombatEvents when visual playback is active.
static func drain_expired_auras(unit: GachaBallInstance, out_events: Array[CombatEvent], emit_visual_events: bool) -> void:
	if not is_instance_valid(unit) or unit.active_auras.is_empty():
		return
	var expired_keys: Array[StringName] = []
	for aura_key: Variant in unit.active_auras.keys():
		var rec: Dictionary = unit.active_auras[aura_key]
		if bool(rec.get("pending_expire", false)):
			expired_keys.append(StringName(aura_key))

	for aura_key: StringName in expired_keys:
		var rec: Dictionary = unit.get_aura(aura_key).duplicate(true)
		var source_uuid: String = String(rec.get("source_uuid", ""))
		var aura_kind: StringName = StringName(rec.get("aura_kind", &""))
		var meta: Dictionary = rec.get("meta", {})
		var hp_loss: int = int(rec.get("hp", 0))
		var pwr_loss: int = int(rec.get("pwr", 0))
		var max_hp: int = unit.get_definition_base_hp()

		var res: ReconcileResult = reconcile_aura(unit, aura_key, 0, 0, source_uuid, aura_kind, {
			"keep_registered": false,
			"pending_expire": false,
			"silent": true,
		})
		if not emit_visual_events or not res.changed:
			continue

		var debuff_payload := CombatPayload.both_stats_change(
			source_uuid,
			-hp_loss,
			-pwr_loss,
			[res.old_hp],
			[res.new_hp],
			[res.old_pwr],
			[res.new_pwr],
			[max_hp]
		)
		debuff_payload.action_type = C.ACTION_DEBUFF
		var source_name: String = String(meta.get("trinket_name", "Insignia"))
		out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s bonus lost on %s (-%d HP, -%d PWR)" % [source_name, BattleHelpers.get_instance_display_name(unit), hp_loss, pwr_loss]
		}))
		out_events.append(CombatEvent.new(CombatEvent.Type.DEBUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [unit.ball_uuid],
			"ability_id": StringName(meta.get("expire_ability_id", "ability_%s_expire" % source_uuid)),
			"action_type": C.ACTION_DEBUFF,
			"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
			"ability_holder_uuid": source_uuid,
			"visual_payload": debuff_payload,
		}))


## Single-source query for UI inspection windows showing live scaling bonuses
## (e.g. Slime Cell, Doppleganger) without touching fake status_effects keys.
static func get_displayed_aura_pwr(
	unit: GachaBallInstance,
	ability_id: StringName,
	source_uuid: String,
	all_instances_db: Dictionary
) -> int:
	if not is_instance_valid(unit):
		return 0
	if ability_id == &"ability_slime_cell_scale":
		var bonus: int = unit.get_aura_pwr(make_key(&"slime_cell", source_uuid))
		if bonus > 0:
			return bonus
		var count: int = 0
		for uuid: Variant in all_instances_db:
			var inst: GachaBallInstance = all_instances_db[uuid] as GachaBallInstance
			if is_instance_valid(inst) and inst.definition_id == &"item_t2_d":
				count += 1
		return maxi(1, count)
	if ability_id == &"ability_doppleganger_scale":
		return unit.get_aura_pwr(&"doppleganger")
	return 0


static func _unit_has_equipment(unit: GachaBallInstance) -> bool:
	for eq_uuid: String in unit.equipped_item_uuids:
		if not eq_uuid.is_empty():
			return true
	return false


static func _infer_team(inst: GachaBallInstance, all_instances_db: Dictionary) -> String:
	if not is_instance_valid(inst):
		return ""
	var loc: LocationIdentifier = inst.get_location()
	if not is_instance_valid(loc):
		return ""
	var c: StringName = loc.container
	if c in [&"PlayerLineup", &"PlayerShelf", &"PlayerTrinkets", &"DiscardPile"] or String(c).begins_with("BattleInventory") or String(c).begins_with("RunInventory"):
		return "PLAYER"
	if c in [&"EnemyLineup", &"EnemyShelf", &"EnemyTrinkets", &"EnemyBanner"]:
		return "ENEMY"
	if c == C.CONTAINER_EQUIPPED_ITEM and not inst.equipped_on_uuid.is_empty():
		var holder: GachaBallInstance = all_instances_db.get(inst.equipped_on_uuid) as GachaBallInstance
		if is_instance_valid(holder):
			return _infer_team(holder, all_instances_db)
	return ""


static func _count_team_unit_copies(def_id: StringName, team: String, all_instances_db: Dictionary) -> int:
	var count: int = 0
	for uuid: Variant in all_instances_db:
		var inst: GachaBallInstance = all_instances_db[uuid] as GachaBallInstance
		if not is_instance_valid(inst) or inst.definition_id != def_id:
			continue
		var def: Resource = inst.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT":
			continue
		if _infer_team(inst, all_instances_db) == team:
			count += 1
	return count


static func _get_doppleganger_scale_amount(unit: GachaBallInstance, all_instances_db: Dictionary) -> int:
	var scale_amount: int = 2 + unit.level
	for ability: AbilityDefinition in unit.get_active_abilities(all_instances_db):
		if String(ability.id).begins_with("ability_doppleganger_scale"):
			if not ability.effects.is_empty():
				scale_amount = int(ability.effects[0].parameters.get("scale_amount", scale_amount))
			break
	return scale_amount

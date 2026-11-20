# res://scripts/battle/VisualSnapshotStore.gd
class_name VisualSnapshotStore
extends RefCounted

## Puppet-mode visual snapshot store for VCR combat playback.
## Holds the exact board state corresponding to the CURRENTLY ANIMATED VCR frame,
## stepping forward strictly as CombatEvents resolve in BattleAnimator.
## Guarantees mid-combat inspection and animator position lookups never leak
## future post-turn simulation state.

const C = preload("res://scripts/Constants.gd")

var _active: bool = false
var _snapshots: Dictionary = {} # uuid: String -> Dictionary (VisualDataAdapter schema)
var _location_index: Dictionary = {} # "ContainerTag:slot" -> uuid: String


func begin_playback(initial_snapshot: Dictionary) -> void:
	_snapshots.clear()
	_location_index.clear()
	for key: Variant in initial_snapshot.keys():
		var uuid: String = String(key)
		if uuid.begins_with("__"):
			continue
		var entry: Variant = initial_snapshot[key]
		if entry is Dictionary:
			var cloned: Dictionary = _clone_entry(entry as Dictionary)
			if not cloned.has("uuid") or String(cloned["uuid"]).is_empty():
				cloned["uuid"] = uuid
			_snapshots[uuid] = cloned
			_index_entry(uuid, cloned)
	_active = true


func end_playback() -> void:
	_active = false
	_snapshots.clear()
	_location_index.clear()


func is_active() -> bool:
	return _active


func has_uuid(uuid: String) -> bool:
	return _active and _snapshots.has(uuid)


func get_snapshot_by_uuid(uuid: String) -> Dictionary:
	if not _active or not _snapshots.has(uuid):
		return {}
	return _snapshots[uuid]


func get_uuid_at_location(loc: LocationIdentifier) -> String:
	if not _active or not is_instance_valid(loc):
		return ""
	var loc_key: String = _make_location_key(loc.container, loc.index)
	return String(_location_index.get(loc_key, ""))


func get_snapshot_by_location(loc: LocationIdentifier) -> Dictionary:
	var uuid: String = get_uuid_at_location(loc)
	if uuid.is_empty():
		return {}
	return _snapshots.get(uuid, {})


func get_all_snapshots() -> Dictionary:
	return _snapshots


func apply_event(event: CombatEvent) -> void:
	if not _active or not is_instance_valid(event):
		return
	var payload: CombatPayload = event.visual_payload

	if is_instance_valid(payload):
		for sub: CombatEvent in payload.windup_events:
			apply_event(sub)
		for sub: CombatEvent in payload.pre_impact_events:
			apply_event(sub)
		for sub: CombatEvent in payload.contact_events:
			apply_event(sub)

	_apply_single_event(event, payload)

	if is_instance_valid(payload):
		for sub: CombatEvent in payload.impact_events:
			apply_event(sub)


func _apply_single_event(event: CombatEvent, payload: CombatPayload) -> void:
	match event.type:
		CombatEvent.Type.DAMAGE, CombatEvent.Type.DAMAGE_BURN, CombatEvent.Type.PRE_KNOCKOUT_ATTACK:
			if not is_instance_valid(payload):
				return
			for i: int in range(event.target_uuids.size()):
				var uuid: String = event.target_uuids[i]
				if not _snapshots.has(uuid):
					continue
				var snap: Dictionary = _snapshots[uuid]
				if i < payload.targets_new_hp.size():
					snap["hp"] = payload.targets_new_hp[i]
				if i < payload.targets_new_armor.size():
					_set_status(snap, &"armor", payload.targets_new_armor[i])
				if payload.apply_burn and i < payload.targets_new_burn.size():
					_set_status(snap, &"burn", payload.targets_new_burn[i])
				if payload.apply_static and i < payload.targets_new_static.size():
					_set_status(snap, &"static", payload.targets_new_static[i])
			for spikes: CombatSpikesData in payload.spikes_data_list:
				if not is_instance_valid(spikes):
					continue
				if _snapshots.has(spikes.attacker_uuid):
					var att_snap: Dictionary = _snapshots[spikes.attacker_uuid]
					att_snap["hp"] = spikes.attacker_new_hp
					if spikes.armor_consumed > 0:
						_set_status(att_snap, &"armor", spikes.new_armor)
				if _snapshots.has(spikes.defender_uuid):
					_set_status(_snapshots[spikes.defender_uuid], &"spikes", spikes.new_spikes)
			for static_ref: CombatStaticReflectionData in payload.static_reflection_data_list:
				if not is_instance_valid(static_ref):
					continue
				if _snapshots.has(static_ref.attacker_uuid):
					_set_status(_snapshots[static_ref.attacker_uuid], &"static", static_ref.attacker_new_static)
			if event.type == CombatEvent.Type.PRE_KNOCKOUT_ATTACK:
				var kamikaze_uuid: String = payload.source_uuid if not payload.source_uuid.is_empty() else event.source_uuid
				if _snapshots.has(kamikaze_uuid):
					_snapshots[kamikaze_uuid]["hp"] = 0
					_deindex_entry(kamikaze_uuid, _snapshots[kamikaze_uuid])

		CombatEvent.Type.APPLY_BURN:
			if not is_instance_valid(payload):
				return
			for i: int in range(event.target_uuids.size()):
				var uuid: String = event.target_uuids[i]
				if not _snapshots.has(uuid):
					continue
				var new_burn: int = payload.targets_new_burn[i] if i < payload.targets_new_burn.size() else (payload.targets_new_val[i] if i < payload.targets_new_val.size() else payload.new_val)
				_set_status(_snapshots[uuid], &"burn", new_burn)

		CombatEvent.Type.HEAL:
			if not is_instance_valid(payload):
				return
			for i: int in range(event.target_uuids.size()):
				var uuid: String = event.target_uuids[i]
				if _snapshots.has(uuid) and i < payload.targets_new_hp.size():
					_snapshots[uuid]["hp"] = payload.targets_new_hp[i]

		CombatEvent.Type.BUFF, CombatEvent.Type.DEBUFF:
			if not is_instance_valid(payload):
				return
			for i: int in range(event.target_uuids.size()):
				var uuid: String = event.target_uuids[i]
				if not _snapshots.has(uuid):
					continue
				var snap: Dictionary = _snapshots[uuid]
				if i < payload.targets_new_hp.size():
					snap["hp"] = payload.targets_new_hp[i]
				if i < payload.targets_new_pwr.size():
					snap["pwr"] = payload.targets_new_pwr[i]

		CombatEvent.Type.STATUS_EFFECT:
			if not is_instance_valid(payload):
				return
			var status_key: StringName = StringName(payload.stat.trim_suffix("_stacks"))
			if status_key == &"":
				return
			for i: int in range(event.target_uuids.size()):
				var uuid: String = event.target_uuids[i]
				if not _snapshots.has(uuid):
					continue
				var new_val: int = payload.targets_new_val[i] if i < payload.targets_new_val.size() else payload.new_val
				_set_status(_snapshots[uuid], status_key, new_val)

		CombatEvent.Type.PREVENT_KNOCKOUT:
			if not is_instance_valid(payload):
				return
			var saved_uuid: String = payload.saved_uuid
			if saved_uuid.is_empty() and not event.target_uuids.is_empty():
				saved_uuid = event.target_uuids[0]
			if _snapshots.has(saved_uuid):
				var restored_hp: int = payload.new_hp if payload.new_hp > 0 else maxi(1, payload.heal_amount)
				_snapshots[saved_uuid]["hp"] = restored_hp

		CombatEvent.Type.KNOCKOUT:
			for uuid: String in event.target_uuids:
				if _snapshots.has(uuid):
					var snap: Dictionary = _snapshots[uuid]
					snap["hp"] = 0
					_deindex_entry(uuid, snap)

		CombatEvent.Type.SUMMON:
			if not is_instance_valid(payload):
				return
			if not payload.old_unit_uuid.is_empty() and _snapshots.has(payload.old_unit_uuid):
				_deindex_entry(payload.old_unit_uuid, _snapshots[payload.old_unit_uuid])
			if not payload.new_unit_uuid.is_empty() and not payload.new_unit_snapshot.is_empty():
				var new_snap: Dictionary = _clone_entry(payload.new_unit_snapshot)
				new_snap["uuid"] = payload.new_unit_uuid
				if is_instance_valid(payload.old_unit_location):
					new_snap["container_tag"] = payload.old_unit_location.container
					new_snap["slot_index"] = payload.old_unit_location.index
				_snapshots[payload.new_unit_uuid] = new_snap
				_index_entry(payload.new_unit_uuid, new_snap)

		CombatEvent.Type.DRAW:
			if not is_instance_valid(payload) or payload.draw_result == null:
				return
			var draw_res: InventoryOperations.DrawResult = payload.draw_result
			if not draw_res.drawn_uuid.is_empty() and not payload.new_unit_snapshot.is_empty():
				var draw_snap: Dictionary = _clone_entry(payload.new_unit_snapshot)
				draw_snap["uuid"] = draw_res.drawn_uuid
				draw_snap["container_tag"] = draw_res.dest_container
				draw_snap["slot_index"] = draw_res.dest_slot
				_snapshots[draw_res.drawn_uuid] = draw_snap
				_index_entry(draw_res.drawn_uuid, draw_snap)

		CombatEvent.Type.TRANSFORM:
			if not is_instance_valid(payload):
				return
			if not payload.old_unit_uuid.is_empty() and _snapshots.has(payload.old_unit_uuid):
				_deindex_entry(payload.old_unit_uuid, _snapshots[payload.old_unit_uuid])
			if not payload.new_unit_uuid.is_empty() and not payload.new_unit_snapshot.is_empty():
				var trans_snap: Dictionary = _clone_entry(payload.new_unit_snapshot)
				trans_snap["uuid"] = payload.new_unit_uuid
				if is_instance_valid(payload.old_unit_location):
					trans_snap["container_tag"] = payload.old_unit_location.container
					trans_snap["slot_index"] = payload.old_unit_location.index
				_snapshots[payload.new_unit_uuid] = trans_snap
				_index_entry(payload.new_unit_uuid, trans_snap)

		CombatEvent.Type.MERGE:
			if not is_instance_valid(payload):
				return
			for parent_uuid: String in payload.merge_parent_uuids:
				if _snapshots.has(parent_uuid):
					_deindex_entry(parent_uuid, _snapshots[parent_uuid])
			if not payload.new_unit_uuid.is_empty() and not payload.new_unit_snapshot.is_empty():
				var merge_snap: Dictionary = _clone_entry(payload.new_unit_snapshot)
				merge_snap["uuid"] = payload.new_unit_uuid
				_snapshots[payload.new_unit_uuid] = merge_snap
				_index_entry(payload.new_unit_uuid, merge_snap)

		CombatEvent.Type.MOVE:
			if not is_instance_valid(payload):
				return
			var moved_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else event.source_uuid
			if not moved_uuid.is_empty() and _snapshots.has(moved_uuid):
				var snap: Dictionary = _snapshots[moved_uuid]
				_deindex_entry(moved_uuid, snap)
				snap["container_tag"] = payload.container_tag
				snap["slot_index"] = payload.slot_index
				_index_entry(moved_uuid, snap)

		CombatEvent.Type.ITEM_EQUIP:
			if not is_instance_valid(payload):
				return
			var target_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else event.source_uuid
			if _snapshots.has(target_uuid) and not payload.item_uuid.is_empty():
				var equipped: Array = _snapshots[target_uuid].get("equipped_items", [])
				var already_present: bool = false
				for item_entry: Variant in equipped:
					if item_entry is Dictionary and String(item_entry.get("uuid", "")) == payload.item_uuid:
						already_present = true
						break
				if not already_present:
					var item_snap: Dictionary = _snapshots.get(payload.item_uuid, {})
					equipped.append({
						"uuid": payload.item_uuid,
						"icon": payload.item_icon,
						"definition_id": item_snap.get("definition_id", &"")
					})
					_snapshots[target_uuid]["equipped_items"] = equipped
				if _snapshots.has(payload.item_uuid):
					_snapshots[payload.item_uuid]["equipped_on_uuid"] = target_uuid

		CombatEvent.Type.ITEM_TRANSFER:
			if not is_instance_valid(payload):
				return
			var from_uuid: String = event.source_uuid
			var to_uuid: String = event.target_uuids[0] if not event.target_uuids.is_empty() else ""
			var transferred_entry: Dictionary = {}
			if _snapshots.has(from_uuid):
				var src_items: Array = _snapshots[from_uuid].get("equipped_items", [])
				for idx: int in range(src_items.size() - 1, -1, -1):
					var entry: Variant = src_items[idx]
					if entry is Dictionary and String(entry.get("uuid", "")) == payload.item_uuid:
						transferred_entry = entry as Dictionary
						src_items.remove_at(idx)
						break
			if _snapshots.has(to_uuid):
				var dst_items: Array = _snapshots[to_uuid].get("equipped_items", [])
				if not payload.replaced_item_uuid.is_empty():
					for idx: int in range(dst_items.size() - 1, -1, -1):
						var entry: Variant = dst_items[idx]
						if entry is Dictionary and String(entry.get("uuid", "")) == payload.replaced_item_uuid:
							dst_items.remove_at(idx)
							break
				if transferred_entry.is_empty() and not payload.item_uuid.is_empty():
					var item_snap: Dictionary = _snapshots.get(payload.item_uuid, {})
					transferred_entry = {
						"uuid": payload.item_uuid,
						"icon": payload.item_icon,
						"definition_id": item_snap.get("definition_id", &"")
					}
				if not transferred_entry.is_empty():
					dst_items.append(transferred_entry)
					_snapshots[to_uuid]["equipped_items"] = dst_items
				if _snapshots.has(payload.item_uuid):
					_snapshots[payload.item_uuid]["equipped_on_uuid"] = to_uuid
				if not payload.replaced_item_uuid.is_empty() and _snapshots.has(payload.replaced_item_uuid):
					_snapshots[payload.replaced_item_uuid]["equipped_on_uuid"] = ""

		CombatEvent.Type.ITEM_DISCARD:
			if not is_instance_valid(payload):
				return
			var holder_uuid: String = event.source_uuid
			if _snapshots.has(holder_uuid):
				var holder_items: Array = _snapshots[holder_uuid].get("equipped_items", [])
				for idx: int in range(holder_items.size() - 1, -1, -1):
					var entry: Variant = holder_items[idx]
					if entry is Dictionary and String(entry.get("uuid", "")) == payload.item_uuid:
						holder_items.remove_at(idx)
						break


## Materialize a frozen, read-only GachaBallInstance representing the exact
## state of `uuid` at the current VCR playback frame.
func build_preview_instance(uuid: String) -> GachaBallInstance:
	if not _active or not _snapshots.has(uuid):
		return null
	return _materialize_snapshot(uuid, _snapshots[uuid])


## Materialize the entire current VCR board snapshot as a uuid -> GachaBallInstance map
## for read-only mid-combat inspection windows (zero live BattleManager reads).
func build_preview_db() -> Dictionary:
	var db: Dictionary = {}
	if not _active:
		return db
	for uuid_key: Variant in _snapshots.keys():
		var uuid: String = String(uuid_key)
		var inst: GachaBallInstance = _materialize_snapshot(uuid, _snapshots[uuid])
		if is_instance_valid(inst):
			db[uuid] = inst
	return db


func _materialize_snapshot(uuid: String, snap: Dictionary) -> GachaBallInstance:
	var def_id: StringName = StringName(snap.get("definition_id", &""))
	if def_id == &"":
		return null
	var def: Resource = Database.get_definition(def_id)
	if not is_instance_valid(def):
		return null

	var inst := GachaBallInstance.new()
	if def is TrinketDefinition:
		inst.initialize_from_trinket(def as TrinketDefinition)
	elif def is GachaBallDefinition:
		inst.initialize(def as GachaBallDefinition)
	else:
		return null

	inst.ball_uuid = uuid
	inst.origin_uuid = String(snap.get("origin_uuid", ""))
	inst.current_hp = int(snap.get("hp", inst.current_hp))
	inst.current_pwr = int(snap.get("pwr", inst.current_pwr))
	var attrs: Variant = snap.get("attributes", {})
	if attrs is Dictionary and attrs.has("level"):
		inst.level = maxi(1, int(attrs["level"]))

	inst.dynamic_tags.clear()
	var dyn_tags: Variant = snap.get("dynamic_tags", [])
	if dyn_tags is Array:
		for tag_val: Variant in dyn_tags:
			inst.dynamic_tags.append(StringName(tag_val))

	inst.components.clear()
	var snap_components: Variant = snap.get("components", [])
	if snap_components is Array:
		for comp_val: Variant in snap_components:
			if comp_val is GachaBallComponent:
				inst.components.append((comp_val as GachaBallComponent).duplicate(true) as GachaBallComponent)

	inst.battle_components.clear()
	var snap_battle_components: Variant = snap.get("battle_components", [])
	if snap_battle_components is Array:
		for comp_val: Variant in snap_battle_components:
			if comp_val is GachaBallComponent:
				inst.battle_components.append((comp_val as GachaBallComponent).duplicate(true) as GachaBallComponent)

	inst.status_effects.clear()
	var statuses: Variant = snap.get("status_effects", {})
	if statuses is Dictionary:
		for s_key: Variant in (statuses as Dictionary).keys():
			var amount: int = int(statuses[s_key])
			if amount != 0:
				inst.status_effects[StringName(s_key)] = amount

	inst.active_auras.clear()
	var auras: Variant = snap.get("active_auras", {})
	if auras is Dictionary:
		for a_key: Variant in (auras as Dictionary).keys():
			var a_val: Variant = auras[a_key]
			if a_val is Dictionary:
				inst.active_auras[StringName(a_key)] = (a_val as Dictionary).duplicate(true)

	inst.location_container_tag = StringName(snap.get("container_tag", &""))
	inst.location_slot_index = int(snap.get("slot_index", -1))
	inst.equipped_on_uuid = String(snap.get("equipped_on_uuid", ""))
	inst.equipped_slot_index = int(snap.get("equipped_slot_index", -1))

	inst.equipped_item_uuids.clear()
	var equipped: Variant = snap.get("equipped_items", [])
	if equipped is Array:
		for item_entry: Variant in equipped:
			if item_entry is Dictionary:
				var item_uuid: String = String(item_entry.get("uuid", ""))
				if not item_uuid.is_empty():
					inst.equipped_item_uuids.append(item_uuid)

	return inst


func _set_status(snap: Dictionary, status_key: StringName, new_value: int) -> void:
	var statuses: Dictionary = snap.get("status_effects", {})
	if new_value <= 0:
		statuses.erase(status_key)
		new_value = 0
	else:
		statuses[status_key] = new_value
	snap["status_effects"] = statuses
	if status_key == &"burn":
		snap["burn_stacks"] = new_value
	elif status_key == &"armor":
		snap["armor_stacks"] = new_value
	elif status_key == &"spikes":
		snap["spikes_stacks"] = new_value


func _clone_entry(entry: Dictionary) -> Dictionary:
	var copy: Dictionary = entry.duplicate(false)
	if entry.has("status_effects") and entry["status_effects"] is Dictionary:
		copy["status_effects"] = (entry["status_effects"] as Dictionary).duplicate(true)
	if entry.has("active_auras") and entry["active_auras"] is Dictionary:
		copy["active_auras"] = (entry["active_auras"] as Dictionary).duplicate(true)
	if entry.has("equipped_items") and entry["equipped_items"] is Array:
		var eq_copy: Array = []
		for item_entry: Variant in entry["equipped_items"]:
			if item_entry is Dictionary:
				eq_copy.append((item_entry as Dictionary).duplicate(false))
		copy["equipped_items"] = eq_copy
	if entry.has("attributes") and entry["attributes"] is Dictionary:
		copy["attributes"] = (entry["attributes"] as Dictionary).duplicate(true)
	if entry.has("active_tags") and entry["active_tags"] is Array:
		copy["active_tags"] = (entry["active_tags"] as Array).duplicate()
	if entry.has("dynamic_tags") and entry["dynamic_tags"] is Array:
		copy["dynamic_tags"] = (entry["dynamic_tags"] as Array).duplicate()
	if entry.has("components") and entry["components"] is Array:
		var comps_copy: Array[GachaBallComponent] = []
		for comp_val: Variant in entry["components"]:
			if comp_val is GachaBallComponent:
				comps_copy.append((comp_val as GachaBallComponent).duplicate(true) as GachaBallComponent)
		copy["components"] = comps_copy
	if entry.has("battle_components") and entry["battle_components"] is Array:
		var bcomps_copy: Array[GachaBallComponent] = []
		for comp_val: Variant in entry["battle_components"]:
			if comp_val is GachaBallComponent:
				bcomps_copy.append((comp_val as GachaBallComponent).duplicate(true) as GachaBallComponent)
		copy["battle_components"] = bcomps_copy
	return copy


func _index_entry(uuid: String, snap: Dictionary) -> void:
	var container_tag: StringName = StringName(snap.get("container_tag", &""))
	var slot_index: int = int(snap.get("slot_index", -1))
	if container_tag == &"" or container_tag == C.CONTAINER_EQUIPPED_ITEM or slot_index < 0:
		return
	_location_index[_make_location_key(container_tag, slot_index)] = uuid


func _deindex_entry(uuid: String, snap: Dictionary) -> void:
	var container_tag: StringName = StringName(snap.get("container_tag", &""))
	var slot_index: int = int(snap.get("slot_index", -1))
	if container_tag == &"" or slot_index < 0:
		return
	var loc_key: String = _make_location_key(container_tag, slot_index)
	if String(_location_index.get(loc_key, "")) == uuid:
		_location_index.erase(loc_key)


static func _make_location_key(container_tag: StringName, slot_index: int) -> String:
	return "%s:%d" % [String(container_tag), slot_index]

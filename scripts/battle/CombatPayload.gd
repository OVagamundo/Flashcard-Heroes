class_name CombatPayload
extends RefCounted

const C = preload("res://scripts/Constants.gd")

## Typed, presentation-only data carried by a CombatEvent.
##
## Every field below corresponds to a former visual_payload dictionary key.  A
## payload is intentionally sparse: a DAMAGE event only fills damage fields,
## while a SUMMON event only fills summon fields.  This preserves the old
## optional-field behaviour without allowing misspelled dynamic keys.

# Semantic action classification
var action_type: StringName = &""

# Shared stat / damage fields.
var source_uuid: String = ""
var amount: int = 0
var stat: String = ""
var skip_bump: bool = false
var bump_direction: Vector2 = Vector2.ZERO
var apply_burn: bool = false
var is_burn_damage: bool = false
var attack_type: String = "melee"
var main_target_uuid: String = ""
var original_target_uuid: String = ""
var original_target_uuids: Array[String] = []
var projectile: CombatProjectile

var targets_old_hp: Array[int] = []
var targets_new_hp: Array[int] = []
var targets_max_hp: Array[int] = []
var targets_old_pwr: Array[int] = []
var targets_new_pwr: Array[int] = []
var targets_old_burn: Array[int] = []
var targets_new_burn: Array[int] = []
var targets_old_armor: Array[int] = []
var targets_new_armor: Array[int] = []
var armor_consumed: Array[int] = []
var targets_old_val: Array[int] = []
var targets_new_val: Array[int] = []
var new_hp: int = 0
var new_pwr: int = 0
var new_val: int = 0
var old_hp: int = 0
var old_pwr: int = 0
var hp_amount: int = 0
var pwr_amount: int = 0
var status_color: Color = Color.WHITE
var is_status_damage: bool = false
var old_value: int = 0
var new_value: int = 0
var spikes_data_list: Array[CombatSpikesData] = []

# Nested animation event phases.
var windup_events: Array[CombatEvent] = []
var pre_impact_events: Array[CombatEvent] = []
var impact_events: Array[CombatEvent] = []

# Summon, transform, and draw fields.  new_unit_snapshot remains a Dictionary
# because VisualDataAdapter and the view layer intentionally share that schema.
var old_unit_uuid: String = ""
var new_unit_uuid: String = ""
var old_unit_location: LocationIdentifier
var new_unit_snapshot: Dictionary = {}
var unit_snapshot: Dictionary = {}
var equipped_items: Array[Dictionary] = []
var spawn_source_uuid: String = ""
var unit_tier: int = 1
var visual_style: String = ""
var draw_result = null # InventoryOperations.DrawResult is an inner class.

# Other one-off presentation fields.
var saved_uuid: String = ""
var heal_amount: int = 1
var guardian_uuid: String = ""
var origin_uuid: String = ""
var target_gold_amount: int = -1
var target_token_amount: int = -1
var container_tag: StringName = &""
var slot_index: int = -1
var is_player: bool = false
var from_effect: StringName = &""
var to_effect: StringName = &""
var item_uuid: String = ""
var item_icon: Texture2D = null
var item_icon_path: String = ""
var item_name: String = "Item"
var message: String = ""
var merge_parent_uuids: Array[String] = []
var merge_recipe_id: StringName = &""

static func merge_payload(p_source_uuid: String, p_target_uuid: String, p_new_unit_uuid: String, p_new_snapshot: Dictionary, p_recipe_id: StringName = &"") -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.new_unit_uuid = p_new_unit_uuid
	payload.merge_parent_uuids = [p_source_uuid, p_target_uuid]
	payload.new_unit_snapshot = p_new_snapshot
	payload.merge_recipe_id = p_recipe_id
	payload.action_type = &"MERGE"
	return payload

static func hp_change(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = [], p_targets_max_hp: Array = []) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = "hp"
	payload.targets_old_hp.assign(p_targets_old_hp)
	payload.targets_new_hp.assign(p_targets_new_hp)
	payload.targets_max_hp.assign(p_targets_max_hp)
	payload.new_hp = payload.targets_new_hp[0] if not payload.targets_new_hp.is_empty() else 0
	return payload

static func pwr_change(p_source_uuid: String, p_amount: int, p_targets_old_pwr: Array = [], p_targets_new_pwr: Array = []) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = "pwr"
	payload.targets_old_pwr.assign(p_targets_old_pwr)
	payload.targets_new_pwr.assign(p_targets_new_pwr)
	payload.new_pwr = payload.targets_new_pwr[0] if not payload.targets_new_pwr.is_empty() else 0
	return payload

static func both_stats_change(p_source_uuid: String, p_hp_amount: int, p_pwr_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = [], p_targets_old_pwr: Array = [], p_targets_new_pwr: Array = [], p_targets_max_hp: Array = []) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_hp_amount
	payload.hp_amount = p_hp_amount
	payload.pwr_amount = p_pwr_amount
	payload.stat = "both"
	payload.targets_old_hp.assign(p_targets_old_hp)
	payload.targets_new_hp.assign(p_targets_new_hp)
	payload.targets_old_pwr.assign(p_targets_old_pwr)
	payload.targets_new_pwr.assign(p_targets_new_pwr)
	payload.targets_max_hp.assign(p_targets_max_hp)
	payload.new_hp = payload.targets_new_hp[0] if not payload.targets_new_hp.is_empty() else 0
	payload.new_pwr = payload.targets_new_pwr[0] if not payload.targets_new_pwr.is_empty() else 0
	payload.action_type = C.ACTION_BUFF
	return payload

func merge_with(next_payload: CombatPayload, target_uuids: Array[String], next_targets: Array[String]) -> void:
	for t_idx in range(next_targets.size()):
		var t_uuid = next_targets[t_idx]
		var existing_idx = target_uuids.find(t_uuid)
		
		if existing_idx >= 0:
			# Target is already in target_uuids: update its NEW values in-place (net accumulation)
			if t_idx < next_payload.targets_new_pwr.size():
				while targets_new_pwr.size() <= existing_idx:
					targets_new_pwr.append(0)
				while targets_old_pwr.size() <= existing_idx:
					targets_old_pwr.append(0)
				if t_idx < next_payload.targets_old_pwr.size() and targets_old_pwr[existing_idx] == 0:
					targets_old_pwr[existing_idx] = next_payload.targets_old_pwr[t_idx]
				targets_new_pwr[existing_idx] = next_payload.targets_new_pwr[t_idx]

			if t_idx < next_payload.targets_new_hp.size():
				while targets_new_hp.size() <= existing_idx:
					targets_new_hp.append(0)
				while targets_old_hp.size() <= existing_idx:
					targets_old_hp.append(0)
				if t_idx < next_payload.targets_old_hp.size() and targets_old_hp[existing_idx] == 0:
					targets_old_hp[existing_idx] = next_payload.targets_old_hp[t_idx]
				targets_new_hp[existing_idx] = next_payload.targets_new_hp[t_idx]

			if t_idx < next_payload.targets_max_hp.size():
				while targets_max_hp.size() <= existing_idx:
					targets_max_hp.append(0)
				targets_max_hp[existing_idx] = next_payload.targets_max_hp[t_idx]

			if t_idx < next_payload.targets_new_val.size():
				while targets_new_val.size() <= existing_idx:
					targets_new_val.append(0)
				while targets_old_val.size() <= existing_idx:
					targets_old_val.append(0)
				if t_idx < next_payload.targets_old_val.size() and targets_old_val[existing_idx] == 0:
					targets_old_val[existing_idx] = next_payload.targets_old_val[t_idx]
				targets_new_val[existing_idx] = next_payload.targets_new_val[t_idx]
		else:
			target_uuids.append(t_uuid)
			if t_idx < next_payload.targets_old_hp.size():
				targets_old_hp.append(next_payload.targets_old_hp[t_idx])
				targets_new_hp.append(next_payload.targets_new_hp[t_idx])
			if t_idx < next_payload.targets_max_hp.size():
				targets_max_hp.append(next_payload.targets_max_hp[t_idx])
			if t_idx < next_payload.targets_old_pwr.size():
				targets_old_pwr.append(next_payload.targets_old_pwr[t_idx])
				targets_new_pwr.append(next_payload.targets_new_pwr[t_idx])
			if t_idx < next_payload.targets_old_val.size():
				targets_old_val.append(next_payload.targets_old_val[t_idx])
				targets_new_val.append(next_payload.targets_new_val[t_idx])

	# Initialize amounts from original stat before stat mutation
	if stat == "hp" and hp_amount == 0:
		hp_amount = amount
	elif stat == "pwr" and pwr_amount == 0:
		pwr_amount = amount

	# Merge stat descriptors and amounts
	if stat != next_payload.stat:
		var has_hp = stat == "hp" or next_payload.stat == "hp" or stat == "both" or next_payload.stat == "both"
		var has_pwr = stat == "pwr" or next_payload.stat == "pwr" or stat == "both" or next_payload.stat == "both"
		if has_hp and has_pwr:
			stat = "both"

	if next_payload.hp_amount != 0:
		hp_amount += next_payload.hp_amount
	elif next_payload.stat == "hp":
		hp_amount += next_payload.amount

	if next_payload.pwr_amount != 0:
		pwr_amount += next_payload.pwr_amount
	elif next_payload.stat == "pwr":
		pwr_amount += next_payload.amount

	if next_payload.new_hp != 0:
		new_hp = next_payload.new_hp
	if next_payload.new_pwr != 0:
		new_pwr = next_payload.new_pwr

static func status_change(p_source_uuid: String, p_amount: int, p_stat: String, p_targets_old_val: Array = [], p_targets_new_val: Array = [], p_status_color: Color = Color.WHITE) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = p_stat
	payload.targets_old_val.assign(p_targets_old_val)
	payload.targets_new_val.assign(p_targets_new_val)
	payload.new_val = payload.targets_new_val[0] if not payload.targets_new_val.is_empty() else 0
	payload.status_color = p_status_color
	return payload

static func damage(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = [], p_targets_old_armor: Array = [], p_targets_new_armor: Array = [], p_armor_consumed: Array = []) -> CombatPayload:
	var payload := hp_change(p_source_uuid, p_amount, p_targets_old_hp, p_targets_new_hp)
	payload.action_type = C.ACTION_DAMAGE
	payload.targets_old_armor.assign(p_targets_old_armor)
	payload.targets_new_armor.assign(p_targets_new_armor)
	payload.armor_consumed.assign(p_armor_consumed)
	return payload

static func heal(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = [], p_targets_max_hp: Array = []) -> CombatPayload:
	var payload := hp_change(p_source_uuid, p_amount, p_targets_old_hp, p_targets_new_hp, p_targets_max_hp)
	payload.action_type = C.ACTION_HEAL
	return payload

static func hp_buff(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = [], p_targets_max_hp: Array = []) -> CombatPayload:
	var payload := hp_change(p_source_uuid, p_amount, p_targets_old_hp, p_targets_new_hp, p_targets_max_hp)
	payload.action_type = C.ACTION_BUFF
	return payload

static func hp_debuff(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array = [], p_targets_new_hp: Array = []) -> CombatPayload:
	var payload := hp_change(p_source_uuid, p_amount, p_targets_old_hp, p_targets_new_hp)
	payload.action_type = C.ACTION_DEBUFF
	return payload

static func pwr_buff(p_source_uuid: String, p_amount: int, p_targets_old_pwr: Array = [], p_targets_new_pwr: Array = []) -> CombatPayload:
	var payload := pwr_change(p_source_uuid, p_amount, p_targets_old_pwr, p_targets_new_pwr)
	payload.action_type = C.ACTION_BUFF
	return payload

static func pwr_debuff(p_source_uuid: String, p_amount: int, p_targets_old_pwr: Array = [], p_targets_new_pwr: Array = []) -> CombatPayload:
	var payload := pwr_change(p_source_uuid, p_amount, p_targets_old_pwr, p_targets_new_pwr)
	payload.action_type = C.ACTION_DEBUFF
	return payload

static func guardian_intercept(p_guardian_uuid: String, p_original_target_uuid: String) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.guardian_uuid = p_guardian_uuid
	payload.original_target_uuid = p_original_target_uuid
	return payload

static func container_payload(p_container_tag: StringName) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.container_tag = p_container_tag
	return payload

static func item_discard(p_source_uuid: String, p_item_uuid: String, p_icon: Texture2D = null, p_icon_path: String = "", p_item_name: String = "Item") -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.item_uuid = p_item_uuid
	payload.item_icon = p_icon
	payload.item_icon_path = p_icon_path
	payload.item_name = p_item_name
	return payload

static func item_equip(p_target_uuid: String, p_item_uuid: String, p_icon: Texture2D = null, p_icon_path: String = "", p_item_name: String = "Item") -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_target_uuid
	payload.main_target_uuid = p_target_uuid
	payload.item_uuid = p_item_uuid
	payload.item_icon = p_icon
	payload.item_icon_path = p_icon_path
	payload.item_name = p_item_name
	return payload

func deep_clone() -> CombatPayload:
	var copy := CombatPayload.new()
	copy.action_type = action_type
	copy.source_uuid = source_uuid
	copy.amount = amount
	copy.stat = stat
	copy.skip_bump = skip_bump
	copy.bump_direction = bump_direction
	copy.apply_burn = apply_burn
	copy.is_burn_damage = is_burn_damage
	copy.attack_type = attack_type
	copy.main_target_uuid = main_target_uuid
	copy.original_target_uuid = original_target_uuid
	copy.original_target_uuids = original_target_uuids.duplicate()
	copy.projectile = projectile.deep_clone() if projectile != null else null
	copy.targets_old_hp = targets_old_hp.duplicate()
	copy.targets_new_hp = targets_new_hp.duplicate()
	copy.targets_max_hp = targets_max_hp.duplicate()
	copy.targets_old_pwr = targets_old_pwr.duplicate()
	copy.targets_new_pwr = targets_new_pwr.duplicate()
	copy.targets_old_burn = targets_old_burn.duplicate()
	copy.targets_new_burn = targets_new_burn.duplicate()
	copy.targets_old_armor = targets_old_armor.duplicate()
	copy.targets_new_armor = targets_new_armor.duplicate()
	copy.armor_consumed = armor_consumed.duplicate()
	copy.targets_old_val = targets_old_val.duplicate()
	copy.targets_new_val = targets_new_val.duplicate()
	copy.new_hp = new_hp
	copy.new_pwr = new_pwr
	copy.new_val = new_val
	copy.old_hp = old_hp
	copy.old_pwr = old_pwr
	copy.hp_amount = hp_amount
	copy.pwr_amount = pwr_amount
	copy.status_color = status_color
	copy.is_status_damage = is_status_damage
	copy.old_value = old_value
	copy.new_value = new_value
	for spikes_data in spikes_data_list:
		copy.spikes_data_list.append(spikes_data.deep_clone())
	for event in windup_events:
		copy.windup_events.append(event.deep_clone())
	for event in pre_impact_events:
		copy.pre_impact_events.append(event.deep_clone())
	for event in impact_events:
		copy.impact_events.append(event.deep_clone())
	copy.old_unit_uuid = old_unit_uuid
	copy.new_unit_uuid = new_unit_uuid
	copy.old_unit_location = old_unit_location
	copy.new_unit_snapshot = new_unit_snapshot.duplicate(true)
	copy.unit_snapshot = unit_snapshot.duplicate(true)
	copy.equipped_items = equipped_items.duplicate(true)
	copy.spawn_source_uuid = spawn_source_uuid
	copy.unit_tier = unit_tier
	copy.visual_style = visual_style
	copy.draw_result = draw_result
	copy.saved_uuid = saved_uuid
	copy.heal_amount = heal_amount
	copy.guardian_uuid = guardian_uuid
	copy.origin_uuid = origin_uuid
	copy.target_gold_amount = target_gold_amount
	copy.target_token_amount = target_token_amount
	copy.container_tag = container_tag
	copy.slot_index = slot_index
	copy.is_player = is_player
	copy.from_effect = from_effect
	copy.to_effect = to_effect
	copy.item_uuid = item_uuid
	copy.item_icon = item_icon
	copy.item_icon_path = item_icon_path
	copy.item_name = item_name
	copy.message = message
	copy.merge_parent_uuids = merge_parent_uuids.duplicate()
	copy.merge_recipe_id = merge_recipe_id
	return copy

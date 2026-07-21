class_name CombatPayload
extends RefCounted

## Typed, presentation-only data carried by a CombatEvent.
##
## Every field below corresponds to a former visual_payload dictionary key.  A
## payload is intentionally sparse: a DAMAGE event only fills damage fields,
## while a SUMMON event only fills summon fields.  This preserves the old
## optional-field behaviour without allowing misspelled dynamic keys.

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
var container_tag: StringName = &""
var slot_index: int = -1
var is_player: bool = false
var from_effect: StringName = &""
var to_effect: StringName = &""
var item_uuid: String = ""
var item_icon_path: String = ""
var item_name: String = "Item"
var message: String = ""

static func hp_change(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array[int] = [], p_targets_new_hp: Array[int] = [], p_targets_max_hp: Array[int] = []) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = "hp"
	payload.targets_old_hp = p_targets_old_hp
	payload.targets_new_hp = p_targets_new_hp
	payload.targets_max_hp = p_targets_max_hp
	payload.new_hp = p_targets_new_hp[0] if not p_targets_new_hp.is_empty() else 0
	return payload

static func pwr_change(p_source_uuid: String, p_amount: int, p_targets_old_pwr: Array[int] = [], p_targets_new_pwr: Array[int] = []) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = "pwr"
	payload.targets_old_pwr = p_targets_old_pwr
	payload.targets_new_pwr = p_targets_new_pwr
	payload.new_pwr = p_targets_new_pwr[0] if not p_targets_new_pwr.is_empty() else 0
	return payload

static func status_change(p_source_uuid: String, p_amount: int, p_stat: String, p_targets_old_val: Array[int] = [], p_targets_new_val: Array[int] = [], p_status_color: Color = Color.WHITE) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.source_uuid = p_source_uuid
	payload.amount = p_amount
	payload.stat = p_stat
	payload.targets_old_val = p_targets_old_val
	payload.targets_new_val = p_targets_new_val
	payload.new_val = p_targets_new_val[0] if not p_targets_new_val.is_empty() else 0
	payload.status_color = p_status_color
	return payload

static func damage(p_source_uuid: String, p_amount: int, p_targets_old_hp: Array[int] = [], p_targets_new_hp: Array[int] = [], p_targets_old_armor: Array[int] = [], p_targets_new_armor: Array[int] = [], p_armor_consumed: Array[int] = []) -> CombatPayload:
	var payload := hp_change(p_source_uuid, p_amount, p_targets_old_hp, p_targets_new_hp)
	payload.targets_old_armor = p_targets_old_armor
	payload.targets_new_armor = p_targets_new_armor
	payload.armor_consumed = p_armor_consumed
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

func deep_clone() -> CombatPayload:
	var copy := CombatPayload.new()
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
	copy.spawn_source_uuid = spawn_source_uuid
	copy.unit_tier = unit_tier
	copy.visual_style = visual_style
	copy.draw_result = draw_result
	copy.saved_uuid = saved_uuid
	copy.heal_amount = heal_amount
	copy.guardian_uuid = guardian_uuid
	copy.origin_uuid = origin_uuid
	copy.target_gold_amount = target_gold_amount
	copy.container_tag = container_tag
	copy.slot_index = slot_index
	copy.is_player = is_player
	copy.from_effect = from_effect
	copy.to_effect = to_effect
	copy.item_uuid = item_uuid
	copy.item_icon_path = item_icon_path
	copy.item_name = item_name
	copy.message = message
	return copy

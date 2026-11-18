# res://scripts/battle/TriggerContext.gd
class_name TriggerContext
extends RefCounted

const C = preload("res://scripts/Constants.gd")

## Strongly typed payload replacing untyped dictionary contexts across all trigger
## routing, target/condition resolution, stat scaling, and EffectDefinition execution.

# --- Trigger & Execution Control Metadata ---
var trigger_type: StringName = &""
var trigger_cause: StringName = &""
var cause_id: StringName = &""
var ability_id: StringName = &""
var is_simulation: bool = false
var is_turn_initiated: bool = false
var is_counter: bool = false
var on_attack_already_triggered: bool = false
var attack_replaced: bool = false
var double_strike_executed: bool = false
var team: String = ""
var turn: int = 0
var current_day: int = -1
var gold_tens: int = -1

# --- Source / Actor / Holder Snapshot ---
var source_uuid: String = ""
var source_holder_uuid: String = ""
var source_category: StringName = &""
var source_consumable_id: StringName = &""
var consumable_uuid: String = ""
var source_pwr: int = -1
var source_hp: int = -1
var source_level: int = 1
var actor_uuid: String = ""
var triggering_uuid: String = ""

# --- Combat, Damage, Heal & Stat Modification ---
var attacker_uuid: String = ""
var defender_uuid: String = ""
var target_uuid: String = ""
var target_initial_hp: int = 0
var damaged_uuid: String = ""
var damaged_team: String = ""
var damaged_current_hp: int = 0
var damaged_category: StringName = &""
var damaged_slot_index: int = -1
var damage_taken: int = 0
var damage_dealt: int = 0
var healed_uuid: String = ""
var healer_uuid: String = ""
var heal_amount: int = 0
var unit_uuid: String = ""
var stat: String = ""
var amount: int = 0
var is_stackable: bool = true
var is_echo: bool = false
var buff_subgroup: StringName = C.BUFF_SUBGROUP_DISCRETE
var status_id: StringName = &""

# --- Knockout & Prevention (Constitutional Vocabulary) ---
var knocked_out_uuid: String = ""
var knocked_out_team: String = ""
var knocked_out_location: LocationIdentifier = null
var knocked_out_tier: int = 0
var knocked_out_definition_id: String = ""
var equipped_items: Array[Dictionary] = []
var killer_uuid: String = ""
var ally_knocked_out_uuid: String = ""
var ally_knocked_out_team: String = ""
var ally_knocked_out_location: LocationIdentifier = null
var ally_knocked_out_pwr: int = -1

# --- Summon, Board, Gacha, Merge & Economy ---
var summoned_uuid: String = ""
var summoned_team: String = ""
var entered_uuid: String = ""
var drawn_uuid: String = ""
var dest_container: StringName = &""
var dest_slot: int = -1
var tier: int = 0
var tokens_spent: int = -1
var merged_uuid: String = ""
var merged_team: String = ""
var merge_container: StringName = &""
var merge_category: StringName = &""
var merged_definition_id: StringName = &""
var bounty_target_uuids: Array[String] = []
var bounty_stacks: int = 0


## Deep-copies all fields for isolated per-request execution in CombatSimulator.
func duplicate_context() -> TriggerContext:
	var copy := TriggerContext.new()
	copy.trigger_type = trigger_type
	copy.trigger_cause = trigger_cause
	copy.cause_id = cause_id
	copy.ability_id = ability_id
	copy.is_simulation = is_simulation
	copy.is_turn_initiated = is_turn_initiated
	copy.is_counter = is_counter
	copy.on_attack_already_triggered = on_attack_already_triggered
	copy.attack_replaced = attack_replaced
	copy.double_strike_executed = double_strike_executed
	copy.team = team
	copy.turn = turn
	copy.current_day = current_day
	copy.gold_tens = gold_tens

	copy.source_uuid = source_uuid
	copy.source_holder_uuid = source_holder_uuid
	copy.source_category = source_category
	copy.source_consumable_id = source_consumable_id
	copy.consumable_uuid = consumable_uuid
	copy.source_pwr = source_pwr
	copy.source_hp = source_hp
	copy.source_level = source_level
	copy.actor_uuid = actor_uuid
	copy.triggering_uuid = triggering_uuid

	copy.attacker_uuid = attacker_uuid
	copy.defender_uuid = defender_uuid
	copy.target_uuid = target_uuid
	copy.target_initial_hp = target_initial_hp
	copy.damaged_uuid = damaged_uuid
	copy.damaged_team = damaged_team
	copy.damaged_current_hp = damaged_current_hp
	copy.damaged_category = damaged_category
	copy.damaged_slot_index = damaged_slot_index
	copy.damage_taken = damage_taken
	copy.damage_dealt = damage_dealt
	copy.healed_uuid = healed_uuid
	copy.healer_uuid = healer_uuid
	copy.heal_amount = heal_amount
	copy.unit_uuid = unit_uuid
	copy.stat = stat
	copy.amount = amount
	copy.is_stackable = is_stackable
	copy.is_echo = is_echo
	copy.buff_subgroup = buff_subgroup
	copy.status_id = status_id

	copy.knocked_out_uuid = knocked_out_uuid
	copy.knocked_out_team = knocked_out_team
	copy.knocked_out_location = knocked_out_location
	copy.knocked_out_tier = knocked_out_tier
	copy.knocked_out_definition_id = knocked_out_definition_id
	copy.equipped_items = equipped_items.duplicate(true)
	copy.killer_uuid = killer_uuid
	copy.ally_knocked_out_uuid = ally_knocked_out_uuid
	copy.ally_knocked_out_team = ally_knocked_out_team
	copy.ally_knocked_out_location = ally_knocked_out_location
	copy.ally_knocked_out_pwr = ally_knocked_out_pwr

	copy.summoned_uuid = summoned_uuid
	copy.summoned_team = summoned_team
	copy.entered_uuid = entered_uuid
	copy.drawn_uuid = drawn_uuid
	copy.dest_container = dest_container
	copy.dest_slot = dest_slot
	copy.tier = tier
	copy.tokens_spent = tokens_spent
	copy.merged_uuid = merged_uuid
	copy.merged_team = merged_team
	copy.merge_container = merge_container
	copy.merge_category = merge_category
	copy.merged_definition_id = merged_definition_id
	copy.bounty_target_uuids = bounty_target_uuids.duplicate()
	copy.bounty_stacks = bounty_stacks
	return copy


## Used by StatScaling for data-driven `.tres` scaling keys (`context_multiplier_key` / `scaling_context_key`).
## Fails fast via `assert` if an unknown key is ever authored in a resource.
func has_scaling_value(key: String) -> bool:
	match key:
		"gold_tens":
			return gold_tens >= 0
		"tokens_spent":
			return tokens_spent >= 0
		"damage_dealt", "damage_taken", "heal_amount", "amount", "knocked_out_tier", "tier", "turn":
			return true
		"current_day":
			return current_day > 0
		"source_pwr":
			return source_pwr >= 0
		"source_hp":
			return source_hp >= 0
		_:
			assert(false, "TriggerContext.has_scaling_value: unknown scaling key '%s'" % key)
			return false


func get_scaling_value(key: String) -> int:
	match key:
		"gold_tens":
			return maxi(0, gold_tens)
		"tokens_spent":
			return maxi(0, tokens_spent)
		"damage_dealt":
			return damage_dealt
		"damage_taken":
			return damage_taken
		"heal_amount":
			return heal_amount
		"amount":
			return amount
		"knocked_out_tier":
			return knocked_out_tier
		"tier":
			return tier
		"turn":
			return turn
		"current_day":
			return maxi(1, current_day)
		"source_pwr":
			return maxi(0, source_pwr)
		"source_hp":
			return maxi(0, source_hp)
		_:
			assert(false, "TriggerContext.get_scaling_value: unknown scaling key '%s'" % key)
			return 0




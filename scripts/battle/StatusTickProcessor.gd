# res://scripts/battle/StatusTickProcessor.gd
class_name StatusTickProcessor
extends RefCounted

## Pure simulation processor for turn-based status effect ticks (damage, heal,
## decay, Fire L3 Burn spread, and status-induced deaths).
## Zero SceneTree / UI / SignalBus dependencies.

const C = preload("res://scripts/Constants.gd")


## Processes a single CombatEffectDefinition status across all living lineup units.
static func process_status_turn_effect(status_def: Resource, all_units: Array, all_events: Array[CombatEvent], death_tracking: Dictionary, bm: Node) -> void:
	for unit: GachaBallInstance in all_units:
		if not is_instance_valid(unit) or not bm._is_lineup_container(unit.location_container_tag):
			continue
		if unit.current_hp <= 0:
			continue

		var stacks: int = unit.get_status_effect_amount(status_def.id)
		if stacks <= 0:
			continue

		var unit_name: String = bm._get_instance_display_name(unit)
		var status_name: String = TranslationServer.translate(status_def.display_name_key) if not status_def.display_name_key.is_empty() else String(status_def.id)

		# Apply turn effect (DAMAGE or HEAL)
		if status_def.turn_effect == "DAMAGE":
			_apply_status_damage_tick(status_def, unit, stacks, unit_name, status_name, all_events, death_tracking, bm)
		elif status_def.turn_effect == "HEAL":
			_apply_status_heal_tick(status_def, unit, stacks, unit_name, status_name, all_events, bm)

		# Apply decay
		_apply_status_decay(status_def, unit, all_events, bm)

		# Handle death from status damage
		if unit.current_hp <= 0:
			var death_team: String = "PLAYER" if bm._is_player_unit(unit) else "ENEMY"
			var death_phase: StringName = StringName(status_def.turn_phase) if not status_def.turn_phase.is_empty() and status_def.turn_phase != "NONE" else &"END_OF_TURN"
			bm._process_registered_death(unit, death_phase, death_team, all_events, death_tracking)


static func _apply_status_damage_tick(status_def: Resource, unit: GachaBallInstance, stacks: int, unit_name: String, status_name: String, all_events: Array[CombatEvent], death_tracking: Dictionary, bm: Node) -> void:
	var damage: int = int(stacks * status_def.turn_effect_multiplier)
	var old_hp: int = unit.current_hp
	var old_armor: int = unit.get_status_effect_amount(&"armor")

	var damage_result: Dictionary = bm.apply_damage(unit, damage, C.DamageType.BURN)
	var new_hp: int = int(damage_result.get("new_hp", unit.current_hp)) if not damage_result.is_empty() else unit.current_hp
	var armor_consumed: int = int(damage_result.get("armor_consumed", 0)) if not damage_result.is_empty() else 0
	var new_armor: int = int(damage_result.get("new_armor", 0)) if not damage_result.is_empty() else 0

	var max_hp: int = 0
	var unit_def: GachaBallDefinition = unit.get_definition()
	if is_instance_valid(unit_def):
		max_hp = unit_def.base_hp

	all_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s takes %d %s dmg" % [unit_name, damage, status_name]
	}))
	var status_damage_payload := CombatPayload.damage("", -damage, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
	status_damage_payload.skip_bump = true
	status_damage_payload.is_status_damage = true
	status_damage_payload.status_color = status_def.color
	status_damage_payload.targets_max_hp = [max_hp] as Array[int]
	all_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
		"source_uuid": "",
		"target_uuids": [unit.ball_uuid],
		"visual_payload": status_damage_payload
	}))
	if damage > 0:
		bm.trigger_on_hurt(unit.ball_uuid, damage, "", C.CAUSE_STATUS_EFFECT, status_def.id)
		all_events.append_array(bm._combat.process_reaction_queue(bm, death_tracking))

	# Fire L3: Spread 1 Burn to each living adjacent ally
	if status_def.id == &"burn":
		TraitRulesEngine.apply_fire_burn_tick_spread(unit, bm, all_events)


static func _apply_status_heal_tick(status_def: Resource, unit: GachaBallInstance, stacks: int, unit_name: String, status_name: String, all_events: Array[CombatEvent], bm: Node) -> void:
	var heal: int = int(stacks * status_def.turn_effect_multiplier)
	var old_hp: int = unit.current_hp
	var new_hp: int = int(bm.apply_stat_delta(unit, "hp", heal, "", C.ACTION_HEAL))
	var max_hp: int = 0
	var unit_def: GachaBallDefinition = unit.get_definition()
	if is_instance_valid(unit_def):
		max_hp = unit_def.base_hp

	all_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s heals %d from %s" % [unit_name, heal, status_name]
	}))
	all_events.append(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": "",
		"target_uuids": [unit.ball_uuid],
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal("", heal, [old_hp], [new_hp], [max_hp])
	}))


static func _apply_status_decay(status_def: Resource, unit: GachaBallInstance, all_events: Array[CombatEvent], bm: Node) -> void:
	var old_stacks: int = unit.get_status_effect_amount(status_def.id)
	var new_stacks: int = old_stacks

	var is_burn_decay_immune: bool = false
	if status_def.id == &"burn":
		var loc: LocationIdentifier = bm.get_location_for_uuid(unit.ball_uuid)
		if is_instance_valid(loc):
			if loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
				if loc.index >= 0 and loc.index < bm._state.player_slot_effects.size() and bm._state.player_slot_effects[loc.index] == &"burn":
					is_burn_decay_immune = true
			elif loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
				if loc.index >= 0 and loc.index < bm._state.enemy_slot_effects.size() and bm._state.enemy_slot_effects[loc.index] == &"burn":
					is_burn_decay_immune = true

	if not is_burn_decay_immune:
		match status_def.decay_mode:
			"HALVE":
				new_stacks = int(floor(old_stacks / 2.0))
			"DECREMENT":
				new_stacks = old_stacks - status_def.decay_amount
			"CLEAR":
				if status_def.id == &"armor":
					var reinforce_stacks: int = unit.get_status_effect_amount(&"reinforce")
					new_stacks = old_stacks if reinforce_stacks > 0 else 0
				else:
					new_stacks = 0

	if new_stacks != old_stacks:
		if new_stacks <= 0:
			unit.clear_status_effect_silent(status_def.id)
			new_stacks = 0
		else:
			var decay_delta: int = new_stacks - old_stacks
			bm.apply_stat_delta(unit, String(status_def.id) + "_stacks", decay_delta)

		var decay_payload := CombatPayload.status_change("", new_stacks - old_stacks, String(status_def.id) + "_stacks", [], [new_stacks], status_def.color)
		all_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": "",
			"target_uuids": [unit.ball_uuid],
			"visual_payload": decay_payload
		}))

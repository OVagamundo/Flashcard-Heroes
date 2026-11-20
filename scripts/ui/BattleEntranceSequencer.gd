# res://scripts/ui/BattleEntranceSequencer.gd
class_name BattleEntranceSequencer
extends RefCounted

## Presentation-layer entrance choreography for staged hero and enemy units.
## Keeps animator playback awaits and inter-unit pacing timers out of BattleManager
## while preserving strict VCR snapshot/event ordering.

const C = preload("res://scripts/Constants.gd")


## Executes entrance animation of the staged hero unit at its PlayerLineup slot.
static func execute_hero_entrance_sequence(bm: Node) -> void:
	if bm._state.staged_hero_placement.is_empty() or not is_instance_valid(bm._state.staged_hero_instance):
		return

	bm._resolve_animator()

	# 1. Capture snapshot before hero enters (hero is not yet in _battle_instances)
	var pre_snap: Dictionary = bm.get_board_snapshot()

	# 2. Atomically place staged hero and register any equipped hero items
	var hero_inst: GachaBallInstance = bm._state.place_staged_hero()
	if not is_instance_valid(hero_inst):
		return
	if OS.is_debug_build():
		bm._bm_validate_state_consistency()

	var pos: int = hero_inst.location_slot_index
	var hero_def: GachaBallDefinition = hero_inst.get_definition()
	if not is_instance_valid(hero_def):
		return

	# 3. Create standard SUMMON event (same as all other summons)
	var summon_loc := LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, pos)
	var unit_snap: Dictionary = EffectHandlers.create_unit_snapshot(hero_inst, hero_def)

	var equipped_items_data: Array = []
	for u_item_uuid: String in hero_inst.equipped_item_uuids:
		if not u_item_uuid.is_empty():
			var u_item: GachaBallInstance = bm.get_instance(u_item_uuid)
			if is_instance_valid(u_item):
				var u_def: GachaBallDefinition = u_item.get_definition()
				if is_instance_valid(u_def):
					equipped_items_data.append({
						"uuid": u_item_uuid,
						"icon": u_def.icon if "icon" in u_def else null,
						"definition_id": u_item.definition_id
					})
	if not equipped_items_data.is_empty():
		unit_snap["equipped_items"] = equipped_items_data
		unit_snap["equipped_item_icon"] = equipped_items_data[0]["icon"]

	var summon_payload: CombatPayload = EffectHandlers._make_summon_payload("", hero_inst.ball_uuid, summon_loc, unit_snap)
	var summon_event := CombatEvent.new(CombatEvent.Type.SUMMON, {
		"source_uuid": "",
		"target_uuids": [hero_inst.ball_uuid],
		"visual_payload": summon_payload
	})

	# 4. Trigger on_board_enter, on_battle_start, on_board_changed
	_trigger_unit_entrance_hooks(hero_inst.ball_uuid)

	# 5. Collect reaction events (e.g. Rusty Ring buff, Apprentice Insignia buff)
	var reaction_events: Array[CombatEvent] = bm._combat.process_reaction_queue(bm, {})
	var entrance_events: Array[CombatEvent] = [summon_event]
	entrance_events.append_array(reaction_events)

	# 6. Animate SUMMON followed by reactions via BattleAnimator
	if is_instance_valid(bm._animator):
		await bm._animator.play_turn_sequence(pre_snap, entrance_events)
	bm._emit_battle_inventory_changed()


## Executes sequential entrance of staged enemy units from Slot 4 (Backline) down to Slot 0 (Frontline).
static func execute_enemy_entrance_sequence(bm: Node) -> void:
	if bm._state.staged_enemy_placements.is_empty():
		return

	var placements: Array = bm._state.staged_enemy_placements.duplicate(true)
	bm._state.staged_enemy_placements.clear()

	# Order strictly Slot 4 (Rightmost, Backline) down to Slot 0 (Leftmost, Frontline)
	placements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("position", 0)) > int(b.get("position", 0)))

	bm._resolve_animator()

	for placement in placements:
		var unit_id: Variant = placement.get("id", placement.get("unit_id", ""))
		var unit_def: GachaBallDefinition = Database.get_definition(unit_id)
		if not is_instance_valid(unit_def):
			continue

		var pos: int = int(placement.get("position", 0))
		var enemy_inst := GachaBallInstance.new()
		enemy_inst.initialize(unit_def)

		var unit_level: int = int(placement.get("level", 1))
		if unit_level > 1:
			enemy_inst.set_unit_level(unit_level)
		var b_hp: int = int(placement.get("bonus_hp", 0))
		var b_pwr: int = int(placement.get("bonus_pwr", 0))
		if b_hp != 0 or b_pwr != 0:
			enemy_inst.apply_encounter_stat_bonus(b_hp, b_pwr)

		# 1. Capture snapshot before this unit enters
		var pre_snap: Dictionary = bm.get_board_snapshot()

		# 2. Place unit in EnemyLineup[pos] in data
		bm._state.bm_add_instance(enemy_inst, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, pos)

		# 3. Create standard SUMMON event (same as boss / elite summons)
		var summon_loc := LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, pos)
		var unit_snap: Dictionary = EffectHandlers.create_unit_snapshot(enemy_inst, unit_def)
		var summon_payload: CombatPayload = EffectHandlers._make_summon_payload("", enemy_inst.ball_uuid, summon_loc, unit_snap)
		var summon_event := CombatEvent.new(CombatEvent.Type.SUMMON, {
			"source_uuid": "",
			"target_uuids": [enemy_inst.ball_uuid],
			"visual_payload": summon_payload
		})

		# 4. Trigger on_board_enter, on_battle_start, on_board_changed
		_trigger_unit_entrance_hooks(enemy_inst.ball_uuid)

		# 5. Collect reaction events (e.g. Apprentice Insignia buff, Templar power scaling)
		var reaction_events: Array[CombatEvent] = bm._combat.process_reaction_queue(bm, {})
		var entrance_events: Array[CombatEvent] = [summon_event]
		entrance_events.append_array(reaction_events)

		# 6. Animate SUMMON followed by reactions via BattleAnimator
		if is_instance_valid(bm._animator):
			await bm._animator.play_turn_sequence(pre_snap, entrance_events)

		# 7. If unit has equipment, equip each item sequentially
		var equipment: Array = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			await _equip_staged_enemy_item(bm, enemy_inst, item_data)

		# Brief pause before next unit enters
		if bm.is_inside_tree() and is_instance_valid(bm.get_tree()):
			await AnimationConstants.create_pausable_timer(bm.get_tree(), AnimationConstants.scaled(0.15)).timeout

	# Final sync
	bm._emit_battle_inventory_changed()


static func _trigger_unit_entrance_hooks(unit_uuid: String) -> void:
	var enter_ctx := TriggerContext.new()
	enter_ctx.entered_uuid = unit_uuid
	AbilityResolver.process_trigger(C.TRIGGER_ON_ENTER_BOARD, enter_ctx)

	var start_ctx := TriggerContext.new()
	start_ctx.source_uuid = unit_uuid
	AbilityResolver.process_trigger(C.TRIGGER_AT_BATTLE_START, start_ctx)

	var board_ctx := TriggerContext.new()
	board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)


static func _equip_staged_enemy_item(bm: Node, enemy_inst: GachaBallInstance, item_data: Variant) -> void:
	var item_id: Variant = item_data if (item_data is StringName or item_data is String) else item_data.get("id", "")
	var item_def: GachaBallDefinition = Database.get_definition(item_id)
	if not is_instance_valid(item_def):
		return

	var equip_pre_stats: Dictionary = bm._capture_all_unit_stats()
	var old_equipped_items_data: Array = bm._capture_unit_equipped_items_data(enemy_inst.ball_uuid)

	var item_inst := GachaBallInstance.new()
	item_inst.initialize(item_def)
	var equip_result: InventoryOperations.OperationResult = InventoryOperations.register_and_equip_item(bm._state, item_inst, enemy_inst.ball_uuid)
	if not equip_result.success:
		push_warning("BattleEntranceSequencer: failed to equip item %s on %s" % [item_inst.ball_uuid, enemy_inst.ball_uuid])
		return

	if OS.is_debug_build():
		bm._bm_validate_state_consistency()

	var discard_event: CombatEvent = null
	if not equip_result.replaced_item_uuid.is_empty():
		var discard_payload := CombatPayload.item_discard(
			equip_result.replaced_from_unit_uuid,
			equip_result.replaced_item_uuid,
			equip_result.replaced_item_icon,
			equip_result.replaced_item_icon_path,
			equip_result.replaced_item_name
		)
		discard_event = CombatEvent.new(CombatEvent.Type.ITEM_DISCARD, {
			"source_uuid": equip_result.replaced_from_unit_uuid,
			"target_uuids": [equip_result.replaced_item_uuid],
			"visual_payload": discard_payload
		})

	var equip_payload := CombatPayload.item_equip(
		enemy_inst.ball_uuid,
		item_inst.ball_uuid,
		item_def.icon if "icon" in item_def else null,
		item_def.icon_path if "icon_path" in item_def else "",
		item_def.name if "name" in item_def else "Item"
	)
	var equip_event := CombatEvent.new(CombatEvent.Type.ITEM_EQUIP, {
		"source_uuid": enemy_inst.ball_uuid,
		"target_uuids": [enemy_inst.ball_uuid],
		"visual_payload": equip_payload
	})

	var equip_board_ctx := TriggerContext.new()
	equip_board_ctx.is_simulation = true
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, equip_board_ctx)
	var equip_reaction_events: Array[CombatEvent] = bm._combat.process_reaction_queue(bm, {})

	var stat_data: Dictionary = bm._generate_inventory_stat_events(equip_pre_stats)
	var equip_events: Array[CombatEvent] = []
	if discard_event != null:
		equip_events.append(discard_event)
	equip_events.append(equip_event)
	equip_events.append_array(stat_data.events)
	equip_events.append_array(equip_reaction_events)

	if is_instance_valid(bm._animator):
		var eq_snapshot: Dictionary = bm.get_board_snapshot(equip_pre_stats)
		if not old_equipped_items_data.is_empty():
			eq_snapshot[enemy_inst.ball_uuid]["equipped_items"] = old_equipped_items_data
			eq_snapshot[enemy_inst.ball_uuid]["equipped_item_icon"] = old_equipped_items_data[0]["icon"]
		else:
			eq_snapshot[enemy_inst.ball_uuid]["equipped_items"] = []
			eq_snapshot[enemy_inst.ball_uuid]["equipped_item_icon"] = null
		await bm._animator.play_turn_sequence(eq_snapshot, equip_events)
	elif bm.is_inside_tree() and is_instance_valid(bm.get_tree()):
		await AnimationConstants.create_pausable_timer(bm.get_tree(), AnimationConstants.scaled(0.15)).timeout

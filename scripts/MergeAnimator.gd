extends Node

## Handles visual animations and VFX sequencing for merge operations.
## Listens to the `merge_animation_requested` signal and decouples presentation
## from the data logic in InventoryManager.

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")


func _ready() -> void:
	SignalBus.merge_animation_requested.connect(_on_merge_animation_requested)


func _on_merge_animation_requested(context: Dictionary) -> void:
	var merged_uuid: String = context.get("merged_uuid", "")
	var source_loc: LocationIdentifier = context.get("source_loc")
	var target_loc: LocationIdentifier = context.get("target_loc")
	var final_loc: LocationIdentifier = context.get("final_loc")
	var new_instance: GachaBallInstance = context.get("new_instance")
	var is_merge_encounter: bool = context.get("is_merge_encounter", false)
	var merge_encounter_cost: int = context.get("merge_encounter_cost", 0)
	var should_trigger_on_merge: bool = context.get("should_trigger_on_merge", false)

	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc) or not is_instance_valid(new_instance):
		_finish_merge_action_if_active(true)
		return

	var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager

	var source_view: Control = WindowManager.find_view_for_location(source_loc)
	var target_view: Control = WindowManager.find_view_for_location(target_loc)
	var final_view: Control = WindowManager.find_view_for_location(final_loc)
	var start_pos: Vector2 = target_view.get_global_rect().get_center() if is_instance_valid(target_view) else context.get("start_pos", Vector2.ZERO)

	_set_unit_view_visible(source_view, false)
	_set_unit_view_visible(target_view, false)

	var snapshot: Dictionary = context.get("snapshot", {})
	var reaction_events: Array = context.get("reaction_events", [])
	if snapshot.is_empty() and should_trigger_on_merge and is_instance_valid(bm):
		snapshot = bm.get_board_snapshot()

	var merge_visual_data: Dictionary = {}
	if snapshot.has(merged_uuid):
		merge_visual_data = snapshot[merged_uuid]
	else:
		var db: Dictionary = bm.get_all_instances() if is_instance_valid(bm) else (GameManager.run_state.get_all_instances() if is_instance_valid(GameManager.run_state) else {})
		merge_visual_data = VisualDataAdapter.create_visual_data(new_instance, db)

	if final_view is SlotView:
		(final_view as SlotView).set_content(merge_visual_data)
	if source_view is SlotView and source_view != final_view:
		(source_view as SlotView).set_content({})

	await get_tree().process_frame

	if not is_instance_valid(final_view):
		final_view = WindowManager.find_view_for_location(final_loc)

	_set_unit_view_visible(final_view, false)

	var vfx_ball: GachaBallView = _create_vfx_ball(new_instance, start_pos, merge_visual_data)
	if is_instance_valid(vfx_ball):
		vfx_ball.play_landing_bounce()

	Audio.play_sfx("ui_merge")

	if is_merge_encounter and merge_encounter_cost > 0:
		await _animate_merge_gold_deduction(target_loc)

	await get_tree().process_frame

	if GameManager.is_in_battle and final_loc != null and final_loc.container == C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE and not start_pos.is_zero_approx():
		vfx_ball.queue_free()
		await BattleBoardEventPresenter.animate_gachaball_to_discard(BattleAnimator, start_pos, merge_visual_data)
		SignalBus.inventory_action_completed.emit([merged_uuid])
	elif is_instance_valid(final_view) and not start_pos.is_zero_approx():
		await _animate_vfx_ball_toss(vfx_ball, final_view, new_instance)
	else:
		if is_instance_valid(vfx_ball):
			vfx_ball.queue_free()
		_set_unit_view_visible(final_view, true)
		SignalBus.emit_signal.call_deferred("inventory_action_completed", [merged_uuid])

	if is_instance_valid(bm) and (should_trigger_on_merge or not reaction_events.is_empty()):
		await get_tree().process_frame

		var typed_events: Array[CombatEvent] = []
		for ev in reaction_events:
			if ev is CombatEvent:
				typed_events.append(ev as CombatEvent)

		if not typed_events.is_empty():
			bm.enqueue_management_animation(snapshot, typed_events)
			if bm.is_animating_management_queue():
				await bm.management_animation_queue_completed
		elif bm.get_pending_reactions_size() > 0:
			await bm.resolve_management_effects_and_animate(snapshot)

	if is_instance_valid(bm):
		bm.unblock_ui_updates()

	final_view = WindowManager.find_view_for_location(final_loc)
	_set_unit_view_visible(final_view, true)
	if not GameManager.is_in_battle:
		SignalBus.run_data_changed.emit()
		SignalBus.inventory_ui_refresh_requested.emit()

	_finish_merge_action_if_active()


func _finish_merge_action_if_active(unblock_bm: bool = false) -> void:
	if unblock_bm:
		var bm: BattleManager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
		if is_instance_valid(bm):
			bm.unblock_ui_updates()
	if ActionQueue.is_busy():
		var act: GameAction = ActionQueue.get_active_action()
		if is_instance_valid(act) and (act is ConfirmMergeAction or act is MergeEncounterAction):
			ActionQueue.finish_action(act)


func _create_vfx_ball(instance: GachaBallInstance, global_pos: Vector2, visual_data_override: Dictionary = {}) -> GachaBallView:
	var visual_data: Dictionary = visual_data_override if not visual_data_override.is_empty() else VisualDataAdapter.create_visual_data(instance)
	var anim_ball: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	WindowManager.get_vfx_layer().add_child(anim_ball)
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.force_inventory_mode = not GameManager.is_in_battle
	anim_ball.show_capsule_overlay = not GameManager.is_in_battle
	anim_ball.set_size_scale(1.0)
	anim_ball.custom_minimum_size = Vector2(96.0, 96.0)
	anim_ball.size = Vector2(96.0, 96.0)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	anim_ball.global_position = global_pos - (anim_ball.size / 2.0)
	return anim_ball


func _find_ball_in_slot(slot_view: Control) -> GachaBallView:
	if not is_instance_valid(slot_view):
		return null
	for child in slot_view.get_children():
		if child is GachaBallView and not child.is_queued_for_deletion():
			return child as GachaBallView
	return null


func _set_unit_view_visible(slot_view: Control, is_visible: bool) -> void:
	if not is_instance_valid(slot_view):
		return
	for child in slot_view.get_children():
		if child is GachaBallView and not child.is_queued_for_deletion():
			(child as GachaBallView).visible = is_visible


func _animate_vfx_ball_toss(vfx_ball: GachaBallView, target_slot: Control, instance: GachaBallInstance) -> void:
	if not is_instance_valid(target_slot) or not is_instance_valid(vfx_ball):
		if is_instance_valid(vfx_ball):
			vfx_ball.queue_free()
		return

	var start_pos: Vector2 = vfx_ball.global_position + (vfx_ball.size / 2.0)
	var end_pos: Vector2 = target_slot.get_global_rect().get_center()
	var real_ball_view: GachaBallView = _find_ball_in_slot(target_slot)

	if start_pos.distance_to(end_pos) < 20.0:
		vfx_ball.queue_free()
		if is_instance_valid(real_ball_view):
			real_ball_view.visible = true
		SignalBus.inventory_action_completed.emit([instance.ball_uuid])
		await AnimationConstants.create_pausable_timer(get_tree(), AnimationConstants.scaled(0.35)).timeout
		return

	if is_instance_valid(real_ball_view):
		real_ball_view.visible = false
		target_slot.visible = true

	var arc_height: float = clampf(start_pos.distance_to(end_pos) * 0.5, 80.0, 300.0)
	Audio.play_sfx("unit_toss")

	var tween: Tween = ArcTossAnimator.toss_bezier(vfx_ball, start_pos, end_pos, {
		"arc_height": arc_height,
		"duration": 0.55,
		"ease_power": 1.05,
		"pivot": vfx_ball.size / 2.0,
	})
	await tween.finished

	if is_instance_valid(vfx_ball):
		vfx_ball.queue_free()
	real_ball_view = _find_ball_in_slot(target_slot)
	if is_instance_valid(real_ball_view):
		real_ball_view.visible = true

	SignalBus.inventory_action_completed.emit([instance.ball_uuid])
	await AnimationConstants.create_pausable_timer(get_tree(), AnimationConstants.scaled(0.35)).timeout


func _animate_merge_gold_deduction(target_loc: LocationIdentifier) -> void:
	var target_view: Control = WindowManager.find_view_for_location(target_loc)
	if not is_instance_valid(target_view):
		return
	var end_pos: Vector2 = target_view.get_global_rect().get_center()
	var cost: int = GameManager.run_state.merge_encounter_cost if is_instance_valid(GameManager.run_state) else 5
	await CurrencyAnimator.animate_gold_spend(cost, end_pos)

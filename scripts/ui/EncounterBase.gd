# res://scripts/ui/EncounterBase.gd
class_name EncounterBase
extends Control

## Shared base class for Reward, RewardElite, and Shop encounter scenes.
## Centralizes inspection-avoidance button tagging, background click routing,
## staggered GachaBall slot entry, VFX capsule arc flights (machine / trinket bar),
## reward slot selection resolution, and inventory-drawer instruction syncing.

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")
const ACTION_BUTTON_AVOID_SCOPE_META: String = "action_button_avoid_scope"

var _transient_drop_pos: Vector2 = Vector2.ZERO
var _is_first_populate: bool = true
var _last_inventory_open: bool = false


func _mark_action_buttons_for_avoidance(buttons: Array[Button], scope: StringName) -> void:
	for button: Button in buttons:
		if is_instance_valid(button):
			button.set_meta(ACTION_BUTTON_AVOID_SCOPE_META, scope)


func _handle_window_background_click(event: InputEvent) -> void:
	if not InputUtils.is_primary_pointer_press(event):
		return
	var context := InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = &"SINGLE_CLICK"
	context.location = null
	context.entity_uuid = ""
	context.entity_type = &"WINDOW_BACKGROUND"
	context.interaction_mode = &"FULLY_INTERACTIVE"
	context.window_group_id = 0
	SignalBus.interaction_context_received.emit(context)
	get_viewport().set_input_as_handled()


func _resolve_drop_interaction(is_drag: bool, mouse_pos: Vector2) -> Dictionary:
	var drop_pos: Vector2 = Vector2.ZERO
	var interaction_type: String = "CLICK"
	if is_drag:
		drop_pos = mouse_pos if not mouse_pos.is_zero_approx() else GlobalInteractionRouter.get_last_pointer_position()
		interaction_type = "DRAG"
	_transient_drop_pos = drop_pos
	return {"drop_pos": drop_pos, "interaction_type": interaction_type}


func _consume_animation_start_pos(fallback_pos: Vector2, explicit_drop_pos: Vector2) -> Vector2:
	if not explicit_drop_pos.is_zero_approx():
		return explicit_drop_pos
	if not _transient_drop_pos.is_zero_approx():
		var captured: Vector2 = _transient_drop_pos
		_transient_drop_pos = Vector2.ZERO
		return captured
	return fallback_pos


func _get_content_slot_global_center(slots_container: Control, index: int) -> Vector2:
	if index < 0 or index >= slots_container.get_child_count():
		return Vector2.ZERO
	var slot_view: Control = slots_container.get_child(index) as Control
	if not is_instance_valid(slot_view):
		return Vector2.ZERO
	var center_pos: Vector2 = slot_view.get_global_rect().get_center()
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		var content_area: Control = main_node.get_node_or_null("%ContentArea") as Control
		if is_instance_valid(content_area):
			center_pos += content_area.global_position
	return center_pos


func _get_absolute_screen_pos(pos: Vector2, vp: Viewport = null) -> Vector2:
	var target_vp: Viewport = vp if is_instance_valid(vp) else get_viewport()
	if not is_instance_valid(target_vp):
		return pos
	return target_vp.get_screen_transform() * (target_vp.get_canvas_transform() * pos)


func _map_screen_to_vfx_viewport(screen_pos: Vector2) -> Vector2:
	var vfx_layer: CanvasLayer = WindowManager.get_vfx_layer()
	if is_instance_valid(vfx_layer):
		var vp: Viewport = vfx_layer.get_viewport()
		return (vp.get_screen_transform() * vp.get_canvas_transform()).affine_inverse() * screen_pos
	return screen_pos


func _find_first_empty_trinket_slot() -> int:
	if not is_instance_valid(GameManager.run_state):
		return 0
	var trinket_container: DataContainer = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if is_instance_valid(trinket_container):
		return maxi(0, trinket_container.find_first_empty_slot())
	return 0


func _sync_reward_inventory_overlay(instruction_key: String, allow_show_instruction: bool = true) -> void:
	var is_open: bool = WindowManager.is_run_inventory_window_open()
	if is_open == _last_inventory_open:
		return
	_last_inventory_open = is_open
	var main_node: Node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		return
	if is_open:
		main_node.hide_action_instruction()
		main_node.hide_reward_drop_zones()
	else:
		var sel: InteractionContext = GlobalInteractionRouter.get_current_selection()
		var is_prize_selected: bool = sel != null and sel.location != null and sel.location.container == &"Rewards"
		if not is_prize_selected and allow_show_instruction:
			main_node.show_action_instruction(tr(instruction_key))


func _get_selected_reward_entry(instances: Array) -> Dictionary:
	var selected_ctx: InteractionContext = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null:
		return {}
	var selected_loc: LocationIdentifier = selected_ctx.location
	if not is_instance_valid(selected_loc) or selected_loc.container != &"Rewards":
		return {}
	if selected_loc.index < 0 or selected_loc.index >= instances.size():
		return {}
	var instance: GachaBallInstance = instances[selected_loc.index] as GachaBallInstance
	if not is_instance_valid(instance):
		return {}
	return {
		"location": selected_loc,
		"instance": instance,
		"uuid": instance.ball_uuid,
	}


func _resolve_reward_entry_by_uuid(instances: Array, uuid: String) -> Dictionary:
	var selected: Dictionary = _get_selected_reward_entry(instances)
	if not selected.is_empty() and selected["uuid"] == uuid:
		return selected
	for i: int in range(instances.size()):
		var inst: GachaBallInstance = instances[i] as GachaBallInstance
		if is_instance_valid(inst) and inst.ball_uuid == uuid:
			return {
				"location": LocationIdentifier.new(&"Rewards", i),
				"instance": inst,
				"uuid": uuid,
			}
	return {}


func _animate_staggered_slot_entry(slots_container: Control, p_views: Array[GachaBallView] = []) -> void:
	if _is_first_populate:
		await AnimationConstants.create_pausable_timer(get_tree(), 0.5).timeout
		_is_first_populate = false
	else:
		await get_tree().process_frame

	await get_tree().process_frame

	var targets: Array[GachaBallView] = []
	if not p_views.is_empty():
		for b: GachaBallView in p_views:
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				targets.append(b)
	else:
		for slot_view in slots_container.get_children():
			for child in slot_view.get_children():
				if child is GachaBallView and not child.is_queued_for_deletion():
					targets.append(child as GachaBallView)
					break

	for ball_index: int in range(targets.size()):
		var ball_view: GachaBallView = targets[ball_index]
		if is_instance_valid(ball_view) and is_instance_valid(ball_view.icon_rect):
			ball_view.icon_rect.pivot_offset = ball_view.icon_rect.size / 2.0
			var delay: float = ball_index * AnimationConstants.ENTRY_STAGGER_DELAY
			var wait_tween: Tween = ball_view.create_tween()
			wait_tween.tween_interval(delay)
			wait_tween.tween_callback(func() -> void:
				if is_instance_valid(ball_view):
					ball_view.visible = true
					ball_view.scale = Vector2.ONE
					ball_view.play_landing_bounce()
			)


func _spawn_vfx_gachaball(
	visual_data: Dictionary,
	size_px: Vector2 = Vector2(96, 96),
	top_level_mode: bool = true,
	inventory_mode: bool = true
) -> GachaBallView:
	var anim_ball: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	WindowManager.get_vfx_layer().add_child(anim_ball)
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.top_level = top_level_mode
	anim_ball.z_index = 100
	if inventory_mode:
		anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = size_px
	anim_ball.size = size_px
	anim_ball.populate(null, visual_data, false)
	anim_ball.pivot_offset = size_px / 2.0
	return anim_ball


func _animate_gachaball_to_machine(start_pos: Vector2, visual_data: Dictionary, tier: int) -> void:
	var main_node: Node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		await get_tree().process_frame
		return

	var machine: Control = main_node.get_gacha_machine(tier) as Control
	if not is_instance_valid(machine):
		await get_tree().process_frame
		return

	var machine_rect: Rect2 = machine.get_global_rect()
	var end_pos := Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)

	Audio.play_sfx("ui_drag_drop")
	var anim_ball: GachaBallView = _spawn_vfx_gachaball(visual_data, Vector2(96, 96), true, true)
	var tween: Tween = ArcTossAnimator.toss_bezier(anim_ball, start_pos, end_pos, {
		"arc_height": 200.0,
		"duration": 0.45,
		"ease_power": 0.55,
	})
	await tween.finished
	Audio.play_sfx("coin_land")
	anim_ball.queue_free()
	main_node.animate_machine_inventory_change(tier, 1)


func _animate_gachaball_to_trinket_bar(
	start_pos: Vector2,
	visual_data: Dictionary,
	target_slot_index: int,
	start_scale: float = 1.0,
	use_vfx_viewport_mapping: bool = false,
	inventory_mode: bool = true
) -> void:
	var main_node: Node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		await get_tree().process_frame
		return

	var trinket_bar: Control = main_node.get_node_or_null("%PlayerTrinketBar") as Control
	if not is_instance_valid(trinket_bar) or trinket_bar.get_child_count() == 0:
		await get_tree().process_frame
		return

	var clamped_idx: int = clampi(target_slot_index, 0, trinket_bar.get_child_count() - 1)
	var target_slot: SlotView = trinket_bar.get_child(clamped_idx) as SlotView
	if not is_instance_valid(target_slot):
		await get_tree().process_frame
		return

	var raw_end_pos: Vector2 = target_slot.get_global_rect().get_center()
	var end_pos: Vector2 = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(raw_end_pos, target_slot.get_viewport())) if use_vfx_viewport_mapping else raw_end_pos

	var anim_ball: GachaBallView = _spawn_vfx_gachaball(visual_data, Vector2(96, 96), true, inventory_mode)
	if not use_vfx_viewport_mapping:
		target_slot.show_empty_trinket_slot = true

	var slot_hidden: bool = false
	var toss_opts: Dictionary = {
		"arc_height": 400.0,
		"duration": 0.45,
		"ease_power": 0.55,
		"on_step": func(t: float) -> void:
			if t >= 0.85 and not slot_hidden:
				slot_hidden = true
				if is_instance_valid(target_slot):
					target_slot.show_empty_trinket_slot = false,
	}
	if not is_equal_approx(start_scale, 1.0):
		toss_opts["start_scale"] = start_scale
		toss_opts["end_scale"] = 1.0
		toss_opts["scale_curve"] = &"linear"
		toss_opts["scale_pivot_offset"] = true

	var tween: Tween = ArcTossAnimator.toss_bezier(anim_ball, start_pos, end_pos, toss_opts)
	await tween.finished
	anim_ball.queue_free()


func _finish_active_action() -> void:
	ActionQueue.finish_action(ActionQueue.get_active_action())


func _is_run_inventory_source(source_loc: LocationIdentifier) -> bool:
	return String(source_loc.container).begins_with("RunInventoryT")


func _get_selected_run_inventory_entry(units_only: bool = false) -> Dictionary:
	var selected_ctx: InteractionContext = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null:
		return {}
	var selected_loc: LocationIdentifier = selected_ctx.location
	if not is_instance_valid(selected_loc) or not _is_run_inventory_source(selected_loc):
		return {}
	var instance: GachaBallInstance = GameManager.get_instance_from_location(selected_loc)
	if not is_instance_valid(instance):
		return {}
	var definition: Resource = instance.get_definition()
	if not is_instance_valid(definition):
		return {}
	if units_only and (not (definition is GachaBallDefinition) or (definition as GachaBallDefinition).category != &"UNIT"):
		return {}
	return {
		"location": selected_loc,
		"instance": instance,
		"definition": definition,
		"uuid": instance.ball_uuid,
	}


func _resolve_run_inventory_entry_by_uuid(target_uuid: String, units_only: bool = false) -> Dictionary:
	var item_data: Dictionary = _get_selected_run_inventory_entry(units_only)
	if not item_data.is_empty() and (target_uuid.is_empty() or item_data["uuid"] == target_uuid):
		return item_data
	if not target_uuid.is_empty() and is_instance_valid(GameManager.run_state):
		var inst: GachaBallInstance = GameManager.run_state.get_instance_by_uuid(target_uuid)
		var loc: LocationIdentifier = GameManager.run_state.get_location_for_uuid(target_uuid)
		if is_instance_valid(inst) and is_instance_valid(loc):
			return {
				"uuid": target_uuid,
				"instance": inst,
				"location": loc,
				"definition": inst.get_definition(),
			}
	return {}


func _toggle_run_inventory() -> void:
	if WindowManager.is_run_inventory_window_open():
		ActionQueue.request(CloseInventoryAction.new("RUN"))
	else:
		ActionQueue.request(OpenInventoryAction.new("RUN"))


func _handle_inventory_encounter_background_click(event: InputEvent) -> void:
	if not InputUtils.is_primary_pointer_press(event):
		return
	if WindowManager.is_run_inventory_window_open() or WindowManager.is_any_inventory_window_open():
		ActionQueue.request(CloseInventoryAction.new("RUN"))
		get_viewport().set_input_as_handled()
		return
	var context := InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = &"SINGLE_CLICK"
	context.location = null
	context.entity_uuid = ""
	context.entity_type = &"GLOBAL_BACKGROUND"
	context.interaction_mode = &"FULLY_INTERACTIVE"
	context.window_group_id = 0
	SignalBus.interaction_context_received.emit(context)
	get_viewport().set_input_as_handled()


func _resolve_ball_view(anchor: Control) -> GachaBallView:
	if not is_instance_valid(anchor):
		return null
	if anchor is GachaBallView:
		return anchor as GachaBallView
	for child in anchor.get_children():
		if child is GachaBallView:
			return child as GachaBallView
	return null


func _spawn_static_vfx_gachaball(visual_data: Dictionary, pos: Vector2) -> GachaBallView:
	var anim_ball: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	WindowManager.get_vfx_layer().add_child(anim_ball)
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.force_inventory_mode = true
	anim_ball.set_size_scale(1.0)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = pos - anim_ball.pivot_offset
	return anim_ball


func _animate_vfx_ball_to_slot(vfx_ball: GachaBallView, start_pos: Vector2, target_slot: Control, ease_power: float = 0.55) -> void:
	if not is_instance_valid(vfx_ball) or not is_instance_valid(target_slot):
		if is_instance_valid(vfx_ball):
			vfx_ball.queue_free()
		return
	var end_pos: Vector2 = target_slot.get_global_rect().get_center()
	vfx_ball.z_index = RenderingServer.CANVAS_ITEM_Z_MAX

	var jump_tween: Tween = ArcTossAnimator.toss_bezier(vfx_ball, start_pos, end_pos, {
		"arc_height": 200.0,
		"duration": 0.45,
		"ease_power": ease_power,
	})
	await jump_tween.finished
	vfx_ball.queue_free()

	if is_instance_valid(target_slot):
		target_slot.visible = true
		target_slot.modulate.a = 1.0
		for child in target_slot.get_children():
			if child is Control:
				(child as Control).visible = true
				(child as Control).modulate.a = 1.0
		var ball_view: GachaBallView = _resolve_ball_view(target_slot)
		if is_instance_valid(ball_view):
			ball_view.play_landing_bounce()


func _animate_machine_token_spend(target_machine: Control, cost: int) -> void:
	var machine_rect: Rect2 = target_machine.get_global_rect()
	var target_pos := Vector2(machine_rect.get_center().x, machine_rect.position.y + machine_rect.size.y * 0.4)
	await CurrencyAnimator.animate_token_spend(cost, target_pos, func(_land_pos: Vector2) -> void:
		_play_machine_coin_land_bounce(target_machine)
	)


func _play_machine_coin_land_bounce(machine: Control) -> void:
	if not is_instance_valid(machine):
		return
	Audio.play_sfx("token_land")
	machine.pivot_offset = Vector2(machine.size.x / 2.0, machine.size.y)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(machine, "scale", Vector2(1.03, 0.97), 0.04)
	tween.tween_property(machine, "scale", Vector2(0.98, 1.02), 0.06).set_delay(0.04)
	tween.tween_property(machine, "scale", Vector2.ONE, 0.08).set_delay(0.10).set_trans(Tween.TRANS_ELASTIC)


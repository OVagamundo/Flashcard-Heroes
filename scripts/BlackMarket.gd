# res://scripts/BlackMarket.gd
extends Control

const BASE_REMOVE_COST: int = 5
const TRANSFORM_COST_GOLD: int = 5
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var title_label: Label = %TitleLabel
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var leave_button: Button = %LeaveButton

var _action_in_progress: bool = false
var _last_inventory_open: bool = false

func _ready() -> void:
	add_to_group("black_market_controller")
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	gui_input.connect(_on_gui_input)
	SignalBus.locale_changed.connect(_update_localized_text)
	SignalBus.black_market_remove_zone_activated.connect(_on_remove_requested)
	SignalBus.black_market_transform_zone_activated.connect(_on_transform_requested)
	_update_localized_text()
	set_process(true)
	call_deferred("_show_black_market_tutorial")

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	if SignalBus.black_market_remove_zone_activated.is_connected(_on_remove_requested):
		SignalBus.black_market_remove_zone_activated.disconnect(_on_remove_requested)
	if SignalBus.black_market_transform_zone_activated.is_connected(_on_transform_requested):
		SignalBus.black_market_transform_zone_activated.disconnect(_on_transform_requested)
	# Hide the BM drop zones when leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_black_market_instruction"):
			main_node.hide_black_market_instruction()
		if main_node.has_method("hide_black_market_drop_zones"):
			main_node.hide_black_market_drop_zones()

func _process(_delta: float) -> void:
	# Track inventory open state to show/hide BM drop zones
	var is_open := WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				if main_node.has_method("show_black_market_instruction"):
					main_node.show_black_market_instruction()
			else:
				if main_node.has_method("hide_black_market_instruction"):
					main_node.hide_black_market_instruction()
				if main_node.has_method("hide_black_market_drop_zones"):
					main_node.hide_black_market_drop_zones()

func _update_localized_text() -> void:
	title_label.text = tr("ui.black_market_title")
	open_inventory_button.text = tr("ui.black_market_open_inventory")
	leave_button.text = tr("ui.leave")

func _get_remove_cost() -> int:
	if not is_instance_valid(GameManager.run_state):
		return BASE_REMOVE_COST
	if GameManager.run_state.has_method("get_black_market_remove_cost"):
		return GameManager.run_state.get_black_market_remove_cost()
	return BASE_REMOVE_COST

func _is_run_inventory_source(source_loc: LocationIdentifier) -> bool:
	return String(source_loc.container).begins_with("RunInventoryT")

func _get_selected_inventory_item() -> Dictionary:
	"""Get the currently selected inventory item. Returns {location, instance, definition} or empty dict."""
	var selected_ctx = GlobalInteractionRouter.get_current_selection()
	if selected_ctx == null:
		return {}
	var selected_loc = selected_ctx.location if selected_ctx else null
	if not is_instance_valid(selected_loc):
		return {}
	if not _is_run_inventory_source(selected_loc):
		return {}
	var instance = GameManager.get_instance_from_location(selected_loc)
	if not is_instance_valid(instance):
		return {}
	var definition = instance.get_definition()
	if not is_instance_valid(definition):
		return {}
	return {
		"location": selected_loc,
		"instance": instance,
		"definition": definition,
		"uuid": instance.ball_uuid
	}

func _on_remove_requested() -> void:
	if _action_in_progress:
		return
	var item_data = _get_selected_inventory_item()
	if item_data.is_empty():
		return

	var main_node = GameManager._active_main_node
	var remove_target = main_node.get_bm_remove_zone() if is_instance_valid(main_node) and main_node.has_method("get_bm_remove_zone") else null
	var remove_cost := _get_remove_cost()
	
	# Check if enough gold first
	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < remove_cost:
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		var target = remove_target if is_instance_valid(remove_target) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		return

	_action_in_progress = true
	
	# Animate gold spend first
	var animation_target = remove_target if is_instance_valid(remove_target) else open_inventory_button
	_animate_gold_spend(remove_cost, animation_target, func():
		# Actually spend gold and remove the instance
		if GameManager.run_state.spend_gold(remove_cost):
			GameManager.run_state.remove_instance(item_data.uuid)
			if GameManager.run_state.has_method("increase_black_market_remove_cost"):
				GameManager.run_state.increase_black_market_remove_cost()

			# Clear selection
			SignalBus.emit_signal("selection_clear_requested")
			Audio.play_sfx("ui_drag_drop")
		
		_action_in_progress = false
	)

func _on_transform_requested() -> void:
	if _action_in_progress:
		return
	var item_data = _get_selected_inventory_item()
	if item_data.is_empty():
		return

	var source_definition = item_data.definition
	var source_location: LocationIdentifier = item_data.location

	var result_definition := _draw_transform_definition(source_definition.id, int(source_definition.tier))
	if not is_instance_valid(result_definition):
		return

	var main_node = GameManager._active_main_node
	var transform_target = main_node.get_bm_transform_zone() if is_instance_valid(main_node) and main_node.has_method("get_bm_transform_zone") else null
	
	# Check if enough gold first
	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < TRANSFORM_COST_GOLD:
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		var target = transform_target if is_instance_valid(transform_target) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		return

	_action_in_progress = true

	# Animate gold spend first
	var animation_target = transform_target if is_instance_valid(transform_target) else open_inventory_button
	_animate_gold_spend(TRANSFORM_COST_GOLD, animation_target, func():
		# Actually spend gold
		if not GameManager.run_state.spend_gold(TRANSFORM_COST_GOLD):
			_action_in_progress = false
			return

		# Animation starts from the Transform zone (where the user clicked/dropped)
		var start_pos := Vector2.ZERO
		if is_instance_valid(transform_target):
			start_pos = transform_target.get_global_rect().get_center()

		# Hide source view during animation
		var source_view = _find_ball_view_for_location(source_location)
		if is_instance_valid(source_view):
			source_view.visible = false
			source_view.modulate.a = 0.0

		# Remove old instance
		GameManager.run_state.remove_instance(item_data.uuid)

		# Create new instance
		var new_instance := GachaBallInstance.new()
		new_instance.initialize(result_definition)
		GameManager.run_state.add_instance(new_instance, source_location.container, source_location.index)
		GameManager.run_state.unlock_recipe_for_result(result_definition.id)

		# Clear selection
		SignalBus.emit_signal("selection_clear_requested")

		# Wait for views to update then animate
		var target_view := await _prepare_transform_target_view(source_location)
		if start_pos != Vector2.ZERO and is_instance_valid(target_view):
			await _animate_transform_to_slot(VisualDataAdapter.create_visual_data(new_instance), start_pos, target_view)
		elif is_instance_valid(target_view):
			target_view.visible = true
			target_view.modulate.a = 1.0
			if target_view.has_method("play_landing_bounce"):
				target_view.play_landing_bounce()

		_action_in_progress = false
	)

func _draw_transform_definition(source_definition_id: StringName, source_tier: int) -> GachaBallDefinition:
	var eligible: Array[GachaBallDefinition] = []
	for definition in Database.get_all_pool_definitions():
		if not is_instance_valid(definition):
			continue
		if definition.id == source_definition_id:
			continue
		if definition.tier != source_tier:
			continue
		eligible.append(definition)

	if eligible.is_empty():
		return null
	return eligible[randi() % eligible.size()]

func _find_ball_view_for_location(loc: LocationIdentifier) -> Control:
	var anchor = WindowManager.find_view_for_location(loc)
	return _resolve_ball_view(anchor)

func _resolve_ball_view(anchor: Control) -> Control:
	if not is_instance_valid(anchor):
		return null
	if anchor is GachaBallView:
		return anchor
	for child in anchor.get_children():
		if child is GachaBallView:
			return child
	return null

func _prepare_transform_target_view(target_location: LocationIdentifier) -> Control:
	await get_tree().process_frame
	var target_anchor := WindowManager.find_view_for_location(target_location)
	var target_ball_view := _resolve_ball_view(target_anchor)

	if is_instance_valid(target_ball_view):
		target_ball_view.visible = false
		target_ball_view.modulate.a = 0.0

	return target_ball_view

func _animate_transform_to_slot(visual_data: Dictionary, start_center: Vector2, target_view: Control) -> void:
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node) or not is_instance_valid(target_view):
		if is_instance_valid(target_view):
			target_view.visible = true
			target_view.modulate.a = 1.0
		return

	var end_center := target_view.get_global_rect().get_center()

	var anim_ball = GachaBallViewScene.instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)

	anim_ball.force_inventory_mode = true
	anim_ball.custom_minimum_size = Vector2(128, 128)
	anim_ball.size = Vector2(128, 128)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = start_center - anim_ball.pivot_offset

	var control_point := Vector2(
		(start_center.x + end_center.x) * 0.5,
		min(start_center.y, end_center.y) - 200.0
	)

	Audio.play_sfx("ui_drag_drop")

	var tween := anim_ball.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(t: float):
		var eased_t := pow(t, 1.05)
		var inv_t := 1.0 - eased_t
		var pos := (inv_t * inv_t * start_center) \
			+ (2.0 * inv_t * eased_t * control_point) \
			+ (eased_t * eased_t * end_center)
		anim_ball.global_position = pos - anim_ball.pivot_offset
	, 0.0, 1.0, 0.45)

	await tween.finished
	anim_ball.queue_free()

	target_view.visible = true
	target_view.modulate.a = 1.0
	if target_view.has_method("play_landing_bounce"):
		target_view.play_landing_bounce()

func _animate_gold_spend(amount: int, target_control: Control, on_complete: Callable) -> void:
	"""Animate gold coins flying from gold counter to target control"""
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		on_complete.call()
		return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		on_complete.call()
		return
	
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon):
		gold_icon = gold_group
		
	var gold_rect = gold_icon.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	var target_rect = target_control.get_global_rect()
	var end_pos = Vector2(
		target_rect.position.x + target_rect.size.x / 2,
		target_rect.position.y + target_rect.size.y / 2
	)
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		
		# Connect to trigger target reaction
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
			if is_instance_valid(target_control):
				var tween = target_control.create_tween()
				target_control.pivot_offset = target_control.size / 2.0
				tween.tween_property(target_control, "scale", Vector2(1.1, 1.1), 0.05)
				tween.tween_property(target_control, "scale", Vector2(1.0, 1.0), 0.1)
		)
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, end_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))

	# Wait for animations then call completion callback
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.45
	var wait_tween = create_tween()
	wait_tween.tween_interval(total_wait)
	wait_tween.tween_callback(on_complete)

func _show_black_market_tutorial() -> void:
	TutorialManager.show_tutorial(&"black_market_intro", [
		{
			"text": "tutorial.black_market_intro",
			"center": true
		}
	], open_inventory_button)

func _on_open_inventory_pressed() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows()
	else:
		SignalBus.emit_signal("inspect_inventory_requested")

func _on_leave_pressed() -> void:
	# Hide BM zones before leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_black_market_instruction"):
			main_node.hide_black_market_instruction()
		if main_node.has_method("hide_black_market_drop_zones"):
			main_node.hide_black_market_drop_zones()
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 0
		SignalBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

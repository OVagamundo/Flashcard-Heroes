# res://scripts/BlackMarket.gd
extends Control

const BASE_REMOVE_COST: int = 5
const TRANSFORM_COST_GOLD: int = 5
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const RejectionFeedbackScript = preload("res://scripts/vfx/RejectionFeedback.gd")
const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
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
	SignalBus.action_drop_zone_2_activated.connect(_on_remove_requested)
	SignalBus.action_drop_zone_1_activated.connect(_on_transform_requested)
	_update_localized_text()
	set_process(true)

func _exit_tree() -> void:
	if SignalBus.locale_changed.is_connected(_update_localized_text):
		SignalBus.locale_changed.disconnect(_update_localized_text)
	if SignalBus.action_drop_zone_2_activated.is_connected(_on_remove_requested):
		SignalBus.action_drop_zone_2_activated.disconnect(_on_remove_requested)
	if SignalBus.action_drop_zone_1_activated.is_connected(_on_transform_requested):
		SignalBus.action_drop_zone_1_activated.disconnect(_on_transform_requested)
	# Hide the BM drop zones when leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
		if main_node.has_method("hide_split_action_drop_zones"):
			main_node.hide_split_action_drop_zones()

func _process(_delta: float) -> void:
	# Track inventory open state to show/hide BM drop zones
	var is_open := WindowManager.is_run_inventory_window_open()
	if is_open != _last_inventory_open:
		_last_inventory_open = is_open
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node):
			if is_open:
				if main_node.has_method("show_action_instruction"):
					main_node.show_action_instruction()
			else:
				if main_node.has_method("hide_action_instruction"):
					main_node.hide_action_instruction()
				if main_node.has_method("hide_split_action_drop_zones"):
					main_node.hide_split_action_drop_zones()

func _update_localized_text() -> void:
	title_label.text = tr("ui.black_market_title")
	if description_label:
		description_label.text = tr("ui.black_market_desc")
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

func _on_remove_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var item_data = _get_selected_inventory_item()
	if item_data.is_empty():
		return

	var main_node = GameManager._active_main_node
	var remove_target = main_node.get_action_zone_2() if is_instance_valid(main_node) and main_node.has_method("get_action_zone_2") else null
	var remove_cost := _get_remove_cost()
	
	# Check if enough gold first
	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < remove_cost:
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		var target = remove_target if is_instance_valid(remove_target) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		return

	_action_in_progress = true
	
	# Determine interaction point: drop point for drag, slot center for click
	var interaction_pos = Vector2.ZERO
	if is_drag:
		interaction_pos = mouse_pos if not mouse_pos.is_zero_approx() else get_viewport().get_mouse_position()
	else:
		# Find the slot center
		var slot_view = WindowManager.find_view_for_location(item_data.location)
		if is_instance_valid(slot_view):
			interaction_pos = slot_view.get_global_rect().get_center()
	
	# Hide the gachaball in the slot IMMEDIATELY before starting gold animation
	# We only hide the child GachaBallView so the slot background remains visible
	var source_anchor = WindowManager.find_view_for_location(item_data.location)
	if is_instance_valid(source_anchor):
		for child in source_anchor.get_children():
			if child is GachaBallView:
				child.modulate.a = 0.0
				child.visible = false
				
	# Create the VFX gachaball immediately so it stays visible during the coin animation
	var visual_data = VisualDataAdapter.create_visual_data(item_data.instance)
	var vfx_ball = _create_vfx_gachaball(visual_data, interaction_pos)

	# Animate gold spend first
	_animate_gold_spend(remove_cost, interaction_pos, func():
		# Actually spend gold and remove the instance
		if GameManager.run_state.spend_gold(remove_cost):
			# Play removal animation using the already-visible VFX ball
			_animate_gachaball_removal_vfx(vfx_ball)
			
			GameManager.run_state.remove_instance(item_data.uuid)
			if GameManager.run_state.has_method("increase_black_market_remove_cost"):
				GameManager.run_state.increase_black_market_remove_cost()

			# Refresh drop zone texts dynamically
			if is_instance_valid(main_node):
				if main_node.has_method("set_action_zone_texts"):
					var transform_text = tr("ui.bm_drop_transform").format({"cost": str(TRANSFORM_COST_GOLD)})
					var remove_text = tr("ui.bm_drop_remove").format({"cost": str(_get_remove_cost())})
					main_node.set_action_zone_texts(transform_text, remove_text)
				if main_node.has_method("show_split_action_drop_zones"):
					main_node.show_split_action_drop_zones()

			# Clear selection
			SignalBus.emit_signal("selection_clear_requested")
			Audio.play_sfx("ui_drag_drop")
		
		_action_in_progress = false
	)

func _on_transform_requested(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
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
	var transform_target = main_node.get_action_zone_1() if is_instance_valid(main_node) and main_node.has_method("get_action_zone_1") else null
	
	# Check if enough gold first
	if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < TRANSFORM_COST_GOLD:
		var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
		var target = transform_target if is_instance_valid(transform_target) else open_inventory_button
		RejectionFeedbackScript.play_rejection_with_counter(target, gold_group, get_tree())
		return

	_action_in_progress = true

	# Determine interaction point: drop point for drag, slot center for click
	var interaction_pos = Vector2.ZERO
	if is_drag:
		interaction_pos = mouse_pos if not mouse_pos.is_zero_approx() else get_viewport().get_mouse_position()
	else:
		var slot_view = WindowManager.find_view_for_location(item_data.location)
		if is_instance_valid(slot_view):
			interaction_pos = slot_view.get_global_rect().get_center()

	# Hide the slot view IMMEDIATELY via modulation to prevent the 1-frame flash during refresh.
	# Using modulate.a = 0 instead of visible = false preserves the layout space (no shifting).
	var target_slot_view = WindowManager.find_view_for_location(source_location)
	if is_instance_valid(target_slot_view):
		target_slot_view.modulate.a = 0.0

	# Clean up UI states immediately
	SignalBus.emit_signal("hide_slot_indicators")
	SignalBus.emit_signal("selection_clear_requested")

	# Create the VFX gachaball immediately so it stays visible during the coin animation
	var visual_data = VisualDataAdapter.create_visual_data(item_data.instance)
	var vfx_ball = _create_vfx_gachaball(visual_data, interaction_pos)

	# Animate gold spend first
	_animate_gold_spend(TRANSFORM_COST_GOLD, interaction_pos, func():
		# Actually spend gold
		if not GameManager.run_state.spend_gold(TRANSFORM_COST_GOLD):
			_action_in_progress = false
			# Restore visibility if spend failed and remove vfx ball
			if is_instance_valid(target_slot_view):
				target_slot_view.modulate.a = 1.0
			if is_instance_valid(vfx_ball):
				vfx_ball.queue_free()
			return

		# Animation starts from the interaction point
		var start_pos = interaction_pos

		# Remove old instance
		GameManager.run_state.remove_instance(item_data.uuid)

		# Create new instance
		var new_instance := GachaBallInstance.new()
		new_instance.initialize(result_definition)
		GameManager.run_state.add_instance(new_instance, source_location.container, source_location.index)
		GameManager.run_state.unlock_recipe_for_result(result_definition.id)

		# Update the VFX ball to show the NEW transformed unit
		var new_visual_data = VisualDataAdapter.create_visual_data(new_instance)
		if is_instance_valid(vfx_ball):
			vfx_ball.populate(null, new_visual_data, false)

		# Wait for views to update then animate using the vfx_ball
		var target_view := await _prepare_transform_target_view(source_location)
		if start_pos != Vector2.ZERO and is_instance_valid(target_view):
			await _animate_transform_to_slot_vfx(vfx_ball, new_visual_data, start_pos, target_view)
		else:
			# Fallback if no target view, just cleanup vfx ball
			if is_instance_valid(vfx_ball): vfx_ball.queue_free()
			if is_instance_valid(target_view):
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
	# Wait for the InventoryWindow to rebuild the slot content after the data update
	await get_tree().process_frame
	
	var target_anchor := WindowManager.find_view_for_location(target_location)
	var target_ball_view := _resolve_ball_view(target_anchor)

	if is_instance_valid(target_ball_view):
		# Keep the newly appeared unit hidden (via alpha) until the toss animation lands
		target_ball_view.modulate.a = 0.0
	
	# Return the anchor (which is currently at modulate.a = 0)
	return target_anchor

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

	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.anchors_preset = Control.PRESET_TOP_LEFT

	anim_ball.force_inventory_mode = true
	# Use 1.0 scale (96x96) to match the inventory standard
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
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

func _animate_gachaball_removal(instance: GachaBallInstance, pos: Vector2) -> void:
	"""Animate a gachaball being removed with a death fade effect at the specified position"""
	if not is_instance_valid(instance):
		return
		
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var ball_uuid = instance.ball_uuid
	
	
func _create_vfx_gachaball(visual_data: Dictionary, pos: Vector2) -> GachaBallView:
	"""Create a static VFX gachaball at a specific screen position."""
	var anim_ball = GachaBallViewScene.instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.anchors_preset = Control.PRESET_TOP_LEFT
	
	anim_ball.force_inventory_mode = true
	anim_ball.set_size_scale(1.0)
	anim_ball.custom_minimum_size = Vector2(96, 96)
	anim_ball.size = Vector2(96, 96)
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	
	anim_ball.pivot_offset = anim_ball.size / 2.0
	anim_ball.global_position = pos - anim_ball.pivot_offset
	return anim_ball

func _animate_gachaball_removal_vfx(vfx_ball: GachaBallView) -> void:
	if not is_instance_valid(vfx_ball):
		return
		
	# Direct implementation of the "Death Fade" (levitate + fade).
	var duration = 0.6
	var levitate_height = 100.0
	
	var tween = vfx_ball.create_tween()
	tween.set_parallel(true)
	
	# Phase 1: Levitate up
	var target_pos = vfx_ball.position + Vector2(0, -levitate_height)
	tween.tween_property(vfx_ball, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Phase 2: Fade out
	tween.tween_property(vfx_ball, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Cleanup
	tween.set_parallel(false)
	tween.tween_callback(vfx_ball.queue_free)

func _animate_transform_to_slot_vfx(vfx_ball: GachaBallView, _visual_data: Dictionary, start_pos: Vector2, target_slot: Control) -> void:
	if not is_instance_valid(vfx_ball) or not is_instance_valid(target_slot):
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		return

	# Animation sequence for transformation (same as shop purchase jump)
	var end_pos = target_slot.get_global_rect().get_center()
	
	# Ensure correct z-index
	vfx_ball.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	
	var control_point = Vector2((start_pos.x + end_pos.x) / 2.0, min(start_pos.y, end_pos.y) - 200)
	var tween = vfx_ball.create_tween()
	
	tween.tween_method(func(t: float):
		var eased_t = pow(t, 1.05)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)
		vfx_ball.global_position = pos - vfx_ball.pivot_offset
	, 0.0, 1.0, 0.45)
	
	await tween.finished
	vfx_ball.queue_free()
	
	# Restore visibility of the actual view now that the animation view is gone
	if is_instance_valid(target_slot):
		target_slot.modulate.a = 1.0
		
		# Find the actual unit view to reveal and bounce
		var real_ball_view: GachaBallView = null
		for child in target_slot.get_children():
			if child is GachaBallView:
				real_ball_view = child
				break
				
		if is_instance_valid(real_ball_view):
			real_ball_view.visible = true
			real_ball_view.modulate.a = 1.0
			real_ball_view.play_landing_bounce()

func _animate_gold_spend(amount: int, target_pos: Vector2, on_complete: Callable) -> void:
	"""Animate gold coins flying from gold counter to target position"""
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
	
	var end_pos = target_pos # Already in screen coordinates
	
	# Spawn gold coins with stagger
	var coins_to_spawn = mini(amount, 5) # Cap at 5 coins for visual clarity
	var stagger_delay = 0.08
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		
		# Connect to trigger counter pop and landing sound
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
			# No target control reaction here anymore as we might be targeting a point in space
		)
		
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, end_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))

	# Wait for animations then call completion callback
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.55
	var wait_tween = create_tween()
	wait_tween.tween_interval(total_wait)
	wait_tween.tween_callback(on_complete)

func _on_open_inventory_pressed() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows()
	else:
		var main_node = GameManager._active_main_node
		if is_instance_valid(main_node) and main_node.has_method("set_action_zone_texts"):
			var transform_text = tr("ui.bm_drop_transform").format({"cost": str(TRANSFORM_COST_GOLD)})
			var remove_text = tr("ui.bm_drop_remove").format({"cost": str(_get_remove_cost())})
			main_node.set_action_zone_texts(transform_text, remove_text)
			
		SignalBus.emit_signal("inspect_inventory_requested")

func _on_leave_pressed() -> void:
	# Hide BM zones before leaving
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node):
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
		if main_node.has_method("hide_split_action_drop_zones"):
			main_node.hide_split_action_drop_zones()
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

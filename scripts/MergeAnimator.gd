extends Node

## Handles visual animations and VFX sequencing for merge operations.
## Listens to the `merge_animation_requested` signal and decouples presentation
## from the data logic in InventoryManager.

func _ready() -> void:
	SignalBus.merge_animation_requested.connect(_on_merge_animation_requested)

func _on_merge_animation_requested(context: Dictionary) -> void:
	# Extract context
	var merged_uuid: String = context.get("merged_uuid", "")
	var source_loc: LocationIdentifier = context.get("source_loc")
	var target_loc: LocationIdentifier = context.get("target_loc")
	var final_loc: LocationIdentifier = context.get("final_loc")
	var new_instance: GachaBallInstance = context.get("new_instance")
	var is_merge_encounter: bool = context.get("is_merge_encounter", false)
	var merge_encounter_cost: int = context.get("merge_encounter_cost", 0)
	var should_trigger_on_merge: bool = context.get("should_trigger_on_merge", false)
	var merge_context: Dictionary = context.get("merge_context", {})

	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc) or not is_instance_valid(new_instance):
		return

	# Locate views
	var source_view = WindowManager.find_view_for_location(source_loc)
	var target_view = WindowManager.find_view_for_location(target_loc)
	var final_view = WindowManager.find_view_for_location(final_loc)
	var start_pos = target_view.get_global_rect().get_center() if is_instance_valid(target_view) else Vector2.ZERO

	# Hide ingredients
	_set_unit_view_visible(source_view, false)
	_set_unit_view_visible(target_view, false)

	# Wait for the tree to process frame so the new final_view is actually ready/instantiated
	await get_tree().process_frame

	# Ensure we have the latest final_view in case it was created during the frame
	if not is_instance_valid(final_view):
		final_view = WindowManager.find_view_for_location(final_loc)

	# Hide the real result unit so we can animate the VFX ball
	_set_unit_view_visible(final_view, false)

	var vfx_ball = _create_vfx_ball(new_instance, start_pos)
	if is_instance_valid(vfx_ball):
		vfx_ball.play_landing_bounce()

	Audio.play_sfx("ui_merge")

	if is_merge_encounter and merge_encounter_cost > 0:
		await _animate_merge_gold_deduction(target_loc)
		
	# Wait for UI to completely refresh before arc toss
	await get_tree().process_frame

	if is_instance_valid(final_view) and not start_pos.is_zero_approx():
		await _animate_vfx_ball_toss(vfx_ball, final_view, new_instance)
	else:
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		# Use call_deferred to be safe
		SignalBus.emit_signal.call_deferred("inventory_action_completed", [merged_uuid])

	# Trigger on_merge AFTER the animation completes
	if should_trigger_on_merge:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			# Let queue_free/redraw settle so animator registers the latest merged views.
			await get_tree().process_frame
			var snapshot: Dictionary = bm.get_board_snapshot()
			if bm.has_method("block_ui_updates"):
				bm.block_ui_updates()
				
			AbilityResolver.process_trigger(&"on_board_enter", {"entered_uuid": merged_uuid})
			AbilityResolver.process_trigger(&"on_merge", merge_context)
			AbilityResolver.process_trigger(&"on_board_changed", {"is_simulation": true})
			
			var pending_count: int = 0
			if bm.has_method("get_pending_reactions_size"):
				pending_count = int(bm.get_pending_reactions_size())
			else:
				pending_count = int(bm._pending_reactions.size())
				
			if pending_count > 0:
				await bm.resolve_management_effects_and_animate(snapshot)
				
			if bm.has_method("unblock_ui_updates"):
				bm.unblock_ui_updates()

func _create_vfx_ball(instance: GachaBallInstance, global_pos: Vector2) -> Control:
	var VisualDataAdapter = load("res://scripts/VisualDataAdapter.gd")
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var anim_ball = preload("res://scenes/GachaBallView.tscn").instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)
	
	# Fix warning: Reset anchors before setting size for a manual-transform node
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	
	anim_ball.force_inventory_mode = true
	# CRITICAL: Set size scale to 1.0 (inventory) and fix dimensions before populate
	# to ensure stat labels and icons are correctly positioned.
	if anim_ball.has_method("set_size_scale"):
		anim_ball.set_size_scale(1.0)
	
	anim_ball.custom_minimum_size = Vector2(96.0, 96.0) # Match C.SLOT_SIZE_BASE
	anim_ball.size = Vector2(96.0, 96.0)
	
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	
	var pivot = anim_ball.size / 2.0
	anim_ball.global_position = global_pos - pivot
	return anim_ball

func _set_unit_view_visible(slot_view: Control, is_visible: bool) -> void:
	if not is_instance_valid(slot_view): return
	for child in slot_view.get_children():
		if "GachaBallView" in child.name or child.has_method("populate"):
			child.visible = is_visible
			break

func _animate_vfx_ball_toss(vfx_ball: Control, target_slot: Control, instance: GachaBallInstance) -> void:
	if not is_instance_valid(target_slot) or not is_instance_valid(vfx_ball): 
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		return
	
	var start_pos = vfx_ball.global_position + (vfx_ball.size / 2.0)
	var end_pos = target_slot.get_global_rect().get_center()
	
	# If start and end are too close, just trigger bounce and return
	if start_pos.distance_to(end_pos) < 20.0:
		vfx_ball.queue_free()
		SignalBus.emit_signal("inventory_action_completed", [instance.ball_uuid])
		return
		
	# Hide the real ball view in the target slot
	var real_ball_view: Control = null
	for child in target_slot.get_children():
		if "GachaBallView" in child.name or child.has_method("play_landing_bounce"):
			real_ball_view = child
			break
	
	if is_instance_valid(real_ball_view):
		real_ball_view.visible = false
		target_slot.visible = true

	# Animate Arc (Kinematic Parabola)
	var arc_height = clamp(start_pos.distance_to(end_pos) * 0.5, 80.0, 300.0)
	var duration = 0.55
	
	var control_point = Vector2(
		(start_pos.x + end_pos.x) / 2.0,
		min(start_pos.y, end_pos.y) - arc_height
	)
	
	var tween = vfx_ball.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	var Audio = get_node_or_null("/root/Audio")
	if is_instance_valid(Audio) and Audio.has_method("play_sfx"):
		Audio.play_sfx("unit_toss")
	
	var pivot = vfx_ball.size / 2.0
	tween.tween_method(func(t: float):
		if not is_instance_valid(vfx_ball): return
		var eased_t = pow(t, 1.05)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_pos)
		vfx_ball.global_position = pos - pivot
	, 0.0, 1.0, duration)
	
	await tween.finished
	
	# Cleanup
	if is_instance_valid(vfx_ball): vfx_ball.queue_free()
	if is_instance_valid(real_ball_view):
		real_ball_view.visible = true
		if real_ball_view.has_method("play_landing_bounce"):
			real_ball_view.play_landing_bounce()
			
	SignalBus.emit_signal("inventory_action_completed", [instance.ball_uuid])

func _animate_merge_gold_deduction(target_loc: LocationIdentifier) -> void:
	var target_view = WindowManager.find_view_for_location(target_loc)
	if not is_instance_valid(target_view): return
	
	var end_pos = target_view.get_global_rect().get_center()
	
	var GameManager = get_node_or_null("/root/GameManager")
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	if not is_instance_valid(main_node): return
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group): return
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon): gold_icon = gold_group
	var gold_rect = gold_icon.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	var GoldCoinVFXScript = load("res://scripts/vfx/GoldCoinVFX.gd")
	if not GoldCoinVFXScript: return
	
	var coins_to_spawn = 5
	var stagger_delay = 0.08
	
	var Audio = get_node_or_null("/root/Audio")
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScript.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			if is_instance_valid(Audio) and Audio.has_method("play_sfx"):
				Audio.play_sfx("coin_land")
		)
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, end_pos, i * stagger_delay)
		if is_instance_valid(Audio) and Audio.has_method("play_sfx"):
			Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
		
	# Await completion (stagger + flight time)
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.55
	await AnimationConstants.create_pausable_timer(get_tree(), total_wait).timeout

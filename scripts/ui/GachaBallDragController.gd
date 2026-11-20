# res://scripts/ui/GachaBallDragController.gd
class_name GachaBallDragController
extends RefCounted

## Manages drag-and-drop initiation, rubber-toy velocity deformation, padded
## drag preview construction, drag notification cleanup, snap-back, landing bounce,
## and trinket activation bounce for GachaBallView.

const C = preload("res://scripts/Constants.gd")
const SpriteOutline = preload("res://scripts/ui/SpriteOutline.gd")
const GACHABALL_OVERLAY_PATH := "res://assets/PixelArt/ui/textures/gachaballcapsule.png"
const INCUBATOR_CAPSULE_TINT := Color(1.0, 0.87, 0.42)


func update_drag_deformation(view: Control, delta: float) -> void:
	if not view._is_dragging:
		return
	if not is_instance_valid(view._drag_preview):
		return

	var mouse_pos: Vector2 = GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else view.get_global_mouse_position()
	if view._drag_first_frame:
		view._drag_first_frame = false
		view._last_mouse_pos = mouse_pos
		return

	var velocity: Vector2 = (mouse_pos - view._last_mouse_pos) / maxf(delta, 0.001)
	view._last_mouse_pos = mouse_pos
	view._drag_velocity = view._drag_velocity.lerp(velocity, 0.25)

	var target_rotation: float = clampf(view._drag_velocity.x * 0.0001, -0.12, 0.12)
	view._drag_preview.rotation = lerpf(view._drag_preview.rotation, target_rotation, 0.15)

	var stretch_factor: float = 0.0
	var clamped_velocity_y: float = maxf(view._drag_velocity.y, -2000.0)
	if clamped_velocity_y < -100.0:
		stretch_factor = clampf(-clamped_velocity_y * 0.00005, 0.0, 0.2)

	var target_scale := Vector2(1.0 - stretch_factor * 0.15, 1.0 + stretch_factor)
	var lerp_speed: float = 0.3 if stretch_factor < 0.01 else 0.15
	view._drag_preview.scale = view._drag_preview.scale.lerp(target_scale, lerp_speed)


func reset_drag_deformation(view: Control) -> void:
	if not view._is_dragging:
		return
	view._is_dragging = false
	view._drag_velocity = Vector2.ZERO
	view._drag_preview = null
	if is_instance_valid(view.icon_rect):
		view.icon_rect.scale = view._original_icon_scale
		view.icon_rect.rotation = view._original_icon_rotation


func can_begin_drag(view: Control) -> bool:
	if not view._is_interactive:
		return false
	if GlobalInteractionRouter.is_combat_locked():
		return false
	if GlobalInteractionRouter.is_vcr_playing():
		return false
	if ActionQueue.is_busy():
		return false
	if is_instance_valid(view._location):
		var context_group: StringName = GlobalInteractionRouter.get_context_group(view._location.container)
		if context_group == &"InspectionOnly":
			return false
	return true


func prepare_drag_payload(view: Control) -> Dictionary:
	if not can_begin_drag(view):
		return {}

	view._drag_initiated_for_click = true
	view._pressed_pending_click = false
	if is_instance_valid(view._inspection_trigger):
		view._inspection_trigger.cancel()

	view._is_dragging = true
	view._drag_first_frame = true
	var current_pointer: Vector2 = GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else view.get_global_mouse_position()
	view._last_mouse_pos = current_pointer
	view._drag_velocity = Vector2.ZERO
	if is_instance_valid(view.icon_rect):
		view._original_icon_scale = view.icon_rect.scale
		view._original_icon_rotation = view.icon_rect.rotation

	var drag_visual: Control = build_drag_preview_visual(view)
	var engine_preview: Control = build_drag_engine_preview_stub()

	view._drag_preview = drag_visual
	view._drag_preview.scale = Vector2.ONE
	view._drag_preview.pivot_offset = Vector2.ZERO
	view._last_mouse_pos = current_pointer

	var placeholder := Control.new()
	placeholder.custom_minimum_size = view.size
	view.get_parent().add_child(placeholder)
	view.get_parent().move_child(placeholder, view.get_index())

	GlobalInteractionRouter.start_drag_visuals(view, placeholder)
	GlobalInteractionRouter.set_drag_overlay_preview(drag_visual)
	var origin_ctx: InteractionContext = view._create_interaction_context(&"DRAG_ORIGIN")
	GlobalInteractionRouter.start_drag(origin_ctx)

	if not GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag_visuals(false)
		if is_instance_valid(drag_visual):
			drag_visual.queue_free()
		view._drag_preview = null
		view._is_dragging = false
		view._drag_initiated_for_click = false
		return {}

	return {
		"data": {"source_loc": view._location},
		"preview": engine_preview,
	}


func build_drag_preview_visual(view: Control) -> Control:
	var drag_texture: Texture2D = view.icon_rect.texture
	var unit_sprite: TextureRect = view.icon_rect.get_node_or_null("UnitSprite") as TextureRect
	if is_instance_valid(unit_sprite) and unit_sprite.texture:
		drag_texture = unit_sprite.texture

	var has_capsule_overlay: bool = view._has_overlay_heuristic()
	var is_battle_shelf_capsule: bool = GameManager.is_in_battle and view._is_shelf_capsule()
	var size_scale: float = view._size_scale
	var capsule_preview_size: float = float(C.GACHA_CAPSULE_DIAMETER) * (size_scale if is_battle_shelf_capsule else 1.0)
	var current_slot_size: float = capsule_preview_size if has_capsule_overlay else float(C.SLOT_SIZE_BASE) * size_scale
	var preview_size := Vector2(current_slot_size, current_slot_size)
	var container_size: Vector2 = preview_size * 2.0
	var offset: Vector2 = -preview_size / 2.0
	var is_item_preview: bool = view._entity_type == &"ITEM"
	var preview_scale: float = current_slot_size / float(C.GACHA_CAPSULE_DIAMETER) if has_capsule_overlay else size_scale
	var authored_preview_size: Vector2 = Vector2(drag_texture.get_size()) * preview_scale

	var preview_container := Control.new()
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	preview_container.custom_minimum_size = container_size
	preview_container.size = container_size

	var preview := TextureRect.new()
	preview.texture = drag_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	view._match_icon_texture_filter(preview)
	if has_capsule_overlay:
		var current_unit_size: float = (float(C.UNIT_SPRITE_SIZE) / 2.0) * preview_scale
		var unit_size := Vector2(current_unit_size, current_unit_size)
		var displayed_size: Vector2 = authored_preview_size if is_item_preview else unit_size
		preview.custom_minimum_size = displayed_size
		preview.size = displayed_size
		preview.position = offset + (preview_size - displayed_size) / 2.0
	elif is_item_preview:
		preview.custom_minimum_size = authored_preview_size
		preview.size = authored_preview_size
		preview.position = offset + (preview_size - authored_preview_size) / 2.0
	else:
		preview.custom_minimum_size = preview_size
		preview.size = preview_size
		preview.position = offset
	preview_container.add_child(preview)
	if view.icon_rect.material and (not has_capsule_overlay or view._is_selected):
		add_padded_drag_outline(view, preview_container, preview, drag_texture)

	if has_capsule_overlay:
		var overlay_texture: Texture2D = load(GACHABALL_OVERLAY_PATH)
		if overlay_texture:
			var overlay_preview := TextureRect.new()
			overlay_preview.texture = overlay_texture
			if view._visual_incubating:
				overlay_preview.modulate = INCUBATOR_CAPSULE_TINT
			overlay_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			overlay_preview.stretch_mode = TextureRect.STRETCH_SCALE
			overlay_preview.custom_minimum_size = preview_size
			overlay_preview.size = preview_size
			overlay_preview.position = offset
			preview_container.add_child(overlay_preview)
			preview_container.move_child(overlay_preview, 0)

	set_preview_tree_mouse_ignore(preview_container)
	return preview_container


func add_padded_drag_outline(view: Control, preview_container: Control, preview: TextureRect, source_texture: Texture2D) -> void:
	var outline_texture: Texture2D = SpriteOutline.padded_texture(source_texture)
	var source_size := Vector2(source_texture.get_size())
	var pixels_per_source_pixel: Vector2 = preview.size / source_size
	var displayed_padding: Vector2 = float(SpriteOutline.PADDING) * pixels_per_source_pixel
	var outline_preview := TextureRect.new()
	outline_preview.texture = outline_texture
	outline_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outline_preview.stretch_mode = TextureRect.STRETCH_SCALE
	view._match_icon_texture_filter(outline_preview)
	outline_preview.custom_minimum_size = preview.size + displayed_padding * 2.0
	outline_preview.size = outline_preview.custom_minimum_size
	outline_preview.position = preview.position - displayed_padding
	var outline_material: ShaderMaterial = view.icon_rect.material.duplicate() as ShaderMaterial
	assert(outline_material != null, "GachaBallView drag outline requires a ShaderMaterial.")
	outline_material.set_shader_parameter("outline_enabled", true)
	if view._is_selected:
		outline_material.set_shader_parameter("outline_color", Color.WHITE)
		outline_material.set_shader_parameter("outline_width", 3.0)
	outline_preview.material = outline_material
	preview_container.add_child(outline_preview)
	preview_container.move_child(outline_preview, preview.get_index())


static func build_drag_engine_preview_stub() -> Control:
	var preview_stub := Control.new()
	preview_stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stub.custom_minimum_size = Vector2.ONE
	preview_stub.size = Vector2.ONE
	preview_stub.modulate.a = 0.0
	return preview_stub


static func set_preview_tree_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		set_preview_tree_mouse_ignore(child)


func handle_drag_notification(view: Control, what: int) -> void:
	if what == Control.NOTIFICATION_DRAG_BEGIN:
		if view._drag_initiated_for_click:
			if is_instance_valid(view._inspection_trigger):
				view._inspection_trigger.cancel()
			view._set_hover_state(false, false)
			view._animate_press_to(0.0, 0.05)
			var context: InteractionContext = view._create_interaction_context(&"DRAG_START")
			SignalBus.emit_signal("interaction_context_received", context)
			view.modulate.a = 0.0

	if what == Control.NOTIFICATION_DRAG_END:
		if not view._is_dragging:
			return
		var godot_successful: bool = view.is_drag_successful()
		var combined_success: bool = godot_successful and view._logical_drag_success
		reset_drag_deformation(view)

		if not combined_success:
			view.modulate.a = 1.0
			var drop_pos: Vector2 = view._last_mouse_pos
			if drop_pos.is_zero_approx():
				drop_pos = GlobalInteractionRouter.get_last_pointer_position()
			if not godot_successful and not ActionQueue.is_replay_mode():
				ActionQueue.request(CancelDragAction.new(view._location, null, "empty_drop", drop_pos))
			else:
				if GlobalInteractionRouter.is_drag_active():
					GlobalInteractionRouter.end_drag(false)
				if not drop_pos.is_zero_approx():
					play_snap_back_from(view, drop_pos)
				else:
					play_landing_bounce(view)

		view._drag_initiated_for_click = false
		view._animate_press_to(0.0, 0.08)
		view._logical_drag_success = false

		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(combined_success)
			GlobalInteractionRouter.end_drag_visuals(combined_success)


func play_trinket_activation_bounce(view: Control) -> void:
	if not is_instance_valid(view.icon_rect):
		return
	Audio.play_sfx("unit_hop")
	if not view.visible:
		view.visible = true
	var parent_canvas: CanvasItem = view.get_parent() as CanvasItem
	if is_instance_valid(parent_canvas):
		parent_canvas.visible = true

	if view.icon_rect.size == Vector2.ZERO:
		await view.get_tree().process_frame
		if not is_instance_valid(view) or not is_instance_valid(view.icon_rect):
			return

	view.icon_rect.pivot_offset = view.icon_rect.size / 2.0
	var original_scale: Vector2 = view.icon_rect.scale
	var tween: Tween = view.create_tween()
	tween.tween_property(view.icon_rect, "scale", Vector2(0.85, 1.15), AnimationConstants.scaled(0.08)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view.icon_rect, "scale", Vector2(1.1, 0.9), AnimationConstants.scaled(0.06)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(view.icon_rect, "scale", original_scale, AnimationConstants.scaled(0.12)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_snap_back_from(view: Control, origin_pos: Vector2) -> void:
	if not is_instance_valid(view.icon_rect):
		play_landing_bounce(view)
		return

	view.visible = true
	view.modulate.a = 1.0
	var parent_canvas: CanvasItem = view.get_parent() as CanvasItem
	if is_instance_valid(parent_canvas):
		parent_canvas.visible = true

	var target_global_pos: Vector2 = view.global_position + (view.size / 2.0)
	if origin_pos.is_zero_approx() or origin_pos.distance_to(target_global_pos) < 6.0:
		play_landing_bounce(view)
		return

	var offset: Vector2 = origin_pos - target_global_pos
	var original_pos: Vector2 = view.icon_rect.position
	view.icon_rect.position = original_pos + offset

	Audio.play_sfx("unit_hop")
	var tween: Tween = view.create_tween()
	tween.tween_property(view.icon_rect, "position", original_pos, AnimationConstants.scaled(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(view):
			play_landing_bounce(view)
	)


func play_landing_bounce(view: Control) -> void:
	if not is_instance_valid(view.icon_rect):
		return

	Audio.play_sfx("unit_hop")
	if not view.visible:
		view.visible = true
	var parent_canvas: CanvasItem = view.get_parent() as CanvasItem
	if is_instance_valid(parent_canvas):
		parent_canvas.visible = true

	view._is_landing_bounce_active = true
	view._landing_bounce_until_msec = Time.get_ticks_msec() + int(AnimationConstants.scaled(0.40) * 1000.0)

	if view._hover_amount > 0.001:
		view._hover_amount = 0.0
		view.scale = Vector2.ONE

	var controller: Node = view.get_node_or_null("AnimationController")
	if is_instance_valid(controller) and not view._bound_uuid.is_empty():
		SignalBus.emit_signal("unit_deform", view._bound_uuid, &"LANDING_BOUNCE")
		return

	var target_sprite: Control = view.icon_rect
	var unit_sprite: Control = view.icon_rect.get_node_or_null("UnitSprite") as Control
	if is_instance_valid(unit_sprite):
		target_sprite = unit_sprite
		target_sprite.pivot_offset = Vector2(target_sprite.size.x / 2.0, target_sprite.size.y)
	else:
		if view.icon_rect.size == Vector2.ZERO:
			view._is_landing_bounce_active = false
			return
		view.icon_rect.pivot_offset = view.icon_rect.size / 2.0

	var original_scale: Vector2 = target_sprite.scale
	var tween: Tween = view.create_tween()
	AnimationConstants.append_landing_bounce(tween, target_sprite, original_scale)
	tween.finished.connect(func() -> void:
		if is_instance_valid(view):
			view._is_landing_bounce_active = false
			if view._is_hovered and not GlobalInteractionRouter.is_drag_active():
				view._animate_hover_to(1.0, 0.16)
	)

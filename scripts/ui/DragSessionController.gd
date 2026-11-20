# res://scripts/ui/DragSessionController.gd
class_name DragSessionController
extends RefCounted

## Centralizes active drag-and-drop state, placeholder/source visibility,
## overlay preview positioning, and DragPreviewLayer lifecycle for GlobalInteractionRouter.

var is_drag_active: bool = false
var drag_origin_context: InteractionContext = null
var drag_source_view: Control = null
var drag_placeholder: Control = null

var _drag_overlay_preview: Control = null
var _drag_preview_layer: CanvasLayer = null


func start_drag(router: Node, origin_context: InteractionContext) -> void:
	if router._is_combat_phase or router.is_vcr_playing() or ActionQueue.is_busy():
		return

	if router._current_selection != null:
		router._execute_deselect()

	router._is_inspection_locked = false
	router._locked_entity_view_id = -1

	is_drag_active = true
	drag_origin_context = origin_context

	if origin_context != null:
		var src_view: Control = InteractionTargetRules.find_view_by_instance_id(origin_context.source_view_instance_id, router.get_tree().root)
		if is_instance_valid(src_view):
			var parent_window: Control = WindowManager.find_ancestor_window_for_view(src_view)
			if is_instance_valid(parent_window):
				WindowManager.close_children_of(parent_window)
			else:
				WindowManager.close_all_inspection_windows(true)

	# Select LAST so window-closure side effects cannot clear the active drag selection.
	router._execute_select(origin_context)
	SignalBus.drag_started.emit(origin_context)
	Audio.play_sfx("ui_drag_start")


func end_drag(router: Node, was_handled: bool) -> void:
	is_drag_active = false
	drag_origin_context = null
	router._execute_deselect()
	router._is_inspection_locked = false

	if was_handled:
		router._suppression.arm(0, CloseSuppressionState.CLOSE_SUPPRESS_GRACE_FRAMES, true)
		if is_instance_valid(router._peek_controller):
			router._peek_controller.suppress_post_drop(0.35)

	end_drag_visuals(was_handled)
	Audio.play_sfx("ui_drag_drop" if was_handled else "ui_deselect")
	SignalBus.drag_ended.emit(was_handled)


func start_drag_visuals(is_combat_phase: bool, source_view: Control, placeholder: Control) -> void:
	if is_combat_phase:
		if is_instance_valid(placeholder):
			placeholder.queue_free()
		return
	drag_source_view = source_view
	drag_placeholder = placeholder
	if is_instance_valid(drag_source_view):
		drag_source_view.visible = false
		drag_source_view.modulate.a = 0.0


func end_drag_visuals(was_handled: bool) -> void:
	if is_instance_valid(drag_source_view) and not was_handled:
		drag_source_view.visible = true
		drag_source_view.modulate.a = 1.0
	if is_instance_valid(drag_placeholder):
		drag_placeholder.queue_free()
	clear_drag_overlay_preview()
	drag_source_view = null
	drag_placeholder = null


func set_drag_overlay_preview(router: Node, preview: Control) -> void:
	clear_drag_overlay_preview()
	if not is_instance_valid(preview):
		return
	_drag_overlay_preview = preview
	_drag_overlay_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_or_create_preview_layer(router.get_tree().root).add_child(_drag_overlay_preview)
	_drag_overlay_preview.global_position = router.get_viewport().get_mouse_position()


func update_overlay_position(pointer_pos: Vector2) -> void:
	if is_instance_valid(_drag_overlay_preview):
		_drag_overlay_preview.global_position = pointer_pos


func clear_drag_overlay_preview() -> void:
	if is_instance_valid(_drag_overlay_preview):
		_drag_overlay_preview.queue_free()
	_drag_overlay_preview = null


func cleanup() -> void:
	end_drag_visuals(false)
	is_drag_active = false
	drag_origin_context = null
	if is_instance_valid(_drag_preview_layer):
		_drag_preview_layer.queue_free()
	_drag_preview_layer = null


func _get_or_create_preview_layer(tree_root: Node) -> CanvasLayer:
	if is_instance_valid(_drag_preview_layer):
		return _drag_preview_layer
	_drag_preview_layer = CanvasLayer.new()
	_drag_preview_layer.name = "DragPreviewLayer"
	_drag_preview_layer.layer = 1023
	tree_root.add_child(_drag_preview_layer)
	return _drag_preview_layer

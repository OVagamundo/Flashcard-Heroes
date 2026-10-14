# res://scripts/engine/actions/ui/CancelDragAction.gd
class_name CancelDragAction
extends GameAction

var source_location: LocationIdentifier = null
var target_location: LocationIdentifier = null
var reason: String = "cancelled"
var drop_pos: Vector2 = Vector2.ZERO
var source_view_id: int = -1

func _init(
	p_source_loc: LocationIdentifier = null,
	p_target_loc: LocationIdentifier = null,
	p_reason: String = "cancelled",
	p_drop_pos: Vector2 = Vector2.ZERO,
	p_source_view_id: int = -1
) -> void:
	super._init(&"CancelDragAction")
	source_location = p_source_loc
	target_location = p_target_loc
	reason = p_reason
	drop_pos = p_drop_pos
	source_view_id = p_source_view_id

func is_meta_action() -> bool:
	return true

func validate() -> bool:
	return true

func execute() -> void:
	var view: Control = null
	if source_view_id != -1:
		var candidate = instance_from_id(source_view_id)
		if is_instance_valid(candidate) and candidate is Control:
			view = candidate

	if not is_instance_valid(view) and is_instance_valid(source_location) and is_instance_valid(WindowManager):
		view = WindowManager.find_view_for_location(source_location)
	
	if not is_instance_valid(view) and is_instance_valid(GlobalInteractionRouter):
		view = GlobalInteractionRouter.get_drag_source_view()
	
	# If view is a SlotView or container, locate the child unit view inside it
	var ball_view: Control = null
	if is_instance_valid(view):
		if view is GachaBallView or view.has_method("play_landing_bounce"):
			ball_view = view
		else:
			for child in view.get_children():
				if not child.is_queued_for_deletion() and (child is GachaBallView or (child is Control and child.has_method("play_landing_bounce"))):
					ball_view = child
					break

	# Calculate effective drop position for snap-back animation if not provided
	var effective_drop_pos: Vector2 = drop_pos
	if effective_drop_pos.is_zero_approx() and is_instance_valid(target_location) and is_instance_valid(WindowManager):
		var target_v: Control = WindowManager.find_view_for_location(target_location)
		if is_instance_valid(target_v):
			effective_drop_pos = target_v.get_global_rect().get_center()

	# Ensure parent/container is visible
	if is_instance_valid(view):
		view.visible = true
		view.modulate.a = 1.0

	# Restore visibility and animate the unit view back to its slot
	if is_instance_valid(ball_view):
		ball_view.visible = true
		ball_view.modulate.a = 1.0
		if not effective_drop_pos.is_zero_approx() and ball_view.has_method("play_snap_back_from"):
			ball_view.play_snap_back_from(effective_drop_pos)
		elif ball_view.has_method("play_landing_bounce"):
			ball_view.play_landing_bounce()
	elif is_instance_valid(view):
		if not effective_drop_pos.is_zero_approx() and view.has_method("play_snap_back_from"):
			view.play_snap_back_from(effective_drop_pos)
		elif view.has_method("play_landing_bounce"):
			view.play_landing_bounce()
	
	Audio.play_sfx("ui_deselect")
	
	if is_instance_valid(GlobalInteractionRouter):
		GlobalInteractionRouter.end_drag_visuals(false)
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.clear_current_selection()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_location"] = source_location.to_dict() if is_instance_valid(source_location) else {}
	d["target_location"] = target_location.to_dict() if is_instance_valid(target_location) else {}
	d["reason"] = reason
	d["drop_pos"] = [drop_pos.x, drop_pos.y]
	d["source_view_id"] = source_view_id
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("source_location") and data["source_location"] is Dictionary and not data["source_location"].is_empty():
		source_location = LocationIdentifier.create_from_dict(data["source_location"])
	if data.has("target_location") and data["target_location"] is Dictionary and not data["target_location"].is_empty():
		target_location = LocationIdentifier.create_from_dict(data["target_location"])
	reason = String(data.get("reason", "cancelled"))
	if data.has("drop_pos") and data["drop_pos"] is Array and data["drop_pos"].size() == 2:
		drop_pos = Vector2(data["drop_pos"][0], data["drop_pos"][1])
	source_view_id = int(data.get("source_view_id", -1))

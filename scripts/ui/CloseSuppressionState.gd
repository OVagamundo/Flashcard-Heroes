# res://scripts/ui/CloseSuppressionState.gd
class_name CloseSuppressionState
extends RefCounted

## Deterministic frame/action-scoped close suppression for GlobalInteractionRouter.
## Prevents parent inspection windows from closing during same-frame input bubbling,
## active ActionQueue mutations, and deferred anchor rebuild frames.

const CLOSE_SUPPRESS_GRACE_FRAMES: int = 2

var _parent_window_id: int = -1
var _until_frame: int = -1
var _hold_while_action_busy: bool = false


func arm(parent_window_id: int, grace_frames: int = CLOSE_SUPPRESS_GRACE_FRAMES, hold_during_action: bool = false) -> void:
	_parent_window_id = parent_window_id
	_until_frame = Engine.get_process_frames() + maxi(0, grace_frames)
	_hold_while_action_busy = hold_during_action


func clear() -> void:
	_parent_window_id = -1
	_until_frame = -1
	_hold_while_action_busy = false


func is_active() -> bool:
	if _parent_window_id == -1:
		return false
	var current_frame: int = Engine.get_process_frames()
	if _hold_while_action_busy and ActionQueue.is_busy():
		_until_frame = maxi(_until_frame, current_frame + CLOSE_SUPPRESS_GRACE_FRAMES)
		return true
	if current_frame <= _until_frame:
		return true
	clear()
	return false


func activate_for_view(view: Control, grace_frames: int = CLOSE_SUPPRESS_GRACE_FRAMES) -> void:
	if not is_instance_valid(view):
		return
	var parent_window: Control = WindowManager.find_ancestor_window_for_view(view)
	if is_instance_valid(parent_window):
		arm(parent_window.get_instance_id(), grace_frames, true)


func activate_for_window_id(window_id: int, grace_frames: int = CLOSE_SUPPRESS_GRACE_FRAMES) -> void:
	if window_id <= 0:
		return
	arm(window_id, grace_frames, true)


func is_suppressed_for_window_id(window_id: int) -> bool:
	if not is_active() or window_id <= 0:
		return false
	return window_id == _parent_window_id


func is_suppressed_for_context(context: InteractionContext, tree_root: Node) -> bool:
	if not is_active() or context == null:
		return false
	var view: Control = InteractionTargetRules.find_view_by_instance_id(context.source_view_instance_id, tree_root)
	if not is_instance_valid(view):
		return false
	var parent_window: Control = WindowManager.find_ancestor_window_for_view(view)
	return is_instance_valid(parent_window) and parent_window.get_instance_id() == _parent_window_id

class_name InspectionPeekController
extends Node

enum State { IDLE, ARMED, OPEN }

var _state: State = State.IDLE
var _armed_source_view: Control = null
var _armed_source_id: int = -1
var _armed_request: Dictionary = {}
var _is_armed_by_press: bool = false
var _timer: Timer = null

# Click suppression: after a selection click occurs on an inspectable element,
# hover peek is suppressed for that element until the cursor exits the element.
var _click_suppressed_source_id: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.name = "PeekTimer"
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	if SignalBus.has_signal("interaction_lock_requested"):
		SignalBus.interaction_lock_requested.connect(_on_interaction_lock_requested)

func _exit_tree() -> void:
	if SignalBus.has_signal("interaction_lock_requested") and SignalBus.interaction_lock_requested.is_connected(_on_interaction_lock_requested):
		SignalBus.interaction_lock_requested.disconnect(_on_interaction_lock_requested)

func _on_interaction_lock_requested(locked: bool) -> void:
	if locked:
		_cancel_internal()

func hover_enter(view: Control, request: Dictionary) -> void:
	if not _can_peek():
		return
	if not is_instance_valid(view):
		return
	var view_id = view.get_instance_id()
	if view_id == _click_suppressed_source_id:
		return
	if _is_blocked_by_inventory_boundary(view):
		return
	
	if _state == State.OPEN and _armed_source_id == view_id:
		return
	if _state == State.ARMED and _armed_source_id == view_id and not _is_armed_by_press:
		return
	
	_cancel_internal()
	_state = State.ARMED
	_is_armed_by_press = false
	_armed_source_view = view
	_armed_source_id = view_id
	_armed_request = request
	_timer.start(InputUtils.HOVER_PEEK_DELAY_SEC)

func hover_exit(view: Control) -> void:
	if not is_instance_valid(view):
		return
	var view_id = view.get_instance_id()
	if view_id == _click_suppressed_source_id:
		_click_suppressed_source_id = -1
	
	if _armed_source_id != view_id:
		return
	
	if _state == State.ARMED:
		if not _is_armed_by_press:
			_cancel_internal()
	elif _state == State.OPEN:
		if not _is_armed_by_press:
			close_peek()

func press_start(view: Control, request: Dictionary) -> void:
	if not _can_peek():
		return
	if not is_instance_valid(view):
		return
	if _is_blocked_by_inventory_boundary(view):
		return
	
	_cancel_internal()
	_state = State.ARMED
	_is_armed_by_press = true
	_armed_source_view = view
	_armed_source_id = view.get_instance_id()
	_armed_request = request
	_timer.start(InputUtils.LONG_PRESS_PEEK_DELAY_SEC)

## Called on pointer release. Returns true if peek was open (so view suppresses click), false otherwise.
func press_end(view: Control) -> bool:
	if not is_instance_valid(view):
		return false
	var view_id = view.get_instance_id()
	if _armed_source_id != view_id:
		return false
	
	if _state == State.OPEN and _is_armed_by_press:
		close_peek()
		return true
	
	if _state == State.ARMED and _is_armed_by_press:
		_cancel_internal()
		# Release before delay = quick click / tap. Suppress hover until hover exit.
		_click_suppressed_source_id = view_id
		return false
	
	return false

func cancel(view: Control = null) -> void:
	if view != null and _armed_source_id != -1 and _armed_source_id != view.get_instance_id():
		return
	_cancel_internal()

func _cancel_internal() -> void:
	if _state == State.ARMED:
		_timer.stop()
		_state = State.IDLE
		_armed_source_view = null
		_armed_source_id = -1
		_armed_request = {}
		_is_armed_by_press = false
	elif _state == State.OPEN:
		close_peek()

func close_peek() -> void:
	if _state == State.OPEN:
		if is_instance_valid(WindowManager):
			WindowManager.close_all_inspection_windows(true)
	_state = State.IDLE
	_armed_source_view = null
	_armed_source_id = -1
	_armed_request = {}
	_is_armed_by_press = false

func is_peek_open() -> bool:
	return _state == State.OPEN

func _on_timer_timeout() -> void:
	if _state != State.ARMED:
		return
	if not _can_peek() or not is_instance_valid(_armed_source_view) or not _armed_source_view.is_inside_tree():
		_cancel_internal()
		return
	
	_state = State.OPEN
	if _armed_request.has("location"):
		var loc: LocationIdentifier = _armed_request["location"]
		if is_instance_valid(loc) and is_instance_valid(WindowManager):
			WindowManager.open_inspection_window(loc, _armed_source_view)
	elif _armed_request.has("trait_id"):
		var trait_id: String = _armed_request["trait_id"]
		if not trait_id.is_empty() and is_instance_valid(WindowManager):
			WindowManager.open_trait_inspection_window(trait_id, _armed_source_view)
	else:
		_cancel_internal()

func _can_peek() -> bool:
	if not is_instance_valid(GlobalInteractionRouter):
		return false
	if GlobalInteractionRouter.is_combat_locked():
		return false
	if GlobalInteractionRouter.is_vcr_playing():
		return false
	if GlobalInteractionRouter.is_combat_phase():
		return false
	if GlobalInteractionRouter.is_drag_active():
		return false
	if GlobalInteractionRouter.is_ui_transitioning():
		return false
	if GlobalInteractionRouter.is_inspection_locked():
		return false
	if is_instance_valid(WindowManager):
		if WindowManager.has_method("is_choice_window_open") and WindowManager.is_choice_window_open():
			return false
		if WindowManager.has_method("is_modal_open") and WindowManager.is_modal_open():
			return false
	return true

func _is_blocked_by_inventory_boundary(view: Control) -> bool:
	if not is_instance_valid(WindowManager):
		return false
	if not WindowManager.is_any_inventory_window_open():
		return false
	# If an inventory window is open, only allow views inside it
	var ancestor = WindowManager.find_ancestor_window_for_view(view)
	if not is_instance_valid(ancestor):
		return true
	if ancestor.has_meta("window_type"):
		var t = ancestor.get_meta("window_type")
		if t == &"Inventory" or t == &"DiscardPile":
			return false
	if "InventoryWindow" in ancestor.name or "DiscardPileWindow" in ancestor.name:
		return false
	return true

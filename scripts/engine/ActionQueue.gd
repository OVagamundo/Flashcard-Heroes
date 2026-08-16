extends Node

## Centralized queue for all GameActions.
## Enforces strict input blocking while actions resolve visually.

signal queue_idle

var _queue: Array[GameAction] = []
var _is_busy: bool = false
var _current_action: GameAction = null
var _is_headless: bool = false

func _ready() -> void:
	add_to_group("action_queue")

## Returns whether the queue is processing actions without visual playback.
func is_headless_mode() -> bool:
	return _is_headless

## Sets the headless mode flag for automated testing and replay fast-forwarding.
func set_headless_mode(enabled: bool) -> void:
	_is_headless = enabled

## Returns whether the queue is currently processing an action and its visuals.
func is_busy() -> bool:
	return _is_busy

## Submit a player-driven action.
## Returns true if accepted, false if dropped (e.g. because queue is busy).
func request(action: GameAction) -> bool:
	if _is_busy:
		return false
	_queue.append(action)
	_process_queue()
	return true

## Submit a system-driven action (e.g. timer, auto-reward).
## System actions are always appended and do not drop.
func enqueue_system(action: GameAction) -> void:
	_queue.append(action)
	if not _is_busy:
		_process_queue()

func _process_queue() -> void:
	if _is_busy or _queue.is_empty():
		return
		
	_is_busy = true
	_current_action = _queue.pop_front()
	
	if _current_action.is_valid():
		var yields = _current_action.yields_for_visuals()
		if yields:
			_current_action.resolved.connect(_on_action_resolved, CONNECT_ONE_SHOT)
			
		_current_action.execute()
		
		if not yields:
			_resolve_current_action()
	else:
		# Invalid actions are discarded and unblock immediately.
		_resolve_current_action()

func _on_action_resolved() -> void:
	_resolve_current_action()

func _resolve_current_action() -> void:
	_is_busy = false
	_current_action = null
	
	if _queue.is_empty():
		queue_idle.emit()
	else:
		call_deferred("_process_queue")

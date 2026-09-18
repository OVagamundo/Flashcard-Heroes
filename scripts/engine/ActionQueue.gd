# res://scripts/engine/ActionQueue.gd
extends Node

## Central command pipeline and deterministic input gate.
## Modelled after Slay the Spire:
## Every player input that mutates game state, advances flow, or dismisses gating modals
## MUST create a GameAction and pass through ActionQueue.request().
## While ActionQueue.is_busy() is true, incoming player inputs are gated.

signal action_requested(action: GameAction)
signal action_started(action: GameAction)
signal action_completed(action: GameAction)
signal action_rejected(action: GameAction, reason: String)
signal queue_idle

var _is_busy: bool = false
var _active_action: GameAction = null
var _is_headless: bool = false
var _global_run_timer: float = 0.0
var _last_action_timestamp: float = 0.0
var _timer_running: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Auto-detect headless flag from command line args
	var args := OS.get_cmdline_user_args()
	if args.has("--qa-bot") or args.has("--headless-test"):
		_is_headless = true

func _process(delta: float) -> void:
	if _timer_running:
		_global_run_timer += delta
		if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			GameManager.run_state.elapsed_simulation_time = _global_run_timer

## Submit an action to the pipeline.
## Returns true if accepted, false if dropped or rejected.
func request(action: GameAction) -> bool:
	if action == null:
		push_error("[ActionQueue] Attempted to request null action.")
		return false

	action_requested.emit(action)

	# Meta-actions (e.g. PauseRunAction, SetCombatSpeedAction) execute immediately
	# and bypass sequential input gating without interrupting the active gameplay action.
	if action.is_meta_action():
		if not action.validate():
			push_warning("[ActionQueue] Validation failed for meta-action %s" % action.action_type)
			action_rejected.emit(action, "VALIDATION_FAILED")
			return false

		action.timestamp = _global_run_timer
		action.idle_time = maxf(0.0, _global_run_timer - _last_action_timestamp)
		action_started.emit(action)
		action.execute()
		action_completed.emit(action)
		return true

	# Gating: Drop or reject if busy
	if is_busy():
		push_warning("[ActionQueue] Gated input: Queue is busy executing %s, rejected %s" % [
			_active_action.action_type if _active_action else "Unknown",
			action.action_type
		])
		action_rejected.emit(action, "QUEUE_BUSY")
		return false

	# Validation: Verify game preconditions
	if not action.validate():
		push_warning("[ActionQueue] Validation failed for %s" % action.action_type)
		action_rejected.emit(action, "VALIDATION_FAILED")
		return false

	# Ground timestamps
	action.timestamp = _global_run_timer
	action.idle_time = maxf(0.0, _global_run_timer - _last_action_timestamp)

	_is_busy = true
	_active_action = action
	action_started.emit(action)

	# Execute backend state mutation
	action.execute()

	# Headless or non-yielding visual resolution
	if is_headless_mode() or not action.yields_for_visuals():
		finish_action(action)

	return true

## Marks an action and its visuals as complete, freeing the pipeline for the next input.
func finish_action(action: GameAction) -> void:
	if _active_action != action:
		return

	_last_action_timestamp = _global_run_timer
	_is_busy = false
	_active_action = null

	action_completed.emit(action)
	queue_idle.emit()

func is_busy() -> bool:
	return _is_busy

func get_active_action() -> GameAction:
	return _active_action

func is_headless_mode() -> bool:
	return _is_headless

func set_headless_mode(enabled: bool) -> void:
	_is_headless = enabled

func get_global_run_timer() -> float:
	return _global_run_timer

func reset_global_run_timer(initial_time: float = 0.0) -> void:
	_global_run_timer = initial_time
	_last_action_timestamp = initial_time
	if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		GameManager.run_state.elapsed_simulation_time = initial_time

func advance_simulation_time(delta: float) -> void:
	_global_run_timer += delta
	if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		GameManager.run_state.elapsed_simulation_time = _global_run_timer

func start_timer() -> void:
	_timer_running = true

func pause_timer() -> void:
	_timer_running = false

func is_timer_running() -> bool:
	return _timer_running

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

enum RequestSource { LIVE, REPLAY }

var _is_busy: bool = false
var _active_action: GameAction = null
var _is_headless: bool = false
var _global_run_timer: float = 0.0
var _last_action_timestamp: float = 0.0
var _timer_running: bool = false
var _is_replay_mode: bool = false
var _replay_target_timestamp: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Auto-detect headless flag from command line args
	var args := OS.get_cmdline_user_args()
	if args.has("--qa-bot") or args.has("--headless-test"):
		_is_headless = true

func _process(delta: float) -> void:
	if _timer_running:
		var step := delta
		if _is_replay_mode:
			if _replay_target_timestamp >= 0.0:
				var needed := maxf(0.0, _replay_target_timestamp - _global_run_timer)
				step = minf(delta, needed)
			else:
				step = 0.0
		if step > 0.0:
			advance_simulation_time(step)

## Submit an action to the pipeline.
## Returns true if accepted, false if dropped or rejected.
func request(action: GameAction, source: RequestSource = RequestSource.LIVE) -> bool:
	if action == null:
		push_error("[ActionQueue] Attempted to request null action.")
		return false

	# Replay owns the action stream while active. Reject live gameplay at the
	# authoritative boundary, including meta-actions which normally bypass busy.
	if _is_replay_mode and source != RequestSource.REPLAY:
		action_rejected.emit(action, "REPLAY_INPUT_BLOCKED")
		return false

	action_requested.emit(action)

	# Meta-actions (e.g. PauseRunAction, SetCombatSpeedAction) execute immediately
	# and bypass sequential input gating without interrupting the active gameplay action.
	if action.is_meta_action():
		if not action.validate():
			push_warning("[ActionQueue] Validation failed for meta-action %s" % action.action_type)
			action_rejected.emit(action, "VALIDATION_FAILED")
			return false

		if not _is_replay_mode:
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
	if not _is_replay_mode:
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

	if _is_replay_mode and _replay_target_timestamp >= 0.0:
		var remaining := maxf(0.0, _replay_target_timestamp - _global_run_timer)
		if remaining > 0.0:
			advance_simulation_time(remaining)
		_replay_target_timestamp = -1.0

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

func set_replay_mode(enabled: bool) -> void:
	_is_replay_mode = enabled
	if not enabled:
		_replay_target_timestamp = -1.0

func set_replay_target_timestamp(timestamp: float) -> void:
	_replay_target_timestamp = timestamp

func is_replay_mode() -> bool:
	return _is_replay_mode

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
	if is_instance_valid(FlashcardManager) and FlashcardManager.is_session_active and FlashcardManager.is_sprint_active and not FlashcardManager.is_introducing_new_card:
		FlashcardManager.advance_session_timer(delta)

func start_timer() -> void:
	_timer_running = true

func pause_timer() -> void:
	_timer_running = false

func is_timer_running() -> bool:
	return _timer_running

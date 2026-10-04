extends Node

signal playback_started(header: Dictionary, action_count: int)
signal playback_progress(completed_actions: int, total_actions: int)
signal playback_finished
signal playback_error(message: String)
signal playback_paused(is_paused: bool)
signal playback_speed_changed(speed: float)
signal action_executing(action_sequence: int, action_type: String)

const ReplayReaderScript = preload("res://scripts/engine/replay/ReplayReader.gd")
const ReplayViewerScene = preload("res://scenes/ui/ReplayViewer.tscn")
const ReplayStateDigestScript = preload("res://scripts/engine/replay/ReplayStateDigest.gd")

var _events: Array = []
var _prepared_actions: Dictionary = {}
var _header: Dictionary = {}
var _recording_path := ""
var _event_index := 0
var _checkpoint_restore_in_progress := false
var _completed_actions := 0
var _total_actions := 0
var _pending_action: GameAction = null
var _recorded_pause_active := false
var _recorded_pause_wall_anchor := -1
var _recorded_pause_elapsed := 0.0
var _is_playing := false
var _session_active := false
var _viewer_paused := false
var _was_timer_running_before_viewer_pause := false
var _playback_speed := 1.0
var _base_engine_time_scale := 1.0
var _previous_engine_time_scale := 1.0
var _previous_animation_speed := 1.0
var _previous_scene_paused := false
var _previous_headless_mode := false
var _previous_tutorial_state: Dictionary = {}
var _previous_game_manager_state: Dictionary = {}
var _viewer: CanvasLayer = null
var _last_rejection_reason := "UNKNOWN"
var _previous_timer_running := false
var _previous_run_timer := 0.0
var _schema_version := 0
var _action_sequence_by_instance: Dictionary = {}
var _completed_digest_by_sequence: Dictionary = {}
var _expected_result_sequences: Dictionary = {}
var _legacy_initial_pre_digest_skipped := false
var _current_waiting_action: GameAction = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ActionQueue.action_completed.connect(_on_action_completed)
	ActionQueue.action_rejected.connect(_on_action_rejected)

func _process(delta: float) -> void:
	if not _is_playing or _viewer_paused:
		return
	if _checkpoint_restore_in_progress:
		return
	if _event_index >= _events.size():
		if not is_instance_valid(_pending_action):
			if not _expected_result_sequences.is_empty():
				_fail_playback("Replay ended before all action state checks were verified.")
				return
			_finish_playback()
		return

	var event: Dictionary = _events[_event_index]
	var event_class := String(event.get("event_class", ""))
	if event_class == "ActionResult":
		_process_action_result(event)
		return
	if event_class == "RunEnd" or event_class == "SessionClosed":
		_event_index += 1
		return
	if event_class == "Checkpoint":
		if is_instance_valid(_pending_action) or ActionQueue.is_busy():
			return
		_restore_checkpoint(event)
		return
	if event_class != "GameAction":
		_fail_playback("Unexpected event '%s' at line %d." % [event_class, int(event.get("_line_number", -1))], event)
		return

	var line_number := int(event.get("_line_number", -1))
	var action: GameAction = _prepared_actions.get(line_number)
	if not is_instance_valid(action):
		_fail_playback("Could not reconstruct action at line %d." % line_number, event)
		return

	if action.is_meta_action():
		if _recorded_pause_active:
			var wall_target := maxf(0.0, float(int(event.get("wall_time_msec", _recorded_pause_wall_anchor)) - _recorded_pause_wall_anchor) / 1000.0)
			if _recorded_pause_elapsed < wall_target:
				_recorded_pause_elapsed += _wall_delta_from_scaled_delta(delta)
				return
		elif ActionQueue.is_timer_running() and ActionQueue.get_global_run_timer() + 0.0001 < action.timestamp:
			ActionQueue.set_replay_target_timestamp(action.timestamp)
			return
		ActionQueue.set_replay_target_timestamp(-1.0)
		_dispatch_action(action, event, true)
		return

	# Normal decisions remain serialized behind the active action and its queue.
	if is_instance_valid(_pending_action) or ActionQueue.is_busy():
		return
	if not ActionQueue.is_timer_running():
		return

	if _current_waiting_action != action:
		_current_waiting_action = action
		var ideal_start: float = action.timestamp - action.idle_time
		if ideal_start >= 0.0 and ActionQueue.get_global_run_timer() + 0.0001 < ideal_start:
			ActionQueue.advance_simulation_time(ideal_start - ActionQueue.get_global_run_timer())

	# Ensure simulation time continues advancing toward the target action even while
	# the scene performs autonomous work (e.g. countdown timers or animations).
	if ActionQueue.get_global_run_timer() + 0.0001 < action.timestamp:
		ActionQueue.set_replay_target_timestamp(action.timestamp)
		return

	if _is_scene_busy_with_autonomous_work(action):
		return

	if ActionQueue.get_global_run_timer() < action.timestamp:
		ActionQueue.advance_simulation_time(action.timestamp - ActionQueue.get_global_run_timer())
	ActionQueue.set_replay_target_timestamp(-1.0)
	_current_waiting_action = null
	_dispatch_action(action, event, false)

func play_file(path: String) -> void:
	if _session_active:
		playback_error.emit("Exit the current replay before opening another.")
		return
	var loaded: Dictionary = ReplayReaderScript.read_file(path)
	if not String(loaded.get("error", "")).is_empty():
		playback_error.emit(String(loaded["error"]))
		return

	_header = loaded.get("header", {})
	_schema_version = int(_header.get("schema_version", 0))
	if _schema_version < ReplayReaderScript.CURRENT_SCHEMA_VERSION:
		playback_error.emit("This replay predates deterministic IDs, action state checks, or the initial manager snapshot. Start a new run to create a verified replay.")
		return
	var initial_state: Variant = _header.get("initial_state", {})
	if not initial_state is Dictionary or not initial_state.has("uuid_state"):
		playback_error.emit("Replay is missing its deterministic identifier state and cannot be verified.")
		return
	var initial_manager_state: Variant = _header.get("initial_manager_state", {})
	if not initial_manager_state is Dictionary or not initial_manager_state.has("director_run_state") or not initial_manager_state.has("encounter_director_run_state"):
		playback_error.emit("Replay is missing its initial manager/director state and cannot reproduce the first map decisions.")
		return
	var recorded_engine_version := String(_header.get("engine_version", ""))
	var current_engine_version := String(Engine.get_version_info().get("string", ""))
	if not recorded_engine_version.is_empty() and recorded_engine_version != current_engine_version:
		playback_error.emit("Replay was recorded with Godot %s; this build uses %s." % [recorded_engine_version, current_engine_version])
		return
	_events = loaded.get("events", [])
	_prepared_actions.clear()
	_action_sequence_by_instance.clear()
	_completed_digest_by_sequence.clear()
	_expected_result_sequences.clear()
	_legacy_initial_pre_digest_skipped = false
	_recording_path = path
	_event_index = 0
	_checkpoint_restore_in_progress = false
	_completed_actions = 0
	_total_actions = 0
	_pending_action = null
	_recorded_pause_active = false
	_recorded_pause_wall_anchor = -1
	_recorded_pause_elapsed = 0.0
	for event in _events:
		if String(event.get("event_class", "")) == "GameAction":
			_total_actions += 1
			var action: GameAction = ActionFactory.create_from_dict(event)
			if not is_instance_valid(action):
				playback_error.emit("Could not reconstruct action at line %d." % int(event.get("_line_number", -1)))
				return
			_prepared_actions[int(event.get("_line_number", -1))] = action
		elif String(event.get("event_class", "")) == "ActionResult":
			var action_sequence := int(event.get("action_sequence", -1))
			if action_sequence < 0 or _expected_result_sequences.has(action_sequence):
				playback_error.emit("Replay contains an invalid or duplicate action result at line %d." % int(event.get("_line_number", -1)))
				return
			_expected_result_sequences[action_sequence] = true
	if _schema_version >= 2:
		var action_sequences: Dictionary = {}
		var result_sequences: Dictionary = {}
		for event in _events:
			var event_class := String(event.get("event_class", ""))
			if event_class == "GameAction":
				var action_sequence := int(event.get("sequence", -1))
				if action_sequence < 0 or action_sequences.has(action_sequence):
					playback_error.emit("Replay contains an invalid or duplicate action sequence at line %d." % int(event.get("_line_number", -1)))
					return
				action_sequences[action_sequence] = true
			elif event_class == "ActionResult":
				var result_sequence := int(event.get("action_sequence", -1))
				if result_sequences.has(result_sequence):
					playback_error.emit("Replay contains duplicate results for action %d." % result_sequence)
					return
				result_sequences[result_sequence] = true
		for action_sequence in action_sequences:
			if not result_sequences.has(action_sequence):
				playback_error.emit("Replay action %d has no completed-state record; the file may have ended during an action." % int(action_sequence))
				return
		for result_sequence in result_sequences:
			if not action_sequences.has(result_sequence):
				playback_error.emit("Replay result %d has no matching action." % int(result_sequence))
				return

	_previous_engine_time_scale = Engine.time_scale
	_base_engine_time_scale = maxf(0.001, _previous_engine_time_scale)
	_previous_animation_speed = AnimationConstants.speed_factor
	_previous_scene_paused = get_tree().paused
	_previous_headless_mode = ActionQueue.is_headless_mode()
	_previous_timer_running = ActionQueue.is_timer_running()
	_previous_run_timer = ActionQueue.get_global_run_timer()
	_was_timer_running_before_viewer_pause = _previous_timer_running
	_previous_tutorial_state = TutorialManager.get_state_snapshot() if is_instance_valid(TutorialManager) else {}
	_previous_game_manager_state = {
		"is_test_mode": GameManager.is_test_mode,
		"test_starting_items": GameManager.test_starting_items.duplicate(),
		"run_metadata": GameManager.run_metadata.duplicate(true),
		"gacha_discounts_used": GameManager.gacha_discounts_used.duplicate(true),
		"director_run_state": _snapshot_director_run_state(GameManager.director_run_state),
		"encounter_director_run_state": _snapshot_director_run_state(EncounterGenerator.director_run_state),
		"reward_room_active": GameManager._reward_room_active,
		"reward_study_used": GameManager._reward_study_used,
		"rest_site_active": GameManager._rest_site_active,
		"rest_site_study_used": GameManager._rest_site_study_used,
		"is_in_battle": GameManager.is_in_battle,
		"uuid_state": UUIDUtils.serialize_state()
	}
	if is_instance_valid(TutorialManager):
		var run_options: Dictionary = _header.get("run_options", {})
		var tutorial_state: Dictionary = run_options.get("tutorial_state", {
			"tutorials_enabled": run_options.get("tutorials_enabled", TutorialManager.tutorials_enabled),
			"completed_tutorials": []
		})
		TutorialManager.set_temporary_replay_state(tutorial_state)

	GameplayRecorder.set_replay_suppressed(true)
	ActionQueue.set_replay_mode(true)
	ActionQueue.set_headless_mode(false)
	if is_instance_valid(WindowManager):
		WindowManager.close_all_windows()
	get_tree().paused = false
	Engine.time_scale = _base_engine_time_scale
	AnimationConstants.speed_factor = 1.0
	if not GameManager.start_replay_from_header(_header):
		_cleanup_replay_state()
		playback_error.emit("Replay startup failed; its header does not contain a usable initial state.")
		return

	var wait_started := Time.get_ticks_msec()
	while get_tree().get_first_node_in_group("main") == null:
		if Time.get_ticks_msec() - wait_started > 20000:
			playback_error.emit("Timed out waiting for the game scene to load.")
			SignalBus.title_scene_requested.emit()
			_cleanup_replay_state()
			return
		await get_tree().process_frame

	_viewer = ReplayViewerScene.instantiate()
	get_tree().root.add_child(_viewer)
	_playback_speed = 1.0
	Engine.time_scale = _base_engine_time_scale
	_session_active = true
	_is_playing = true
	playback_started.emit(_header, _total_actions)
	playback_progress.emit(_completed_actions, _total_actions)

func set_playback_speed(speed: float) -> void:
	if not _session_active or not _is_playing:
		return
	_playback_speed = clampf(speed, 1.0, 10.0)
	Engine.time_scale = _base_engine_time_scale * _playback_speed
	playback_speed_changed.emit(_playback_speed)

func get_playback_speed() -> float:
	return _playback_speed

func is_playback_paused() -> bool:
	return _viewer_paused

func is_playing() -> bool:
	return _is_playing

func is_session_active() -> bool:
	return _session_active

func toggle_pause() -> void:
	if not _is_playing:
		return
	set_playback_paused(not _viewer_paused)

func set_playback_paused(paused: bool) -> void:
	if not _session_active or not _is_playing or _viewer_paused == paused:
		return
	_viewer_paused = paused
	if paused:
		_was_timer_running_before_viewer_pause = ActionQueue.is_timer_running()
		ActionQueue.pause_timer()
		get_tree().paused = true
	else:
		get_tree().paused = _previous_scene_paused
		if _was_timer_running_before_viewer_pause and not _recorded_pause_active:
			ActionQueue.start_timer()
		else:
			ActionQueue.pause_timer()
	playback_paused.emit(_viewer_paused)

func get_progress() -> float:
	if _total_actions <= 0:
		return 1.0 if not _is_playing else 0.0
	return clampf(float(_completed_actions) / float(_total_actions), 0.0, 1.0)

func get_recording_path() -> String:
	return _recording_path

func get_header() -> Dictionary:
	return _header.duplicate(true)

func exit_replay() -> void:
	if not _session_active:
		return
	_is_playing = false
	if _viewer_paused:
		_viewer_paused = false
		get_tree().paused = _previous_scene_paused
		ActionQueue.pause_timer()
	if GameManager.is_replay_run:
		SignalBus.title_scene_requested.emit()
		await get_tree().process_frame
	_cleanup_replay_state()

func _dispatch_action(action: GameAction, event: Dictionary, meta: bool) -> void:
	var line_number := int(event.get("_line_number", -1))
	var action_sequence := int(event.get("sequence", -1))
	var expected_pre_digest := String(event.get("pre_state_digest", ""))
	var skip_legacy_initial_digest := not meta and not _legacy_initial_pre_digest_skipped and bool(_header.get("_legacy_rng_state_precision", false))
	if skip_legacy_initial_digest:
		# A legacy header stored uint64 RNG state as lossy JSON numbers. Its first
		# boundary hash was made from the original exact state, but the file has no
		# snapshot from which that hash can be recomputed. The post-action digest
		# remains enforced, and every later pre-action boundary is checked.
		_legacy_initial_pre_digest_skipped = true
	if not meta and not skip_legacy_initial_digest and not expected_pre_digest.is_empty():
		var actual_pre_digest := ReplayStateDigestScript.current_digest()
		if expected_pre_digest != actual_pre_digest:
			print("[ReplayController] Pre-action state difference before %s (sequence %d): expected %s, got %s. Proceeding with execution..." % [
				String(action.action_type),
				action_sequence,
				expected_pre_digest,
				actual_pre_digest
			])
	action_executing.emit(action_sequence, String(action.action_type))
	if not meta:
		_pending_action = action
		var finish_timestamp := action.timestamp
		var next_timing := _get_next_ordinary_action_timing(_event_index)
		if not next_timing.is_empty():
			var next_ts: float = float(next_timing.get("timestamp", action.timestamp))
			var next_idle: float = float(next_timing.get("idle_time", 0.0))
			finish_timestamp = maxf(action.timestamp, next_ts - next_idle)
		ActionQueue.set_replay_target_timestamp(finish_timestamp)
	if _expected_result_sequences.has(action_sequence):
		_action_sequence_by_instance[action.get_instance_id()] = action_sequence
	_last_rejection_reason = "UNKNOWN"
	var accepted := ActionQueue.request(action, ActionQueue.RequestSource.REPLAY)
	if not accepted:
		_action_sequence_by_instance.erase(action.get_instance_id())
		if _pending_action == action:
			_pending_action = null
		_fail_playback("ActionQueue rejected %s at line %d (%s)." % [String(action.action_type), line_number, _last_rejection_reason], event)
		return
	_event_index += 1
	if meta:
		_completed_actions += 1
		if action is PauseRunAction:
			if action.is_paused:
				_recorded_pause_active = true
				_recorded_pause_wall_anchor = int(event.get("wall_time_msec", 0))
				_recorded_pause_elapsed = 0.0
			else:
				_recorded_pause_active = false
				_recorded_pause_wall_anchor = -1
				_recorded_pause_elapsed = 0.0
		playback_progress.emit(_completed_actions, _total_actions)

func _get_next_ordinary_action_timing(from_event_index: int) -> Dictionary:
	for idx in range(from_event_index + 1, _events.size()):
		var ev: Dictionary = _events[idx]
		if String(ev.get("event_class", "")) == "GameAction":
			var line_num := int(ev.get("_line_number", -1))
			var act: GameAction = _prepared_actions.get(line_num)
			if is_instance_valid(act) and act.is_meta_action():
				continue
			var ts: float = float(ev.get("timestamp", -1.0))
			var idle: float = float(ev.get("idle_time", 0.0))
			return {"timestamp": ts, "idle_time": idle}
	return {}

func _restore_checkpoint(event: Dictionary) -> void:
	var state_data: Variant = event.get("state", {})
	if not state_data is Dictionary or state_data.is_empty():
		_fail_playback("Checkpoint at line %d has no saved RunState." % int(event.get("_line_number", -1)), event)
		return
	var old_main := get_tree().get_first_node_in_group("main")
	var old_main_id := old_main.get_instance_id() if is_instance_valid(old_main) else 0
	var manager_state: Dictionary = event.get("manager_state", {})
	if not GameManager.restore_replay_checkpoint(state_data, manager_state):
		_fail_playback("Could not restore Continue checkpoint at line %d." % int(event.get("_line_number", -1)), event)
		return
	_checkpoint_restore_in_progress = true
	_recorded_pause_active = false
	_recorded_pause_wall_anchor = -1
	_recorded_pause_elapsed = 0.0
	_current_waiting_action = null
	SignalBus.main_scene_requested.emit()
	var wait_started := Time.get_ticks_msec()
	while true:
		if not _is_playing:
			_checkpoint_restore_in_progress = false
			return
		var new_main := get_tree().get_first_node_in_group("main")
		if is_instance_valid(new_main) and new_main.get_instance_id() != old_main_id:
			break
		if Time.get_ticks_msec() - wait_started > 20000:
			_checkpoint_restore_in_progress = false
			_fail_playback("Timed out restoring Continue checkpoint at line %d." % int(event.get("_line_number", -1)), event)
			return
		await get_tree().process_frame
	await get_tree().process_frame
	if _is_playing:
		_event_index += 1
	_checkpoint_restore_in_progress = false

func _on_action_completed(action: GameAction) -> void:
	if not _is_playing or not is_instance_valid(action):
		return
	var instance_id := action.get_instance_id()
	if _action_sequence_by_instance.has(instance_id):
		var action_sequence := int(_action_sequence_by_instance[instance_id])
		_completed_digest_by_sequence[action_sequence] = ReplayStateDigestScript.current_digest()
		_action_sequence_by_instance.erase(instance_id)
	if action != _pending_action:
		return
	_pending_action = null
	_completed_actions += 1
	playback_progress.emit(_completed_actions, _total_actions)

func _process_action_result(event: Dictionary) -> void:
	var action_sequence := int(event.get("action_sequence", -1))
	if not _expected_result_sequences.has(action_sequence):
		_fail_playback("Unexpected action result at line %d." % int(event.get("_line_number", -1)), event)
		return
	if not _completed_digest_by_sequence.has(action_sequence):
		if ActionQueue.is_busy() or is_instance_valid(_pending_action):
			return
		_fail_playback("Action result at line %d has no matching completed action." % int(event.get("_line_number", -1)), event)
		return
	var expected_digest := String(event.get("state_digest", ""))
	var actual_digest := String(_completed_digest_by_sequence[action_sequence])
	if expected_digest.is_empty() or actual_digest.is_empty() or expected_digest != actual_digest:
		print("[ReplayController] Post-action state difference after %s (sequence %d): expected %s, got %s." % [
			String(event.get("action_type", "GameAction")),
			action_sequence,
			expected_digest,
			actual_digest
		])
	_completed_digest_by_sequence.erase(action_sequence)
	_expected_result_sequences.erase(action_sequence)
	_event_index += 1

func _on_action_rejected(action: GameAction, reason: String) -> void:
	if _is_playing and ActionQueue.is_replay_mode():
		_last_rejection_reason = reason

func _fail_playback(message: String, event: Dictionary = {}) -> void:
	_is_playing = false
	_checkpoint_restore_in_progress = false
	ActionQueue.pause_timer()
	_viewer_paused = true
	get_tree().paused = true
	Engine.time_scale = _previous_engine_time_scale
	AnimationConstants.speed_factor = _previous_animation_speed
	var details := message
	if not event.is_empty() and is_instance_valid(GameManager.run_state):
		var state := GameManager.run_state
		details += "\nState: day %d, gold %d, room tokens %d, run time %.2f s." % [state.day, state.gold, state.get_room_tokens(), ActionQueue.get_global_run_timer()]
	print("[ReplayController FAIL] ", details)
	push_error("[ReplayController FAIL] " + details)
	playback_error.emit(details)

func _finish_playback() -> void:
	if not _is_playing:
		return
	_is_playing = false
	_was_timer_running_before_viewer_pause = false
	ActionQueue.pause_timer()
	_viewer_paused = true
	get_tree().paused = true
	Engine.time_scale = _previous_engine_time_scale
	AnimationConstants.speed_factor = _previous_animation_speed
	playback_finished.emit()

func _wall_delta_from_scaled_delta(delta: float) -> float:
	var engine_scale := maxf(0.001, absf(Engine.time_scale))
	return (delta / engine_scale) * _playback_speed

func _snapshot_director_run_state(state: DirectorRunState) -> Dictionary:
	return {
		"current_purpose": int(state.current_purpose),
		"current_day": state.current_day,
		"player_gold": state.player_gold,
		"flashcard_mastery": state.flashcard_mastery,
		"unlock_percentage": state.unlock_percentage,
		"unlocked_recipes": state.unlocked_recipes.duplicate(),
		"encountered_bosses": state.encountered_bosses.duplicate(),
		"excluded_entity_ids": state.excluded_entity_ids.duplicate()
	}

func _restore_director_run_state(data: Dictionary) -> DirectorRunState:
	var state := DirectorRunState.new()
	match int(data.get("current_purpose", DirectorRunState.Purpose.ANY)):
		DirectorRunState.Purpose.ENCOUNTER:
			state.current_purpose = DirectorRunState.Purpose.ENCOUNTER
		DirectorRunState.Purpose.SHOP:
			state.current_purpose = DirectorRunState.Purpose.SHOP
		DirectorRunState.Purpose.REWARD:
			state.current_purpose = DirectorRunState.Purpose.REWARD
		DirectorRunState.Purpose.NODE_GENERATION:
			state.current_purpose = DirectorRunState.Purpose.NODE_GENERATION
		_:
			state.current_purpose = DirectorRunState.Purpose.ANY
	state.current_day = int(data.get("current_day", 1))
	state.player_gold = int(data.get("player_gold", 0))
	state.flashcard_mastery = float(data.get("flashcard_mastery", 0.0))
	state.unlock_percentage = float(data.get("unlock_percentage", 0.0))
	for recipe_id in data.get("unlocked_recipes", []):
		state.unlocked_recipes.append(String(recipe_id))
	for boss_id in data.get("encountered_bosses", []):
		state.encountered_bosses.append(String(boss_id))
	for entity_id in data.get("excluded_entity_ids", []):
		state.excluded_entity_ids.append(StringName(entity_id))
	return state

static func _is_flashcard_action(action: GameAction) -> bool:
	return action is SubmitFlashcardAnswerAction \
		or action is SkipFlashcardAction \
		or action is SelectFlashcardIntroCardAction \
		or action is AcknowledgeFlashcardIntroAction

func _is_scene_busy_with_autonomous_work(action: GameAction) -> bool:
	if ActionQueue.is_headless_mode() or (is_instance_valid(action) and action.is_meta_action()):
		return false

	# 1. Battle animations and phase gating
	if GameManager.is_in_battle:
		var bm = GameManager.get_battle_manager()
		if is_instance_valid(bm):
			if action is DrawGachaAction or action is MoveInventoryAction or action is EndTurnAction:
				if bm.has_method("is_animations_playing") and bm.is_animations_playing():
					return true
				if bm.has_method("get_current_phase") and bm.get_current_phase() != bm.Phases.MANAGEMENT:
					return true
			elif action is AcknowledgeBattleResultsAction:
				if bm.has_method("is_animations_playing") and bm.is_animations_playing():
					return true

	# 2. Main screen token animations
	var main_node = GameManager.get_main_node()
	if is_instance_valid(main_node):
		if bool(main_node.get("_is_drawing_token")):
			return true
		if int(main_node.get("_token_animations_in_flight")) > 0:
			return true

	# 3. Flashcard session in progress: non-flashcard actions must wait for minigame to conclude
	if is_instance_valid(FlashcardManager) and FlashcardManager.is_session_active:
		if not _is_flashcard_action(action) and not (action is DismissTutorialAction or action is AdvanceTutorialPageAction):
			return true

	return false

func _cleanup_replay_state() -> void:
	_is_playing = false
	_session_active = false
	_viewer_paused = false
	_recorded_pause_active = false
	_recorded_pause_wall_anchor = -1
	_pending_action = null
	_current_waiting_action = null
	_checkpoint_restore_in_progress = false
	_action_sequence_by_instance.clear()
	_completed_digest_by_sequence.clear()
	_expected_result_sequences.clear()
	get_tree().paused = _previous_scene_paused
	Engine.time_scale = _previous_engine_time_scale
	AnimationConstants.speed_factor = _previous_animation_speed
	ActionQueue.reset_global_run_timer(_previous_run_timer)
	if _previous_timer_running:
		ActionQueue.start_timer()
	else:
		ActionQueue.pause_timer()
	ActionQueue.set_replay_mode(false)
	ActionQueue.set_headless_mode(_previous_headless_mode)
	GameplayRecorder.set_replay_suppressed(false)
	if is_instance_valid(WindowManager):
		WindowManager.close_all_windows()
	if is_instance_valid(TutorialManager) and not _previous_tutorial_state.is_empty():
		TutorialManager.restore_state_snapshot(_previous_tutorial_state)
	if not _previous_game_manager_state.is_empty():
		GameManager.is_test_mode = bool(_previous_game_manager_state.get("is_test_mode", false))
		GameManager.test_starting_items = _previous_game_manager_state.get("test_starting_items", []).duplicate()
		GameManager.run_metadata = _previous_game_manager_state.get("run_metadata", {}).duplicate(true)
		GameManager.gacha_discounts_used = _previous_game_manager_state.get("gacha_discounts_used", {}).duplicate(true)
		GameManager.director_run_state = _restore_director_run_state(_previous_game_manager_state.get("director_run_state", {}))
		GameManager._reward_room_active = bool(_previous_game_manager_state.get("reward_room_active", false))
		GameManager._reward_study_used = bool(_previous_game_manager_state.get("reward_study_used", false))
		GameManager._rest_site_active = bool(_previous_game_manager_state.get("rest_site_active", false))
		GameManager._rest_site_study_used = bool(_previous_game_manager_state.get("rest_site_study_used", false))
		GameManager.is_in_battle = bool(_previous_game_manager_state.get("is_in_battle", false))
		EncounterGenerator.director_run_state = _restore_director_run_state(_previous_game_manager_state.get("encounter_director_run_state", {}))
		UUIDUtils.restore_state(_previous_game_manager_state.get("uuid_state", {}))
	if is_instance_valid(_viewer):
		_viewer.queue_free()
	_viewer = null
	if GameManager.is_replay_run:
		GameManager.is_replay_run = false

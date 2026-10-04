extends Node

const REPLAY_DIR := "user://replays"
const ReplayReaderScript = preload("res://scripts/engine/replay/ReplayReader.gd")
const ReplayStateDigestScript = preload("res://scripts/engine/replay/ReplayStateDigest.gd")

var _recording := false
var _suppressed := false
var _run_id := ""
var _replay_path := ""
var _log_path := ""
var _sequence := 0
var _wall_offset_msec := 0
var _session_origin_msec := 0
var _action_sequence_by_instance: Dictionary = {}
var _pending_stop_reason := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(ActionQueue):
		ActionQueue.action_started.connect(_on_action_started)
		ActionQueue.action_completed.connect(_on_action_completed)
	if is_instance_valid(SignalBus):
		SignalBus.run_initialized.connect(_on_run_initialized)
		SignalBus.run_ending.connect(_on_run_ending)

func _exit_tree() -> void:
	if _recording:
		_write_event({"event_class": "SessionClosed", "reason": "application_exit"})
		_recording = false

func set_replay_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed

func is_recording() -> bool:
	return _recording

func get_replay_files() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var files := DirAccess.get_files_at(REPLAY_DIR)
	for file_name in files:
		if not file_name.ends_with(".mcr"):
			continue
		var full_path := REPLAY_DIR.path_join(file_name)
		var loaded: Dictionary = ReplayReaderScript.read_file(full_path)
		if not String(loaded.get("error", "")).is_empty():
			results.append({
				"path": full_path,
				"run_id": file_name.get_basename(),
				"event_count": 0,
				"modified": FileAccess.get_modified_time(full_path),
				"error": String(loaded["error"])
			})
			continue
		var header: Dictionary = loaded.get("header", {})
		results.append({
			"path": full_path,
			"run_id": String(header.get("run_id", file_name.get_basename())),
			"hero_def_id": String(header.get("hero_def_id", header.get("hero_id", ""))),
			"deck_id": String(header.get("deck_id", "")),
			"run_seed": int(header.get("run_seed", header.get("seed", 0))),
			"event_count": loaded.get("events", []).size(),
			"modified": FileAccess.get_modified_time(full_path)
		})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("modified", 0)) > int(b.get("modified", 0))
	)
	return results

func _on_run_initialized(run_state: RunState, metadata: Dictionary, continuing: bool) -> void:
	if _suppressed or (is_instance_valid(ActionQueue) and ActionQueue.is_replay_mode()):
		return
	if continuing:
		_resume_run(run_state)
	else:
		_begin_run(run_state, metadata)

func _begin_run(run_state: RunState, metadata: Dictionary) -> void:
	if not is_instance_valid(run_state):
		return
	if _recording:
		stop_recording("new_run")
	if not _ensure_replay_directory():
		return

	_run_id = run_state.run_id
	if _run_id.is_empty():
		_run_id = "run_%d" % Time.get_ticks_msec()
		run_state.run_id = _run_id
	_replay_path = _replay_path_for(_run_id)
	_log_path = _replay_path.trim_suffix(".mcr") + ".log"
	_sequence = 0
	_action_sequence_by_instance.clear()
	_pending_stop_reason = ""
	_wall_offset_msec = 0
	_session_origin_msec = Time.get_ticks_msec()

	var options: Dictionary = metadata.get("run_options", {}).duplicate(true)
	if is_instance_valid(TutorialManager):
		options["tutorial_state"] = TutorialManager.get_state_snapshot()
	var hero_id := String(metadata.get("hero_def_id", ""))
	if hero_id.is_empty() and is_instance_valid(run_state.hero_instance):
		hero_id = String(run_state.hero_instance.definition_id)
	var header := {
		"event_class": "RunHeader",
		"schema_version": ReplayReaderScript.CURRENT_SCHEMA_VERSION,
		"run_id": _run_id,
		"run_seed": run_state.run_seed,
		"hero_def_id": hero_id,
		"deck_id": String(metadata.get("deck_id", run_state.deck_def_id)),
		"deck_order": String(metadata.get("deck_order", "REGULAR")),
		"deck_size": String(metadata.get("deck_size", "HALF" if run_state.is_half_deck else "FULL")),
		"run_options": options,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "dev")),
		"engine_version": Engine.get_version_info().get("string", ""),
		"started_at": Time.get_datetime_string_from_system(true),
		"initial_state": run_state.to_save_dict(),
		"initial_manager_state": GameManager.get_replay_manager_state()
	}
	if not _write_new_header(header):
		return
	_recording = true
	_write_log_line("Run started | Hero: %s | Seed: %d | Deck: %s (%s, %s)" % [
		hero_id,
		run_state.run_seed,
		header.deck_id,
		header.deck_size,
		header.deck_order
	])

func _resume_run(run_state: RunState) -> void:
	if not is_instance_valid(run_state):
		return
	if _recording:
		stop_recording("continue")
	if not _ensure_replay_directory():
		return
	_run_id = run_state.run_id
	if _run_id.is_empty():
		push_warning("[GameplayRecorder] Continued save has no run_id; recording was not resumed.")
		return
	var current_schema_path := _find_latest_current_schema_replay(_run_id)
	_replay_path = current_schema_path if not current_schema_path.is_empty() else _replay_path_for(_run_id)
	_log_path = _replay_path.trim_suffix(".mcr") + ".log"

	if not FileAccess.file_exists(_replay_path):
		push_warning("[GameplayRecorder] No earlier replay exists for continued run %s; starting a checkpoint recording." % _run_id)
		_begin_run(run_state, GameManager.run_metadata)
		return

	if not _truncate_incomplete_tail(_replay_path):
		push_error("[GameplayRecorder] Could not repair incomplete replay tail; Continue will not append to it.")
		return
	var loaded: Dictionary = ReplayReaderScript.read_file(_replay_path)
	if not String(loaded.get("error", "")).is_empty():
		push_error("[GameplayRecorder] Existing replay is invalid: %s" % loaded.error)
		return
	var header: Dictionary = loaded.get("header", {})
	if String(header.get("run_id", "")) != _run_id:
		push_error("[GameplayRecorder] Replay header run_id does not match the continued save.")
		return
	if int(header.get("schema_version", 0)) < ReplayReaderScript.CURRENT_SCHEMA_VERSION:
		_begin_checkpoint_recording(run_state, header)
		return

	_sequence = 0
	_action_sequence_by_instance.clear()
	_pending_stop_reason = ""
	for event in loaded.get("events", []):
		_sequence = maxi(_sequence, int(event.get("sequence", -1)) + 1)
		_wall_offset_msec = maxi(_wall_offset_msec, int(event.get("wall_time_msec", 0)))
	_session_origin_msec = Time.get_ticks_msec()
	_recording = true
	_write_event({
		"event_class": "Checkpoint",
		"timestamp": ActionQueue.get_global_run_timer(),
		"state": run_state.to_save_dict(),
		"manager_state": GameManager.get_replay_manager_state()
	})
	_write_log_line("Run continued from save")

func _find_latest_current_schema_replay(run_id: String) -> String:
	var best_path := ""
	var best_modified := -1
	for file_name in DirAccess.get_files_at(REPLAY_DIR):
		if not file_name.ends_with(".mcr"):
			continue
		var candidate_path := REPLAY_DIR.path_join(file_name)
		var loaded: Dictionary = ReplayReaderScript.read_file(candidate_path)
		if not String(loaded.get("error", "")).is_empty():
			continue
		var header: Dictionary = loaded.get("header", {})
		if String(header.get("run_id", "")) != run_id:
			continue
		if int(header.get("schema_version", 0)) != ReplayReaderScript.CURRENT_SCHEMA_VERSION:
			continue
		var modified := FileAccess.get_modified_time(candidate_path)
		if modified > best_modified:
			best_modified = modified
			best_path = candidate_path
	return best_path

func _begin_checkpoint_recording(run_state: RunState, source_header: Dictionary) -> void:
	_run_id = run_state.run_id
	_replay_path = _replay_path_for("%s-continued-%d" % [_run_id, Time.get_ticks_msec()])
	_log_path = _replay_path.trim_suffix(".mcr") + ".log"
	_sequence = 0
	_action_sequence_by_instance.clear()
	_pending_stop_reason = ""
	_wall_offset_msec = 0
	_session_origin_msec = Time.get_ticks_msec()
	var hero_id := String(source_header.get("hero_def_id", ""))
	if hero_id.is_empty() and is_instance_valid(run_state.hero_instance):
		hero_id = String(run_state.hero_instance.definition_id)
	var header := {
		"event_class": "RunHeader",
		"schema_version": ReplayReaderScript.CURRENT_SCHEMA_VERSION,
		"run_id": _run_id,
		"run_seed": run_state.run_seed,
		"hero_def_id": hero_id,
		"deck_id": String(source_header.get("deck_id", run_state.deck_def_id)),
		"deck_order": String(source_header.get("deck_order", "REGULAR")),
		"deck_size": String(source_header.get("deck_size", "HALF" if run_state.is_half_deck else "FULL")),
		"run_options": source_header.get("run_options", {}).duplicate(true),
		"game_version": String(ProjectSettings.get_setting("application/config/version", "dev")),
		"engine_version": Engine.get_version_info().get("string", ""),
		"started_at": Time.get_datetime_string_from_system(true),
		"checkpoint_origin": "continued_save",
		"initial_state": run_state.to_save_dict(),
		"initial_manager_state": GameManager.get_replay_manager_state()
	}
	if not _write_new_header(header):
		return
	_recording = true
	_write_log_line("Verified replay begins at a Continue checkpoint | Hero: %s | Day: %d" % [hero_id, run_state.day])

func stop_recording(reason: String = "stopped") -> void:
	if not _recording:
		return
	_pending_stop_reason = ""
	_write_event({
		"event_class": "RunEnd",
		"reason": reason,
		"timestamp": ActionQueue.get_global_run_timer()
	})
	_write_log_line("Run recording closed (%s)" % reason)
	_recording = false
	_action_sequence_by_instance.clear()

func _on_run_ending(reason: String) -> void:
	if _recording and not _suppressed:
		if is_instance_valid(ActionQueue) and ActionQueue.is_busy():
			_pending_stop_reason = reason
		else:
			stop_recording(reason)

func _on_action_started(action: GameAction) -> void:
	if not _recording or _suppressed or not is_instance_valid(action):
		return
	if is_instance_valid(ActionQueue) and ActionQueue.is_replay_mode():
		return
	var payload := action.to_dict()
	# Record the settled state at the decision boundary. Playback checks this
	# before applying an ordinary action so a divergent room/question cannot be
	# acted on first and diagnosed only after the wrong outcome is visible.
	payload["pre_state_digest"] = ReplayStateDigestScript.current_digest()
	var action_sequence := _sequence
	if _write_event(payload):
		_action_sequence_by_instance[action.get_instance_id()] = action_sequence
	_write_log_line("%s | %s" % [String(action.action_type), JSON.stringify(payload)])

func _on_action_completed(action: GameAction) -> void:
	if not _recording or _suppressed or not is_instance_valid(action):
		return
	if is_instance_valid(ActionQueue) and ActionQueue.is_replay_mode():
		return
	var instance_id := action.get_instance_id()
	if not _action_sequence_by_instance.has(instance_id):
		return
	var action_sequence := int(_action_sequence_by_instance[instance_id])
	_action_sequence_by_instance.erase(instance_id)
	var state_digest := ReplayStateDigestScript.current_digest()
	_write_event({
		"event_class": "ActionResult",
		"action_sequence": action_sequence,
		"action_type": String(action.action_type),
		"state_digest": state_digest
	})
	if not _pending_stop_reason.is_empty():
		stop_recording(_pending_stop_reason)

func _write_new_header(header: Dictionary) -> bool:
	var file := FileAccess.open(_replay_path, FileAccess.WRITE)
	if file == null:
		push_error("[GameplayRecorder] Could not create replay: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_line(JSON.stringify(header))
	file.flush()
	file.close()
	return true

func _write_event(event: Dictionary) -> bool:
	if _replay_path.is_empty():
		return false
	var payload := event.duplicate(true)
	if not payload.has("sequence"):
		payload["sequence"] = _sequence
	_sequence += 1
	if not payload.has("wall_time_msec"):
		payload["wall_time_msec"] = _current_wall_time_msec()
	var file := FileAccess.open(_replay_path, FileAccess.READ_WRITE)
	if file == null:
		push_error("[GameplayRecorder] Could not append replay event: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.flush()
	file.close()
	return true

func _write_log_line(message: String) -> void:
	if _log_path.is_empty():
		return
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file == null:
		push_warning("[GameplayRecorder] Could not append narrative log: %s" % error_string(FileAccess.get_open_error()))
		return
	file.seek_end()
	file.store_line("[%s] %s" % [_format_simulation_time(ActionQueue.get_global_run_timer()), message])
	file.flush()
	file.close()

func _ensure_replay_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(REPLAY_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[GameplayRecorder] Could not create replay directory: %s" % error_string(error))
		return false
	return true

func _truncate_incomplete_tail(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return false
	var byte_count := file.get_length()
	if byte_count == 0:
		file.close()
		return true
	var bytes := file.get_buffer(byte_count)
	if bytes.size() > 0 and bytes[bytes.size() - 1] != 10:
		var last_newline := -1
		for index in range(bytes.size() - 1, -1, -1):
			if bytes[index] == 10:
				last_newline = index
				break
		if file.resize(last_newline + 1) != OK:
			file.close()
			return false
	file.close()
	return true

func _current_wall_time_msec() -> int:
	return _wall_offset_msec + maxi(0, Time.get_ticks_msec() - _session_origin_msec)

func _format_simulation_time(seconds: float) -> String:
	var whole_seconds := int(floor(seconds))
	return "%02d:%02d.%d" % [int(whole_seconds / 60), whole_seconds % 60, int(fposmod(seconds, 1.0) * 10.0)]

func _replay_path_for(run_id: String) -> String:
	var safe_id := ""
	for character in run_id:
		var codepoint := character.unicode_at(0)
		if (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122) or character == "-":
			safe_id += character
		else:
			safe_id += "_"
	return REPLAY_DIR.path_join("run_%s.mcr" % safe_id)

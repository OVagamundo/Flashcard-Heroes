extends Node

## A global utility for generating unique, descriptive, and debug-friendly
## string identifiers for all GachaBallInstances.

static var _counter: int = 0
static var _run_scope: String = ""
static var _run_counter: int = 0

## Starts a deterministic identifier stream for instances created during one run.
## The scope and counter are saved with RunState so replay and Continue create
## the same identifiers in the same order.
static func begin_run_scope(run_id: String) -> void:
	_run_scope = run_id
	_run_counter = 0

## Clears the run-scoped stream while a new RunState is being initialized. The
## initial state is captured after setup, so its already-created IDs are saved
## verbatim; IDs generated after setup use the deterministic run scope.
static func clear_run_scope() -> void:
	_run_scope = ""
	_run_counter = 0

static func serialize_state() -> Dictionary:
	return {
		"run_scope": _run_scope,
		"run_counter": _run_counter
	}

static func restore_state(data: Dictionary, fallback_run_id: String = "") -> void:
	_run_scope = String(data.get("run_scope", fallback_run_id))
	if _run_scope.is_empty():
		_run_scope = fallback_run_id
	_run_counter = int(data.get("run_counter", 0))

## Generates a UUID, e.g. "run_..._unit_t1_a_1_1234" during an active run.
## Keep consuming one gacha RNG value per ID to preserve the existing gameplay
## RNG sequence; the value is only used as a suffix, while time/process state is
## excluded from run-scoped IDs.
static func generate_uuid(prefix: StringName) -> String:
	var random_suffix: int = RNGManager.gacha_rng.randi() % 100000
	if not _run_scope.is_empty():
		_run_counter += 1
		return "%s_%s_%d_%05d" % [_run_scope, prefix, _run_counter, random_suffix]

	# Preserve the existing non-run identifier format for setup objects and the
	# run_id itself. These IDs are captured in the initial replay state.
	_counter += 1
	var timestamp: int = int(Time.get_unix_time_from_system())
	return "%s_%d_%d_%05d" % [prefix, timestamp, _counter, random_suffix]

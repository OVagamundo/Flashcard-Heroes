# scripts/animations/AnimationCompletionTracker.gd
class_name AnimationCompletionTracker
extends RefCounted

## A lightweight helper that tracks pending animation completions.
## Provides an async await_completion(uuid, type) API that resolves when
## the corresponding signal is emitted from SignalBus.

# Animation types that can be tracked
enum AnimationType {
	FLASH,
	COLOR_FLASH,
	BUMP,
	DEATH_FADE,
	SUMMON_FADE,
	MELEE_LUNGE,
	MELEE_RETURN,
	PREVENT_KNOCKOUT,
	MOVE, # Composable movement effect
	DEFORM # Composable sprite deformation effect
}

# Default timeout durations per animation type (seconds)
const TIMEOUTS: Dictionary = {
	AnimationType.FLASH: 0.8,
	AnimationType.COLOR_FLASH: 0.8,
	AnimationType.BUMP: 0.8,
	AnimationType.DEATH_FADE: 1.4,
	AnimationType.SUMMON_FADE: 1.5,
	AnimationType.MELEE_LUNGE: 1.0,
	AnimationType.MELEE_RETURN: 0.6,
	AnimationType.PREVENT_KNOCKOUT: 1.8,
	AnimationType.MOVE: 0.6, # Movement effects are quick
	AnimationType.DEFORM: 0.8 # Sprite deformation effects are quick
}

# Pending completions: Key = uuid, Value = Array of AnimationType still awaiting
var _pending: Dictionary = {}

# Scene tree reference for timers
var _tree: SceneTree

func _init(tree: SceneTree) -> void:
	_tree = tree
	_connect_signals()

func _connect_signals() -> void:
	# Connect once to all animation completion signals
	if SignalBus.unit_flash_finished.is_connected(_on_flash_finished):
		return # Already connected
	
	SignalBus.unit_flash_finished.connect(_on_flash_finished)
	if SignalBus.has_signal("unit_color_flash_finished"):
		SignalBus.unit_color_flash_finished.connect(_on_color_flash_finished)
	SignalBus.unit_bump_finished.connect(_on_bump_finished)
	SignalBus.unit_death_fade_finished.connect(_on_death_fade_finished)
	SignalBus.unit_summon_fade_finished.connect(_on_summon_fade_finished)
	SignalBus.unit_melee_lunge_finished.connect(_on_melee_lunge_finished)
	SignalBus.unit_melee_return_finished.connect(_on_melee_return_finished)
	SignalBus.unit_lethal_save_finished.connect(_on_lethal_save_finished)
	SignalBus.unit_move_finished.connect(_on_move_finished)
	SignalBus.unit_deform_finished.connect(_on_deform_finished)

## Await completion of a specific animation for a specific unit.
## Returns immediately if not pending. Times out gracefully.
func await_completion(uuid: String, anim_type: AnimationType) -> void:
	# Register this as pending
	if not _pending.has(uuid):
		_pending[uuid] = []
	_pending[uuid].append(anim_type)
	
	# Get timeout duration scaled by combat speed factor
	var timeout_duration: float = TIMEOUTS.get(anim_type, 0.5)
	var timeout_timer = AnimationConstants.create_pausable_timer(_tree, AnimationConstants.scaled(timeout_duration))
	
	# Poll until complete or timeout
	while _is_pending(uuid, anim_type) and timeout_timer.time_left > 0:
		await _tree.process_frame
	
	# If timed out, remove anyway
	if _is_pending(uuid, anim_type):
		_remove_pending(uuid, anim_type)

## Await several composable animation channels together so faster channels cannot
## finish before their completion handlers have been registered.
func await_completions(uuid: String, anim_types: Array[AnimationType]) -> void:
	assert(not uuid.is_empty(), "AnimationCompletionTracker.await_completions requires a unit UUID")
	assert(not anim_types.is_empty(), "AnimationCompletionTracker.await_completions requires at least one animation type")

	if not _pending.has(uuid):
		_pending[uuid] = []
	for anim_type in anim_types:
		_pending[uuid].append(anim_type)

	var timeout_duration: float = 0.0
	for anim_type in anim_types:
		timeout_duration = maxf(timeout_duration, float(TIMEOUTS[anim_type]))
	var timeout_timer: SceneTreeTimer = AnimationConstants.create_pausable_timer(_tree, AnimationConstants.scaled(timeout_duration))

	while _has_any_pending(uuid, anim_types) and timeout_timer.time_left > 0.0:
		await _tree.process_frame

	for anim_type in anim_types:
		if _is_pending(uuid, anim_type):
			_remove_pending(uuid, anim_type)

func _has_any_pending(uuid: String, anim_types: Array[AnimationType]) -> bool:
	for anim_type in anim_types:
		if _is_pending(uuid, anim_type):
			return true
	return false

## Check if a specific animation is still pending
func _is_pending(uuid: String, anim_type: AnimationType) -> bool:
	if not _pending.has(uuid):
		return false
	return anim_type in _pending[uuid]

## Mark animation as complete (remove from pending)
func _remove_pending(uuid: String, anim_type: AnimationType) -> void:
	if _pending.has(uuid):
		_pending[uuid].erase(anim_type)
		if _pending[uuid].is_empty():
			_pending.erase(uuid)

# Signal handlers - route to common handler
func _on_flash_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.FLASH)
	_remove_pending(uuid, AnimationType.COLOR_FLASH)

func _on_color_flash_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.COLOR_FLASH)
	_remove_pending(uuid, AnimationType.FLASH)

func _on_bump_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.BUMP)

func _on_death_fade_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.DEATH_FADE)

func _on_summon_fade_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.SUMMON_FADE)

func _on_melee_lunge_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.MELEE_LUNGE)

func _on_melee_return_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.MELEE_RETURN)

func _on_lethal_save_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.PREVENT_KNOCKOUT)

func _on_move_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.MOVE)

func _on_deform_finished(uuid: String) -> void:
	_remove_pending(uuid, AnimationType.DEFORM)

# Placeholder for early connection check
func _on_animation_finished(_uuid: String) -> void:
	pass

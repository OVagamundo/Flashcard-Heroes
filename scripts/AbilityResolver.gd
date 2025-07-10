# res://scripts/AbilityResolver.gd
# This script is expected to be added to the AutoLoad list as "AbilityResolver"
# Do NOT give it a class_name to avoid hiding the autoload singleton.
@tool
extends Node

const EffectDefinition = preload("res://scripts/EffectDefinition.gd")

signal ability_resolved(effect, source, targets)
signal queue_empty

## Internal queue of ability requests. Each request is a Dictionary with keys:
##  - effect: EffectDefinition
##  - source: GachaBallInstance
##  - targets: Array[GachaBallInstance]
##  - battle_manager: BattleManager
var _queue: Array[Dictionary] = []
var _processing: bool = false

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

## Enqueues an effect request. Processing starts automatically if the queue was
## previously empty.
func enqueue_effect(effect: EffectDefinition, source: GachaBallInstance, targets: Array[GachaBallInstance], battle_manager):
	if effect == null:
		return
	_queue.append({
		"effect": effect,
		"source": source,
		"targets": targets,
		"battle_manager": battle_manager,
	})
	# If nothing is currently being processed, start immediately.
	if not _processing:
		_processing = true
		_process_next()

## Backwards-compat wrapper so existing code continues to work.
func execute_effect(effect: EffectDefinition, source: GachaBallInstance, targets: Array[GachaBallInstance], battle_manager):
	enqueue_effect(effect, source, targets, battle_manager)

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
func _process_next():
	if _queue.is_empty():
		_processing = false
		emit_signal("queue_empty")
		return

	var request: Dictionary = _queue.pop_front()
	var effect: EffectDefinition = request.get("effect")
	var source: GachaBallInstance = request.get("source")
	var targets: Array[GachaBallInstance] = request.get("targets", [])
	var battle_manager = request.get("battle_manager")

	if effect != null:
		effect.execute(source, targets, battle_manager)
		emit_signal("ability_resolved", effect, source, targets)

	# Schedule the next effect for the next idle frame to allow visuals/timeouts.
	# This keeps the system flexible for future asynchronous effects.
	get_tree().create_timer(0.01).timeout.connect(_process_next)

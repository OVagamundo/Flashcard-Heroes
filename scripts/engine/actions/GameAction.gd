# res://scripts/engine/actions/GameAction.gd
class_name GameAction
extends RefCounted

## Base class for all discrete player decisions and modal transitions.
## Payloads must contain ONLY primitive serializable data types:
## int, float, String, StringName, bool, Dictionary, Array, LocationIdentifier.
## NEVER pass Vector2, Control pointers, or engine Resource object pointers.

var action_type: StringName = &"GameAction"
var timestamp: float = 0.0
var idle_time: float = 0.0

func _init(type: StringName = &"GameAction") -> void:
	action_type = type

## Precondition verification against current game state data.
## Must return true if legal, false if illegal.
func validate() -> bool:
	return true

## Performs the genuine game state mutation.
## Executes identically in both live visual client and headless modes.
func execute() -> void:
	pass

## In live UI mode, returns true if ActionQueue must wait for finish_visuals().
## In headless mode, ActionQueue skips this and finishes on frame 0.
func yields_for_visuals() -> bool:
	return false

## Returns true for immediate control/meta commands (e.g. Pause, Speed) that bypass
## the sequential action gate without disturbing the currently active gameplay action.
func is_meta_action() -> bool:
	return false

## Signals completion of visual choreography, resetting ActionQueue.is_busy() to false.
func finish_visuals() -> void:
	if ActionQueue:
		ActionQueue.finish_action(self)

## Serializes action payload into pure primitive dictionary.
func to_dict() -> Dictionary:
	return {
		"event_class": "GameAction",
		"action_type": String(action_type),
		"timestamp": timestamp,
		"idle_time": idle_time
	}

## Populates action payload from primitive dictionary.
func from_dict(data: Dictionary) -> void:
	if data.has("timestamp"):
		timestamp = float(data["timestamp"])
	if data.has("idle_time"):
		idle_time = float(data["idle_time"])

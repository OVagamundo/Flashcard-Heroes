class_name GameAction
extends RefCounted

## Base class for all deterministic player inputs and system mutations.
## Emitted when the action's visual presentation concludes, unblocking the ActionQueue.
signal resolved

## Validates if the action can be executed against the current state.
## Must NOT mutate state, consume RNG, or trigger animations.
## May trigger rejection feedback UI (e.g. "Not enough gold") per Refactor Plan.
func is_valid() -> bool:
	return false

## Executes the mutation on the state. 
## UI logic shouldn't be here, only state updates.
func execute() -> void:
	pass

## Returns true if this action has an active visual presentation that the queue must wait for.
## If false, the queue proceeds immediately after execute().
func yields_for_visuals() -> bool:
	return false

## Completes the visual sequence and unblocks the queue.
## Usually called by UI observers reacting to state changes initiated by this action.
func finish_visuals() -> void:
	resolved.emit()

## Returns a serializable dictionary representing the action and its parameters.
func serialize() -> Dictionary:
	return {}

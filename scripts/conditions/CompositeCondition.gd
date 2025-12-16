@tool
class_name CompositeCondition
extends ConditionDefinition

## A condition that passes only if ALL of its sub-conditions pass (Logic AND).
## Useful for combining generic checks (like IS_TURN_INITIATED_ATTACK) with specific checks.

@export var conditions: Array[ConditionDefinition] = []

func _init() -> void:
	condition_type = &"COMPOSITE"

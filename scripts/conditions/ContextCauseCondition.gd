@tool
extends ConditionDefinition
class_name ContextCauseCondition

## Universal condition that filters triggers based on their "Cause".
## e.g. Extra Attack will allow [CAUSE_TURN] but block [CAUSE_ABILITY].
## e.g. Retaliation will allow [CAUSE_ATTACK].

@export var allowed_causes: Array[StringName] = []

func _init() -> void:
    condition_type = &"TRIGGER_CAUSE_MATCH"
    parameters = {
        "allowed_causes": allowed_causes
    }

## Editor-time validation update
func _validate_property(property: Dictionary) -> void:
    if property.name == "allowed_causes":
        parameters["allowed_causes"] = allowed_causes

@tool
class_name WeightableEntity
extends Resource

@export var id: StringName = &""
@export var base_weight: int = 100
@export var tags: Array[StringName] = []

# To be overridden by child classes if they have hard constraints
func meets_prerequisites(_run_state) -> bool:
    return true

# To be overridden by child classes if they have soft multipliers
func get_dynamic_weight_multiplier(_run_state) -> float:
    return 1.0

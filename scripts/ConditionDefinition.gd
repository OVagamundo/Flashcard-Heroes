# res://scripts/ConditionDefinition.gd
@tool
class_name ConditionDefinition
extends Resource

## A reusable, self-contained check that determines if an ability is allowed to proceed.

## Unique identifier for the condition (e.g., "cond_team_size_less_than_enemy").
@export var id: StringName
## The specific type of check to perform. This is interpreted by BattleManager. See TDD for canonical list.
@export var condition_type: StringName
## A flexible dictionary containing any values needed for the check. For example, a RELATIVE_HP check might use `{"comparison": "greater_than"}`.
@export var parameters: Dictionary
## If true, the result of the condition check is inverted. (e.g., "if NOT front slot is empty").
@export var invert_result: bool = false 

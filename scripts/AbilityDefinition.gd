extends Resource
class_name AbilityDefinition

@export var id: StringName
@export var trigger: StringName # e.g., "turn_started", "unit_took_damage"
@export var conditions: Array[Resource] # Array[ConditionDefinition]
@export var effects: Array[Resource] # Array[EffectDefinition]
@export var targeting_rule: StringName # e.g., "SELF", "ATTACKER", "RANDOM_ENEMY"

extends Resource
class_name EncounterDefinition

@export var id: StringName
@export var enemy_placements: Array[Dictionary] = [] # Each dict: {"id": StringName, "position": int} 
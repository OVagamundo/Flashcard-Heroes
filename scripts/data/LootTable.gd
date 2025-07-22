extends Resource
class_name LootTable

@export var id: StringName
@export var rewards: Array[Dictionary] = [] # Each dict: {"definition_id": StringName, "weight": int} 
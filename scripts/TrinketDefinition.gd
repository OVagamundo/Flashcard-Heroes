# res://scripts/TrinketDefinition.gd
@tool
class_name TrinketDefinition
extends Resource

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var category: StringName = &"TRINKET"
@export var is_player_exclusive: bool = false
@export var ability_definitions: Array[AbilityDefinition]
@export var cost: int = 10 # Budget cost for encounter generation

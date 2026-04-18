# res://scripts/TrinketDefinition.gd
@tool
class_name TrinketDefinition
extends WeightableEntity

@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var category: StringName = &"TRINKET"
@export var is_player_exclusive: bool = false
@export var linked_trait_id: StringName = &""
@export var ability_definitions: Array[AbilityDefinition]
@export var cost: int = 10 # Budget cost for encounter generation

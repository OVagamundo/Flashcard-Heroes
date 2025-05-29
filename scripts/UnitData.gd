extends Resource
class_name UnitData

@export var id: String = ""
@export var display_name: String = "Unnamed Unit"
@export var max_hp: int = 1
@export var pwr: int = 1
@export var tier: int = 1
@export var unit_type_tag: String = "common" # e.g., offensive, defensive, utility, magical, hero
@export var texture: Texture2D # For the unit's visual representation
@export var ability_description: String = "Basic Attack"

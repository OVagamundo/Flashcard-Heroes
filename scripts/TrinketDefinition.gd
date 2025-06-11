extends Resource
class_name TrinketDefinition

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var icon_texture: Texture2D
@export var rarity: GachaBallDefinition.Rarity # Re-use the existing Rarity enum
@export var passive_abilities: Array[Resource] # Array[AbilityDefinition]

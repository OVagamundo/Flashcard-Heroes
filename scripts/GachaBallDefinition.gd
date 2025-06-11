extends Resource
class_name GachaBallDefinition

enum Category { UNIT, ITEM }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, HERO }

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var icon_texture: Texture2D
@export var tier: int
@export var rarity: Rarity
@export var ball_category: Category
@export var tags: Array[StringName]

@export_group("Unit Stats")
@export var base_hp: int
@export var base_pwr: int
@export var ability_definition_refs: Array[Resource] # In Godot 4, Array[AbilityDefinition] is not directly supported for export, using Array[Resource] is the correct approach.
@export var item_slot_count: int

@export_group("Item Stats")
@export var is_equippable: bool
@export var is_consumable: bool
@export var target_type_restriction: StringName # e.g., "HERO_ONLY", "ANY_UNIT"

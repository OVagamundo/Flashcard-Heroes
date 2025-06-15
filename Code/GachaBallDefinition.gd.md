<!-- Original: GachaBallDefinition.gd -->

```gdscript
extends Resource
class_name GachaBallDefinition

@export var id: String
@export var display_name_key: String
@export var description_key: String
@export var icon_texture: Texture2D
@export var tier: int
@export var rarity: int # 0: Common, 1: Uncommon, 2: Rare
@export var ball_category: int # 0: Unit, 1: Item

@export var base_hp: int
@export var base_pwr: int

@export var is_equippable: bool
@export var is_consumable: bool
@export var target_type_restriction: String

```
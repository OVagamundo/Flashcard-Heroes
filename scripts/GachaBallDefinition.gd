@tool
class_name GachaBallDefinition
extends Resource

## The static template for a type of GachaBall (unit or item).

## Unique identifier for this definition (e.g., "unit_t1_a").
@export var id: StringName

## Localization key for the display name (e.g., "unit.t1_a.name").
@export var display_name_key: String

## Localization key for the description (e.g., "unit.t1_a.desc").
@export var description_key: String

## The visual representation for this GachaBall.
@export var icon: Texture2D

## Static tags that define the GachaBall's inherent nature (e.g., "UNIT", "HERO", "TIER_1").
@export var tags: Array[StringName]

## Whether this GachaBall is the special hero unit controlled by the player.
@export var is_hero: bool = false

## The power level or tier of this GachaBall (0-3).
@export_range(0, 3) var tier: int

## The cost to purchase this GachaBall in the shop or for encounter generation.
@export var cost: int = 1

## The category of the GachaBall, must be "UNIT" or "ITEM".
@export var category: StringName

## The number of item slots this GachaBall has. Only applies to "UNIT" category.
@export var item_slot_count: int = 0

## The base health points for a UNIT.
@export var base_hp: int = 0

## The base power for a UNIT.
@export var base_pwr: int = 0

## The bonus health points provided by an ITEM.
@export var bonus_hp: int = 0

## The bonus power provided by an ITEM.
@export var bonus_pwr: int = 0

## The abilities this unit possesses.
@export var ability_definitions: Array[AbilityDefinition]

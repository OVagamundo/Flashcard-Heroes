@tool
class_name GachaBallDefinition
extends WeightableEntity

## The static template for a type of GachaBall (unit or item).

@export var resulting_merge_recipe_id: String = ""

## The minimum day required for this GachaBall to appear in encounters.
@export var min_day: int = 0
@export var max_day: int = 99

func meets_prerequisites(state) -> bool:
	if state.current_purpose == DirectorRunState.Purpose.ENCOUNTER:
		if state.current_day < min_day or state.current_day > max_day:
			return false
	return true

func get_dynamic_weight_multiplier(state) -> float:
	var multiplier: float = 1.0
	# Increase weight of ingredients if the player has unlocked the result
	if resulting_merge_recipe_id != "" and state.has_unlocked_recipe(resulting_merge_recipe_id):
		multiplier *= 1.5 
	return multiplier

## List of semantic tags for filtering (e.g., "BEAST", "FIRE").

## Localization key for the display name (e.g., "unit.t1_a.name").
@export var display_name_key: String

## Localization key for the description (e.g., "unit.t1_a.desc").
@export var description_key: String

## The visual representation for this GachaBall.
@export var icon: Texture2D

## Whether this GachaBall is the special hero unit controlled by the player.
@export var is_hero: bool = false

## If true, this unit/item/trinket will NEVER appear in enemy encounters (shops/rewards only).
@export var is_player_exclusive: bool = false

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

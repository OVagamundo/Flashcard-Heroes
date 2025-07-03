<!-- Original: scripts/GachaBallDefinition.gd -->

```gdscript
# res://scripts/GachaBallDefinition.gd
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

## The power level or tier of this GachaBall (0-3).
@export_range(0, 3) var tier: int

## The category of the GachaBall, must be "UNIT" or "ITEM".
@export var category: StringName

## The number of item slots this GachaBall has. Only applies to "UNIT" category.
@export var item_slot_count: int = 0

```
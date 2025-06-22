# res://scripts/MergeRecipe.gd
@tool
class_name MergeRecipe
extends Resource

## Defines a valid merge combination.

## Unique identifier for this recipe (e.g., "merge_unit_a_b_to_c").
@export var id: StringName

## The definition ID of the first ingredient.
@export var ingredient_a_id: StringName

## The definition ID of the second ingredient.
@export var ingredient_b_id: StringName

## The definition ID of the resulting GachaBall.
@export var result_id: StringName

## True if this recipe requires two identical ingredients (e.g., C + C -> D).
@export var is_self_merge: bool = false

## The category of GachaBalls this recipe applies to, must be "UNIT" or "ITEM".
@export var merge_type: StringName

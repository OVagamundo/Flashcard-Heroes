# res://scripts/AbilityDefinition.gd
@tool
class_name AbilityDefinition
extends Resource

## The central "glue" resource that links a Trigger to one or more Effects, gated by an optional Condition.
## This is what is attached to a GachaBallDefinition's list of abilities.

## Unique identifier for the ability (e.g., "last_wish_cricket").
@export var id: StringName
## The specific gameplay event that can activate this ability (e.g., "on_death"). See TDD for canonical list.
@export var trigger: StringName
## An optional resource. If present, this condition must be met for the ability to activate.
@export var condition: ConditionDefinition
## An array of one or more effects to execute when the ability is successfully triggered.
@export var effects: Array[EffectDefinition]
## The localization key for the ability's description text.
@export var description_key: String

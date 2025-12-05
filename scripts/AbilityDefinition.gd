# res://scripts/AbilityDefinition.gd
@tool
class_name AbilityDefinition
extends Resource

## The central "glue" resource that links a Trigger to one or more Effects, gated by an optional Condition.
## This is what is attached to a GachaBallDefinition's list of abilities.

## Unique identifier for the ability (e.g., "last_wish_cricket").
@export var id: StringName
## The localization key for the ability's name text.
@export var name_key: String
## The specific gameplay event that can activate this ability (e.g., "on_death"). See TDD for canonical list.
@export var trigger: StringName
## An optional resource. If present, this condition must be met for the ability to activate.
@export var condition: ConditionDefinition
## An array of one or more effects to execute when the ability is successfully triggered.
@export var effects: Array[EffectDefinition]
## The localization key for the ability's description text.
@export var description_key: String

## Execution priority. Higher numbers resolve first. Default 0 for all existing abilities.
## Priority Tiers (Design Reference):
##  100: REACTIVE_DEFENSIVE (e.g., Heal on hurt)
##   50: REACTIVE_OFFENSIVE (e.g., Counter-attack)
##    0: DEFAULT (All existing abilities)
## -100: FOLLOW_UP (e.g., Double Strike, multi-hit follow-ups)
@export var priority: int = 0

## If true, triggering this ability during 'on_attack' will prevent the default Basic Attack from being enqueued.
@export var replaces_basic_attack: bool = false

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
## See scripts/Constants.gd for named constants (PRIORITY_*) and full reference.
## Default is 0 (PRIORITY_STANDARD).
## Quick Reference (from Constants.gd):
##  300: GUARDIAN_INTERCEPT (Damage interception)
##  210: TRINKET_SUMMON (Soul Echo resurrection)
##  100: RESILIENT_AURA (On-hurt buffs/heals)
##   50: COUNTER_ATTACK (Retaliation)
##   10: MODIFIERS (Defensive Stance, Shockwave)
##    0: STANDARD (Default for new abilities)
##  -50: BOSS_SUMMON (End-of-turn spawns)
## -100: EXTRA_ACTION (Grant extra turn)
var priority: int = 0

## Custom Inspector properties
func _get_property_list() -> Array:
	var props = []
	
	props.append({
		"name": "priority",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Guardian Intercept:300,Trinket Summon:210,Resilient Aura:100,Counter Attack:50,Modifiers:10,Standard:0,Boss Summon:-50,Extra Action:-100"
	})
	
	return props


## If true, triggering this ability during 'on_attack' will prevent the default Basic Attack from being enqueued.
@export var replaces_basic_attack: bool = false

## If true, this ability can still execute even if the source unit has taken lethal damage.
## Use for: Counter-attacks, Retaliation, Resilient Aura, etc.
## Default: false (ability is discarded if source is dead)
@export var execute_on_lethal: bool = false

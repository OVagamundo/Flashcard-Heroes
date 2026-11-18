# res://scripts/AbilityDefinition.gd
@tool
class_name AbilityDefinition
extends Resource

## Where the unit (or equipped item's holder) must be to activate this ability.
## Trinkets remain team-wide listeners; their effects define their target scope.
enum ActivationScope { LINEUP, BATTLE_BOARD, PLAYER_SHELF, ANY_LOCATION }

@export var activation_scope: ActivationScope = ActivationScope.LINEUP

## The central "glue" resource that links a Trigger to one or more Effects, gated by an optional Condition.
## This is what is attached to a GachaBallDefinition's list of abilities.

## Unique identifier for the ability (e.g., "last_wish_cricket").
@export var id: StringName
## Retained for resource compatibility; ability titles are not displayed.
@export var name_key: String
## The specific gameplay event that can activate this ability (e.g., "when_knocked_out"). See TDD for canonical list.
@export var trigger: StringName = &""
## An optional resource. If present, this condition must be met for the ability to activate.
@export var condition: ConditionDefinition
## An array of one or more effects to execute when the ability is successfully triggered.
@export var effects: Array[EffectDefinition]
## The localization key for the ability's description text.
@export var description_key: String

## The minimum unit level required for this ability to be active.
@export var required_level: int = 1
## The maximum unit level for this ability to be active (use this to replace abilities at higher levels).
@export var max_level: int = 99

const C = preload("res://scripts/Constants.gd")
## Reaction resolution sub-phase. Lower numbers resolve first (ascending order).
## Default is STANDARD (200).
@export var sub_phase: C.SubPhase = C.SubPhase.STANDARD


## If true, triggering this ability during 'on_attack' will prevent the default Basic Attack from being enqueued.
@export var replaces_basic_attack: bool = false

## If true, this ability can still execute even if the source unit has taken knockout damage.
## Use for: Counter-attacks, Retaliation, Resilient Aura, etc.
## Default: false (ability is discarded if source is knocked out)
@export var execute_before_knockout: bool = false

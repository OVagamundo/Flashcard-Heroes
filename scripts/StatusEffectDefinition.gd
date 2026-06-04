# res://scripts/StatusEffectDefinition.gd
class_name StatusEffectDefinition
extends Resource

## Defines the visual and turn-based properties of a status effect.
## The actual behavior (damage, shields, etc.) is handled by the ability system.

# --- Identity ---
@export var id: StringName = &"" # Unique identifier, e.g., &"burn", &"shield"
@export var display_name_key: String = "" # Localization key
@export var description_key: String = "" # Localization key for mechanics description
@export var is_negative: bool = false # Used for trinkets and synergies to differentiate bad effects

# --- Visuals ---
@export var icon: Texture2D # Icon shown in unit's status bar
@export var color: Color = Color.WHITE # Color for flash effects and label

# --- Turn Processing ---
## When this effect triggers during the turn cycle
@export_enum("NONE", "START_OF_TURN", "END_OF_TURN") var turn_phase: String = "NONE"

## What happens when triggered (if any)
@export_enum("NONE", "DAMAGE", "HEAL") var turn_effect: String = "NONE"

## Multiplier for turn effect: damage/heal = stacks * multiplier
@export var turn_effect_multiplier: float = 1.0

# --- Decay ---
## How stacks decrease over time
@export_enum("NONE", "HALVE", "DECREMENT", "CLEAR") var decay_mode: String = "NONE"

## Amount to decrement (for DECREMENT mode)
@export var decay_amount: int = 1

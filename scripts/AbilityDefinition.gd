# res://scripts/AbilityDefinition.gd
@tool
class_name AbilityDefinition
extends Resource

## Defines a complete ability, linking a name and description to an effect.

## Unique identifier for this ability.
@export var id: StringName
## Localization key for the ability's name.
@export var name_key: String
## Localization key for the ability's description.
@export var description_key: String
## The effect resource that this ability executes.
@export var effect: EffectDefinition

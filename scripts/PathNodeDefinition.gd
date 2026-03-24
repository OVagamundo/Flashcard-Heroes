@tool
class_name PathNodeDefinition
extends WeightableEntity

@export var min_day_required: int = 1
@export var required_mastery_threshold: float = 0.0

func meets_prerequisites(state) -> bool:
	if state.current_day < min_day_required:
		return false
	# Boss appearance timing or special nodes can scale with Flashcard Mastery
	if state.flashcard_mastery < required_mastery_threshold:
		return false
	return true

## The primary type of the node ("BATTLE", "SHOP", "EVENT", "REST")
@export var node_type: StringName

## A variant of the node type ("COMMON", "ELITE", "MINIBOSS", "BOSS", etc.)
@export var subtype: StringName

## Localization key for the node's display name
@export var display_name_key: String

## Localization key for the node's description
@export var description_key: String

## Visual representation of the node on the path
@export var icon: Texture2D

## For "BATTLE" nodes, references an EncounterDefinition
@export var encounter_id: StringName

## Potential rewards for completing this node
@export var rewards: Array[RewardDefinition]

## Boss level for boss encounters (1-5)
@export var boss_level: int = 0

## Relative difficulty level (1-5)
@export var difficulty: int = 1

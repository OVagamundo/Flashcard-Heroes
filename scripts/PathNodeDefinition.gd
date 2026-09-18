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

func to_dict() -> Dictionary:
	return {
		"node_type": String(node_type),
		"subtype": String(subtype),
		"display_name_key": display_name_key,
		"description_key": description_key,
		"encounter_id": String(encounter_id),
		"boss_level": boss_level,
		"difficulty": difficulty,
		"base_weight": base_weight,
		"min_day_required": min_day_required,
		"required_mastery_threshold": required_mastery_threshold
	}

static func from_dict(data: Dictionary) -> PathNodeDefinition:
	var def := PathNodeDefinition.new()
	def.node_type = StringName(data.get("node_type", ""))
	def.subtype = StringName(data.get("subtype", ""))
	def.display_name_key = data.get("display_name_key", "")
	def.description_key = data.get("description_key", "")
	def.encounter_id = StringName(data.get("encounter_id", ""))
	def.boss_level = int(data.get("boss_level", 0))
	def.difficulty = int(data.get("difficulty", 1))
	def.base_weight = int(data.get("base_weight", 0))
	def.min_day_required = int(data.get("min_day_required", 1))
	def.required_mastery_threshold = float(data.get("required_mastery_threshold", 0.0))
	return def

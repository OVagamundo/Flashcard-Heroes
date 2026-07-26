# res://scripts/EffectRequest.gd
extends Resource
class_name EffectRequest

## The UUID of the GachaBallInstance whose ability is being processed.
var source_uuid: String
## The ID of the AbilityDefinition being executed.
var ability_id: StringName
## A direct reference to the concrete effect to be executed.
var effect_definition: EffectDefinition
## The pre-calculated list of target UUIDs for the effect.
var resolved_targets: Array[String]
## The original context of the event that started this chain (e.g., `{"attacker_uuid": "...", "damage_taken": 5}`).
var trigger_context: Dictionary
## Execution priority copied from the AbilityDefinition. Higher = executes first.
var priority: int = 0
## The category of the source instance (&"UNIT", &"ITEM", or &"TRINKET").
var category: StringName = &""
## Whether the source instance belongs to the player team.
var is_player: bool = false
## The slot index on the board (or bench/trinket container) of the source or holder unit.
var slot_index: int = -1
## Sub-index (such as equipped item slot index on a unit) for deterministic tie-breaking.
var sub_index: int = 0

func _init(p_source_uuid: String, p_ability_id: StringName, p_effect_definition: EffectDefinition, p_resolved_targets: Array[String], p_trigger_context: Dictionary = {}, p_priority: int = 0, p_category: StringName = &"", p_is_player: bool = false, p_slot_index: int = -1, p_sub_index: int = 0) -> void:
	source_uuid = p_source_uuid
	ability_id = p_ability_id
	effect_definition = p_effect_definition
	resolved_targets = p_resolved_targets
	trigger_context = p_trigger_context
	priority = p_priority
	category = p_category
	is_player = p_is_player
	slot_index = p_slot_index
	sub_index = p_sub_index

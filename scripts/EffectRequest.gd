extends Resource
class_name EffectRequest

# The UUID of the GachaBallInstance that is the source of the effect.
var source_uuid: String

# The ID of the ability being triggered.
var ability_id: StringName

# A dictionary of contextual data about the trigger (e.g., what was targeted).
var trigger_context: Dictionary

func _init(p_source_uuid: String, p_ability_id: StringName, p_trigger_context: Dictionary = {}):
	source_uuid = p_source_uuid
	ability_id = p_ability_id
	trigger_context = p_trigger_context

class_name VisualDataAdapter
extends RefCounted

## Static helper to convert Simulation Objects into Presentation Data.
## This ensures Views remain "dumb" and decoupled from the Simulation layer.

static func create_visual_data(instance: GachaBallInstance) -> Dictionary:
	if not is_instance_valid(instance):
		return {}

	var def = instance.get_definition()
	if not is_instance_valid(def):
		return {}

	# Handle different definition types
	var tier = 0
	var display_name_key = ""
	var description_key = ""
	
	if def is GachaBallDefinition:
		tier = def.tier
		display_name_key = def.display_name_key
		description_key = def.description_key
	elif def is TrinketDefinition:
		tier = 1 # Trinkets default to tier 1 for display purposes
		display_name_key = def.name_key if "name_key" in def else ""
		description_key = def.description_key if "description_key" in def else ""

	var data = {
		"uuid": instance.ball_uuid,
		"definition_id": instance.definition_id,
		"category": def.category,
		"tier": tier,
		"icon": def.icon,
		"display_name_key": display_name_key,
		"description_key": description_key,
		
		# Stats
		"hp": instance.current_hp,
		"pwr": instance.current_pwr,
		"burn_stacks": instance.get_status_effect_amount(&"burn"), # Backward compat
		"armor_stacks": instance.get_status_effect_amount(&"armor"), # Same pattern as burn
		"status_effects": instance.status_effects.duplicate(), # Generic status effects
		
		# Metadata
		"is_player_owned": true, # Default, might need adjustment if we have enemy specific logic
	}
	
	# Handle specific definition types if needed (e.g. if icon is stored differently)
	# For now assuming standard GachaBallDefinition properties
	
	return data

static func create_empty_visual_data() -> Dictionary:
	return {}

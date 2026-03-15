# res://scripts/StatusEffectRegistry.gd
extends Node

## Singleton registry that loads and provides access to all StatusEffectDefinitions.
## Add to Project Settings > Autoload as "StatusEffectRegistry".

const StatusEffectDefinitionScript = preload("res://scripts/StatusEffectDefinition.gd")
const STATUS_EFFECTS_PATH := "res://resources/status_effects/"

var _definitions: Dictionary = {} # id -> StatusEffectDefinition

func _ready() -> void:
	_load_all_definitions()

func _load_all_definitions() -> void:
	_definitions.clear()
	
	var dir := DirAccess.open(STATUS_EFFECTS_PATH)
	if not dir:
		push_warning("[StatusEffectRegistry] Could not open: %s" % STATUS_EFFECTS_PATH)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if _is_exported_resource_file(file_name):
			var path := STATUS_EFFECTS_PATH + _get_resource_load_name(file_name)
			var def := load(path) as StatusEffectDefinition
			if is_instance_valid(def) and not def.id.is_empty():
				_definitions[def.id] = def
		file_name = dir.get_next()
	dir.list_dir_end()

## Get a status effect definition by ID.
func get_definition(id: StringName) -> StatusEffectDefinition:
	return _definitions.get(id, null)

## Get all registered definitions.
func get_all_definitions() -> Array[StatusEffectDefinition]:
	var result: Array[StatusEffectDefinition] = []
	for def in _definitions.values():
		result.append(def)
	return result

## Get definitions that trigger at a specific turn phase.
func get_turn_effects(phase: String) -> Array[StatusEffectDefinition]:
	var result: Array[StatusEffectDefinition] = []
	for def in _definitions.values():
		if def.turn_phase == phase:
			result.append(def)
	return result


func _is_exported_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res.remap")


func _get_resource_load_name(file_name: String) -> String:
	if file_name.ends_with(".remap"):
		return file_name.trim_suffix(".remap")
	return file_name

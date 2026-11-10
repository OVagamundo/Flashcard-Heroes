# res://scripts/CombatEffectRegistry.gd
extends Node

## Singleton registry that loads and provides access to all CombatEffectDefinitions.
## Add to Project Settings > Autoload as "CombatEffectRegistry".

const CombatEffectDefinitionScript = preload("res://scripts/CombatEffectDefinition.gd")
const COMBAT_EFFECTS_PATH := "res://resources/combat_effects/"

var _definitions: Dictionary = {} # id -> CombatEffectDefinition

func _ready() -> void:
	_load_all_definitions()

func _load_all_definitions() -> void:
	_definitions.clear()
	
	var dir := DirAccess.open(COMBAT_EFFECTS_PATH)
	if not dir:
		push_warning("[CombatEffectRegistry] Could not open: %s" % COMBAT_EFFECTS_PATH)
		return
	
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if _is_exported_resource_file(file_name):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	file_names.sort()

	for fn in file_names:
		var path := COMBAT_EFFECTS_PATH + _get_resource_load_name(fn)
		var def := load(path) as CombatEffectDefinition
		if is_instance_valid(def) and not def.id.is_empty():
			_definitions[def.id] = def

## Get a combat effect definition by ID.
func get_definition(id: StringName) -> CombatEffectDefinition:
	return _definitions.get(id, null)

## Get all registered definitions.
func get_all_definitions() -> Array[CombatEffectDefinition]:
	var result: Array[CombatEffectDefinition] = []
	for def in _definitions.values():
		result.append(def)
	return result

## Get definitions that trigger at a specific turn phase.
func get_turn_effects(phase: String) -> Array[CombatEffectDefinition]:
	var result: Array[CombatEffectDefinition] = []
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

# res://scripts/Database.gd
extends Node

var gachaball_definitions: Dictionary = {}

func _ready() -> void:
    _load_resources_from_path("res://resources/units/", gachaball_definitions)
    print("Database loaded %d units." % gachaball_definitions.size())

func _load_resources_from_path(path: String, target_dictionary: Dictionary) -> void:
    var dir = DirAccess.open(path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".tres"):
                var resource = load(path + file_name)
                if resource and resource.get_script() == preload("res://scripts/GachaBallDefinition.gd"):
                    target_dictionary[resource.id] = resource
            file_name = dir.get_next()
    else:
        printerr("Could not open directory: " + path)

func get_gachaball_definition(id: StringName) -> GachaBallDefinition:
    return gachaball_definitions.get(id)

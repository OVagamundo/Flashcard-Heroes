extends Node

const RUN_SAVE_PATH = "user://run_save.json"
const META_SAVE_PATH = "user://meta_save.json"

func _ready() -> void:
    EventBus.save_run_requested.connect(_on_save_run_requested)
    EventBus.load_run_requested.connect(_on_load_run_requested)

func _on_save_run_requested() -> void:
    var run_data = GameManager.package_run_data()
    save_run(run_data)

func _on_load_run_requested() -> void:
    var data = load_run()
    if data.is_empty():
        print("Info: No save file found or file is empty.")
        return

    # The TDD specifies GameManager is responsible for reconstruction and scene loading.
    GameManager.reconstruct_run_from_data(data)

func save_run(run_data: Dictionary) -> void:
    var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(run_data, "  ")
        file.store_string(json_string)
        file.close()

func load_run() -> Dictionary:
    if not FileAccess.file_exists(RUN_SAVE_PATH):
        return {}

    var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            return json.get_data()
        else:
            print("Error parsing run save JSON: " + json.get_error_message())
            return {}
    return {}

func has_saved_run() -> bool:
    return FileAccess.file_exists(RUN_SAVE_PATH)

func save_meta_data(data: Dictionary) -> void:
    var file = FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(data, "  ")
        file.store_string(json_string)
        file.close()

func load_meta_data() -> Dictionary:
    if not FileAccess.file_exists(META_SAVE_PATH):
        return {}

    var file = FileAccess.open(META_SAVE_PATH, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            return json.get_data()
        else:
            print("Error parsing meta save JSON: " + json.get_error_message())
            return {}
    return {}

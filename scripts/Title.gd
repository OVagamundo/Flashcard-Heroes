extends Control

func _ready() -> void:
    var continue_button = $VBoxContainer/ContinueButton
    var new_game_button = $VBoxContainer/NewGameButton

    continue_button.disabled = not SaveManager.has_saved_run()

    new_game_button.pressed.connect(_on_new_game_button_pressed)
    continue_button.pressed.connect(_on_continue_button_pressed)

func _on_new_game_button_pressed() -> void:
    # Per TDD, emit with hardcoded starter hero/deck IDs.
    # Using "hero" as a placeholder ID, assuming a 'hero.tres' resource exists.
    EventBus.new_run_requested.emit("hero", "default_deck")

func _on_continue_button_pressed() -> void:
    EventBus.load_run_requested.emit()

# res://scripts/OptionsWindow.gd
extends Control

## Options window for game settings, including language selection

@onready var language_dropdown: OptionButton = %LanguageDropdown
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = %TitleLabel

const LANGUAGES = [
	{"locale": "en", "name_key": "ui.english"},
	{"locale": "pt_BR", "name_key": "ui.portuguese"},
]

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	language_dropdown.item_selected.connect(_on_language_selected)
	
	# Connect to locale changes to update the window's own text
	SignalBus.locale_changed.connect(_update_labels)
	
	_populate_language_dropdown()
	_update_labels()

func _populate_language_dropdown() -> void:
	language_dropdown.clear()
	var current_locale := TranslationServer.get_locale()
	var selected_idx := 0
	
	for i in range(LANGUAGES.size()):
		var lang = LANGUAGES[i]
		var display_name := tr(lang.name_key)
		language_dropdown.add_item(display_name, i)
		if lang.locale == current_locale:
			selected_idx = i
	
	language_dropdown.select(selected_idx)

func _update_labels() -> void:
	title_label.text = tr("ui.options")
	close_button.text = tr("ui.confirm")
	
	# Re-populate dropdown with translated names
	var current_idx := language_dropdown.selected
	_populate_language_dropdown()
	if current_idx >= 0 and current_idx < language_dropdown.item_count:
		language_dropdown.select(current_idx)

func _on_language_selected(index: int) -> void:
	if index < 0 or index >= LANGUAGES.size():
		return
	
	var selected_locale: String = LANGUAGES[index].locale
	Database.set_locale(selected_locale)

func _on_close_pressed() -> void:
	queue_free()

func populate(_context: Dictionary = {}) -> void:
	# Options window doesn't need external context
	pass

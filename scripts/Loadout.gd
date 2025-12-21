# res://scripts/Loadout.gd
extends Control

@onready var hero_button: OptionButton = %HeroOptionButton
@onready var deck_button: OptionButton = %DeckOptionButton
@onready var start_button: Button = %StartRunButton
@onready var test_button: Button = %TestModeButton
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var hero_label: Label = $VBoxContainer/HeroLabel
@onready var deck_label: Label = $VBoxContainer/DeckLabel

var _hero_defs: Array[GachaBallDefinition] = []
var _deck_meta: Array[Dictionary] = []

func _ready() -> void:
	_populate_heroes()
	_populate_decks()
	start_button.pressed.connect(_on_start_run_pressed)
	test_button.pressed.connect(_on_test_mode_pressed)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	title_label.text = tr("ui.title")
	start_button.text = tr("ui.start_run")
	test_button.text = tr("ui.test_mode")
	hero_label.text = tr("ui.choose_hero")
	deck_label.text = tr("ui.choose_deck")
	
	# Re-populate heroes to update translated names
	var hero_selection = hero_button.selected
	_populate_heroes()
	if hero_selection >= 0 and hero_selection < hero_button.item_count:
		hero_button.select(hero_selection)

func _populate_heroes() -> void:
	_hero_defs = Database.get_hero_definitions()
	hero_button.clear()
	for i in range(_hero_defs.size()):
		var hero_def = _hero_defs[i]
		hero_button.add_item(tr(hero_def.display_name_key), i)

func _populate_decks() -> void:
	_deck_meta = Database.get_all_deck_metadata()
	deck_button.clear()
	for i in range(_deck_meta.size()):
		var meta = _deck_meta[i]
		deck_button.add_item(meta.display_name, i)

func _on_start_run_pressed() -> void:
	var selected_hero_index = hero_button.selected
	var selected_deck_index = deck_button.selected

	if selected_hero_index == -1 or selected_deck_index == -1:
		return

	var hero_id = _hero_defs[selected_hero_index].id
	var deck_id = _deck_meta[selected_deck_index].deck_id

	# Ensure test mode is off for normal runs
	GameManager.is_test_mode = false
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id)


func _on_test_mode_pressed() -> void:
	var selected_hero_index = hero_button.selected
	var selected_deck_index = deck_button.selected
	
	if selected_hero_index == -1 or selected_deck_index == -1:
		return
	
	var hero_id = _hero_defs[selected_hero_index].id
	var deck_id = _deck_meta[selected_deck_index].deck_id
	
	# Set test mode flag
	GameManager.is_test_mode = true
	
	# Trigger normal run start
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id)

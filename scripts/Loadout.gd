# res://scripts/Loadout.gd
extends Control

@onready var hero_button: OptionButton = %HeroOptionButton
@onready var deck_button: OptionButton = %DeckOptionButton
@onready var start_button: Button = %StartRunButton

var _hero_defs: Array[GachaBallDefinition] = []
var _deck_meta: Array[Dictionary] = []

func _ready():
	_populate_heroes()
	_populate_decks()
	start_button.pressed.connect(_on_start_run_pressed)

func _populate_heroes():
	_hero_defs = Database.get_hero_definitions()
	hero_button.clear()
	for i in range(_hero_defs.size()):
		var hero_def = _hero_defs[i]
		hero_button.add_item(tr(hero_def.display_name_key), i)

func _populate_decks():
	_deck_meta = Database.get_all_deck_metadata()
	deck_button.clear()
	for i in range(_deck_meta.size()):
		var meta = _deck_meta[i]
		deck_button.add_item(meta.display_name, i)

func _on_start_run_pressed():
	var selected_hero_index = hero_button.selected
	var selected_deck_index = deck_button.selected

	if selected_hero_index == -1 or selected_deck_index == -1:
		return

	var hero_id = _hero_defs[selected_hero_index].id
	var deck_id = _deck_meta[selected_deck_index].deck_id

	SignalBus.emit_signal("start_run_requested", hero_id, deck_id)

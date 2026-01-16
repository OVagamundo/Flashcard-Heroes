# res://scripts/DeckSelectButton.gd
class_name DeckSelectButton
extends PanelContainer

## Clickable deck card button for the loadout scene.
## Displays deck name and card count with selection highlight.

signal deck_selected(deck_meta: Dictionary)

@onready var deck_name_label: Label = %DeckName
@onready var card_count_label: Label = %CardCount
@onready var selection_border: Panel = %SelectionBorder

var _deck_meta: Dictionary
var _is_selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	selection_border.visible = false


func populate(deck_meta: Dictionary) -> void:
	_deck_meta = deck_meta
	
	deck_name_label.text = deck_meta.get("display_name", "Unknown")
	
	# Get card count from Database
	var card_ids = Database.get_cards_for_deck(StringName(deck_meta.get("deck_id", "")))
	card_count_label.text = str(card_ids.size()) + " " + tr("ui.cards")


func set_selected(selected: bool) -> void:
	_is_selected = selected
	selection_border.visible = selected
	
	if selected:
		_play_selection_bounce()


func _play_selection_bounce() -> void:
	# AUDIO HOOK: Play selection sound
	Audio.play_sfx("ui_select")
	
	pivot_offset = size / 2.0
	var original_scale := scale
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 0.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.95, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", original_scale, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_click")
		deck_selected.emit(_deck_meta)


func get_deck_meta() -> Dictionary:
	return _deck_meta

# res://scripts/Loadout.gd
extends Control

## Loadout scene with hero and deck grid selection.
## Displays heroes in a 5-column grid and decks below.
## Separate info panels for hero and deck, both visible simultaneously.

const HeroSelectButtonScene = preload("res://scenes/HeroSelectButton.tscn")
const DeckSelectButtonScene = preload("res://scenes/DeckSelectButton.tscn")

# UI References - Selection Grids
@onready var hero_title: Label = %HeroTitle
@onready var hero_grid: GridContainer = %HeroGrid
@onready var deck_title: Label = %DeckTitle
@onready var deck_grid: GridContainer = %DeckGrid

# UI References - Hero Info Panel
@onready var hero_info_panel: PanelContainer = %HeroInfoPanel
@onready var hero_sprite: TextureRect = %HeroSprite
@onready var hero_name: Label = %HeroName
@onready var hero_stats: Label = %HeroStats
@onready var hero_description: RichTextLabel = %HeroDescription
@onready var hero_abilities: RichTextLabel = %HeroAbilities

# UI References - Deck Info Panel
@onready var deck_info_panel: PanelContainer = %DeckInfoPanel
@onready var deck_name: Label = %DeckName
@onready var deck_stats: Label = %DeckStats
@onready var deck_description: RichTextLabel = %DeckDescription

# UI References - Buttons
@onready var start_button: Button = %StartRunButton
@onready var test_button: Button = %TestModeButton

# Data
var _hero_defs: Array[GachaBallDefinition] = []
var _deck_meta: Array[Dictionary] = []

# Selection State
var _selected_hero_def: GachaBallDefinition = null
var _selected_deck_meta: Dictionary = {}
var _hero_buttons: Array = [] # HeroSelectButton instances
var _deck_buttons: Array = [] # DeckSelectButton instances


func _ready() -> void:
	
	# AUDIO HOOK: Loadout BGM
	Audio.play_music(SoundRegistry.BGM_LOADOUT)
	
	_populate_heroes()
	_populate_decks()
	
	start_button.pressed.connect(_on_start_run_pressed)
	test_button.pressed.connect(_on_test_mode_pressed)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()


func _update_localized_text() -> void:
	hero_title.text = tr("ui.choose_your_hero")
	deck_title.text = tr("ui.choose_your_deck")
	start_button.text = tr("ui.play")
	test_button.text = tr("ui.test_mode")
	
	# Re-populate to update translated names
	var hero_selection = _selected_hero_def
	var deck_selection = _selected_deck_meta
	
	_populate_heroes()
	_populate_decks()
	
	# Restore selections
	if hero_selection:
		_select_hero_by_id(hero_selection.id)
	if not deck_selection.is_empty():
		_select_deck_by_id(deck_selection.get("deck_id", ""))


func _populate_heroes() -> void:
	_hero_defs = Database.get_hero_definitions()
	
	# Clear existing buttons
	for child in hero_grid.get_children():
		child.queue_free()
	_hero_buttons.clear()
	
	# Create hero buttons
	for hero_def in _hero_defs:
		var button = HeroSelectButtonScene.instantiate()
		hero_grid.add_child(button)
		button.populate(hero_def, false) # Not locked
		button.hero_selected.connect(_on_hero_selected)
		_hero_buttons.append(button)
	
	# Add locked placeholder using first hero's sprite (for future unlockables)
	if _hero_defs.size() > 0:
		var locked_button = HeroSelectButtonScene.instantiate()
		hero_grid.add_child(locked_button)
		locked_button.populate(_hero_defs[0], true) # Use first hero sprite but locked
		_hero_buttons.append(locked_button)
	
	# Pre-select first hero
	if _hero_buttons.size() > 0 and not _hero_buttons[0]._is_locked:
		_on_hero_selected(_hero_defs[0])


func _populate_decks() -> void:
	_deck_meta = Database.get_all_deck_metadata()
	
	# Clear existing buttons
	for child in deck_grid.get_children():
		child.queue_free()
	_deck_buttons.clear()
	
	# Sort decks to put Katakana first
	_deck_meta.sort_custom(func(a, b):
		if a.get("deck_id", "") == "katakana_main":
			return true
		if b.get("deck_id", "") == "katakana_main":
			return false
		return a.get("display_name", "") < b.get("display_name", "")
	)
	
	# Create deck buttons
	for meta in _deck_meta:
		var button = DeckSelectButtonScene.instantiate()
		deck_grid.add_child(button)
		button.populate(meta)
		button.deck_selected.connect(_on_deck_selected)
		_deck_buttons.append(button)
	
	# Pre-select Katakana (should be first after sorting)
	if _deck_buttons.size() > 0:
		_on_deck_selected(_deck_meta[0])


func _on_hero_selected(hero_def: GachaBallDefinition) -> void:
	_selected_hero_def = hero_def
	
	# Update button selection states
	for button in _hero_buttons:
		button.set_selected(button.get_hero_def() == hero_def)
	
	# Update hero info panel
	_update_hero_info_panel(hero_def)


func _on_deck_selected(deck_meta: Dictionary) -> void:
	_selected_deck_meta = deck_meta
	
	# Update button selection states
	for button in _deck_buttons:
		button.set_selected(button.get_deck_meta().get("deck_id", "") == deck_meta.get("deck_id", ""))
	
	# Update deck info panel
	_update_deck_info_panel(deck_meta)


func _update_hero_info_panel(hero_def: GachaBallDefinition) -> void:
	hero_info_panel.visible = true
	
	# Sprite
	if hero_def.icon:
		hero_sprite.texture = hero_def.icon
		hero_sprite.visible = true
	else:
		hero_sprite.visible = false
	
	# Name
	hero_name.text = tr(hero_def.display_name_key)
	
	# Stats
	hero_stats.text = tr("ui.hp") + ": " + str(hero_def.base_hp) + "  " + tr("ui.pwr") + ": " + str(hero_def.base_pwr)
	
	# Description and Flavor
	var desc_text = tr(hero_def.description_key)
	var flavor_key = String(hero_def.id) + ".flavor"
	var flavor_text = tr(flavor_key)
	if flavor_text != flavor_key: # Translation exists
		desc_text += "\n\n[i]" + flavor_text + "[/i]"
	hero_description.text = desc_text
	
	# Abilities
	if hero_def.ability_definitions.size() > 0:
		var ability_text = "[b]" + tr("ui.ability") + ":[/b]\n"
		for ability_def in hero_def.ability_definitions:
			ability_text += "• " + tr(ability_def.name_key) + ": " + tr(ability_def.description_key) + "\n"
		hero_abilities.text = ability_text
		hero_abilities.visible = true
	else:
		hero_abilities.text = ""
		hero_abilities.visible = false


func _update_deck_info_panel(deck_meta: Dictionary) -> void:
	deck_info_panel.visible = true
	
	# Name
	deck_name.text = deck_meta.get("display_name", "Unknown")
	
	# Card count
	var deck_id = deck_meta.get("deck_id", "")
	var card_ids = Database.get_cards_for_deck(StringName(deck_id))
	deck_stats.text = str(card_ids.size()) + " " + tr("ui.cards")
	
	# Description
	var desc_key = "deck." + deck_id.replace("_main", "") + ".desc"
	var desc_text = tr(desc_key)
	if desc_text == desc_key: # No translation, use stored description
		desc_text = deck_meta.get("description", "")
	deck_description.text = desc_text


func _select_hero_by_id(hero_id: StringName) -> void:
	for hero_def in _hero_defs:
		if hero_def.id == hero_id:
			_on_hero_selected(hero_def)
			return


func _select_deck_by_id(deck_id: String) -> void:
	for meta in _deck_meta:
		if meta.get("deck_id", "") == deck_id:
			_on_deck_selected(meta)
			return


func _on_start_run_pressed() -> void:
	if _selected_hero_def == null or _selected_deck_meta.is_empty():
		Audio.play_sfx("ui_error")
		return
	
	var hero_id = _selected_hero_def.id
	var deck_id = _selected_deck_meta.get("deck_id", "")
	
	# Ensure test mode is off for normal runs
	GameManager.is_test_mode = false
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id)


func _on_test_mode_pressed() -> void:
	if _selected_hero_def == null or _selected_deck_meta.is_empty():
		Audio.play_sfx("ui_error")
		return
	
	var hero_id = _selected_hero_def.id
	var deck_id = _selected_deck_meta.get("deck_id", "")
	
	# Set test mode flag
	GameManager.is_test_mode = true
	
	# Trigger normal run start
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id)

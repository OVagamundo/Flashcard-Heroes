# res://scripts/Loadout.gd
extends Control

## Loadout scene with hero and deck carousel selection.
## Displays heroes and decks in a carousel showing prev/selected/next.
## Separate info panels for hero and deck, both visible simultaneously.

const HeroSelectButtonScene = preload("res://scenes/HeroSelectButton.tscn")
const DeckSelectButtonScene = preload("res://scenes/DeckSelectButton.tscn")

# UI References - Carousels
@onready var hero_title: Label = %HeroTitle
@onready var hero_carousel: HBoxContainer = %HeroCarousel
@onready var deck_title: Label = %DeckTitle
@onready var deck_carousel: HBoxContainer = %DeckCarousel

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

# Selection State (index-based for carousel)
var _selected_hero_index: int = 0
var _selected_deck_index: int = 0
var _selected_hero_def: GachaBallDefinition = null
var _selected_deck_meta: Dictionary = {}
var deck_order_option: OptionButton # Deck order selection
var deck_size_option: OptionButton # Deck size selection

var _test_starters: Array[StringName] = []
var _test_starters_label: Label
var _test_starters_option: OptionButton


func _ready() -> void:
	
	# AUDIO HOOK: Loadout BGM
	Audio.play_music(SoundRegistry.BGM_LOADOUT)
	
	_load_hero_data()
	_load_deck_data()
	_update_hero_carousel()
	_update_deck_carousel()
	
	# Create Deck Order setting UI
	var order_container = HBoxContainer.new()
	order_container.alignment = BoxContainer.ALIGNMENT_CENTER
	order_container.add_theme_constant_override("separation", 10)
	
	var order_label = Label.new()
	order_label.text = tr("ui.deck_order") if tr("ui.deck_order") != "ui.deck_order" else "Deck Order:"
	
	deck_order_option = OptionButton.new()
	deck_order_option.add_item(tr("ui.deck_order.regular") if tr("ui.deck_order.regular") != "ui.deck_order.regular" else "Regular", 0)
	deck_order_option.add_item(tr("ui.deck_order.inverted") if tr("ui.deck_order.inverted") != "ui.deck_order.inverted" else "Inverted", 1)
	deck_order_option.add_item(tr("ui.deck_order.random") if tr("ui.deck_order.random") != "ui.deck_order.random" else "Random", 2)
	
	order_container.add_child(order_label)
	order_container.add_child(deck_order_option)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	order_container.add_child(spacer)
	
	var size_label = Label.new()
	size_label.text = tr("ui.deck_size") if tr("ui.deck_size") != "ui.deck_size" else "Deck Size:"
	
	deck_size_option = OptionButton.new()
	deck_size_option.add_item(tr("ui.deck_size.full") if tr("ui.deck_size.full") != "ui.deck_size.full" else "Full (complete deck)", 0)
	deck_size_option.add_item(tr("ui.deck_size.half") if tr("ui.deck_size.half") != "ui.deck_size.half" else "Quick (half deck)", 1)
	
	order_container.add_child(size_label)
	order_container.add_child(deck_size_option)
	
	deck_carousel.get_parent().add_child(order_container)
	
	# Create Test Starters UI
	var test_starters_container = VBoxContainer.new()
	test_starters_container.name = "TestStartersContainer"
	
	var ts_label = Label.new()
	ts_label.text = "Add Test Items/Trinkets (Optional):"
	ts_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	test_starters_container.add_child(ts_label)
	
	var ts_controls = HBoxContainer.new()
	test_starters_container.add_child(ts_controls)
	
	_test_starters_option = OptionButton.new()
	_test_starters_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts_controls.add_child(_test_starters_option)
	
	_test_starters_option.add_item("--- Select Item ---", 0)
	_test_starters_option.set_item_metadata(0, "")
	
	var t_idx = 1
	var all_pool = Database.get_all_pool_definitions()
	for def in all_pool:
		var display_text = "%s (%s)" % [tr(def.display_name_key), def.id]
		_test_starters_option.add_item(display_text, t_idx)
		_test_starters_option.set_item_metadata(t_idx, def.id)
		t_idx += 1
	for t in Database.trinkets.values():
		var display_text = "%s (%s)" % [tr(t.name_key), t.id]
		_test_starters_option.add_item(display_text, t_idx)
		_test_starters_option.set_item_metadata(t_idx, t.id)
		t_idx += 1
		
	var btn_add = Button.new()
	btn_add.text = "Add"
	btn_add.pressed.connect(func():
		var sel_idx = _test_starters_option.selected
		if sel_idx > 0:
			var item_id = _test_starters_option.get_item_metadata(sel_idx)
			if item_id != "":
				_test_starters.append(StringName(item_id))
				_update_test_starters_label()
	)
	ts_controls.add_child(btn_add)
	
	var btn_clear = Button.new()
	btn_clear.text = "Clear"
	btn_clear.pressed.connect(func():
		_test_starters.clear()
		_update_test_starters_label()
	)
	ts_controls.add_child(btn_clear)
	
	_test_starters_label = Label.new()
	_test_starters_label.text = "Selected: None"
	_test_starters_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_test_starters_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	test_starters_container.add_child(_test_starters_label)
	
	# Add the container to HeroColumn
	hero_info_panel.get_parent().add_child(test_starters_container)
	
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
	
	# Preserve current selections
	var hero_id_backup = _selected_hero_def.id if _selected_hero_def else StringName("")
	var deck_id_backup = _selected_deck_meta.get("deck_id", "") if not _selected_deck_meta.is_empty() else ""
	
	_load_hero_data()
	_load_deck_data()
	
	# Restore selections by finding indices
	if hero_id_backup != StringName(""):
		for i in range(_hero_defs.size()):
			if _hero_defs[i].id == hero_id_backup:
				_selected_hero_index = i
				break
	if deck_id_backup != "":
		for i in range(_deck_meta.size()):
			if _deck_meta[i].get("deck_id", "") == deck_id_backup:
				_selected_deck_index = i
				break
	
	_update_hero_carousel()
	_update_deck_carousel()

func _update_test_starters_label() -> void:
	if _test_starters.is_empty():
		_test_starters_label.text = "Selected: None"
	else:
		var names = []
		for item_id in _test_starters:
			var def = Database.get_definition(item_id)
			if def:
				if "name_key" in def:
					names.append(tr(def.name_key))
				elif "display_name_key" in def:
					names.append(tr(def.display_name_key))
				else:
					names.append(String(item_id))
			else:
				names.append(String(item_id))
		_test_starters_label.text = "Selected: " + ", ".join(names)

# --- Data Loading ---


func _load_hero_data() -> void:
	_hero_defs = Database.get_hero_definitions()
	_selected_hero_index = clampi(_selected_hero_index, 0, maxi(_hero_defs.size() - 1, 0))
	if _hero_defs.size() > 0:
		_selected_hero_def = _hero_defs[_selected_hero_index]


func _load_deck_data() -> void:
	_deck_meta = Database.get_all_deck_metadata()
	
	# Sort decks to put Katakana first
	_deck_meta.sort_custom(func(a, b):
		if a.get("deck_id", "") == "katakana_main":
			return true
		if b.get("deck_id", "") == "katakana_main":
			return false
		return a.get("display_name", "") < b.get("display_name", "")
	)
	
	_selected_deck_index = clampi(_selected_deck_index, 0, maxi(_deck_meta.size() - 1, 0))
	if _deck_meta.size() > 0:
		_selected_deck_meta = _deck_meta[_selected_deck_index]


# --- Carousel Updates ---


func _update_deck_carousel() -> void:
	for child in deck_carousel.get_children():
		child.queue_free()
	
	if _deck_meta.is_empty():
		return
	
	var count = _deck_meta.size()
	_selected_deck_index = wrapi(_selected_deck_index, 0, count)
	_selected_deck_meta = _deck_meta[_selected_deck_index]
	
	# Left arrow
	var left_arrow = _create_arrow_button("◀")
	left_arrow.pressed.connect(_on_deck_prev)
	deck_carousel.add_child(left_arrow)
	
	# Previous item (only if 3+ items to avoid showing same item twice)
	if count >= 3:
		var prev_idx = wrapi(_selected_deck_index - 1, 0, count)
		_add_deck_carousel_item(prev_idx, false)
	
	# Selected item
	_add_deck_carousel_item(_selected_deck_index, true)
	
	# Next item (only if 2+ items)
	if count >= 2:
		var next_idx = wrapi(_selected_deck_index + 1, 0, count)
		_add_deck_carousel_item(next_idx, false)
	
	# Right arrow
	var right_arrow = _create_arrow_button("▶")
	right_arrow.pressed.connect(_on_deck_next)
	deck_carousel.add_child(right_arrow)
	
	_update_deck_info_panel(_selected_deck_meta)


func _add_deck_carousel_item(index: int, is_selected: bool) -> void:
	var button = DeckSelectButtonScene.instantiate()
	if is_selected:
		button.custom_minimum_size = Vector2(160, 80)
	else:
		button.custom_minimum_size = Vector2(110, 60)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck_carousel.add_child(button)
	button.populate(_deck_meta[index])
	if is_selected:
		button.set_selected(true)
	else:
		button.modulate = Color(1, 1, 1, 0.45)
		var target_index = index
		button.deck_selected.connect(func(_m): _navigate_deck_to(target_index))


func _update_hero_carousel() -> void:
	for child in hero_carousel.get_children():
		child.queue_free()
	
	if _hero_defs.is_empty():
		return
	
	var count = _hero_defs.size()
	_selected_hero_index = wrapi(_selected_hero_index, 0, count)
	_selected_hero_def = _hero_defs[_selected_hero_index]
	
	# Left arrow
	var left_arrow = _create_arrow_button("◀")
	left_arrow.pressed.connect(_on_hero_prev)
	hero_carousel.add_child(left_arrow)
	
	# Previous item
	if count >= 3:
		var prev_idx = wrapi(_selected_hero_index - 1, 0, count)
		_add_hero_carousel_item(prev_idx, false)
	
	# Selected item
	_add_hero_carousel_item(_selected_hero_index, true)
	
	# Next item
	if count >= 2:
		var next_idx = wrapi(_selected_hero_index + 1, 0, count)
		_add_hero_carousel_item(next_idx, false)
	
	# Right arrow
	var right_arrow = _create_arrow_button("▶")
	right_arrow.pressed.connect(_on_hero_next)
	hero_carousel.add_child(right_arrow)
	
	_update_hero_info_panel(_selected_hero_def)


func _add_hero_carousel_item(index: int, is_selected: bool) -> void:
	var button = HeroSelectButtonScene.instantiate()
	if is_selected:
		button.custom_minimum_size = Vector2(128, 128)
	else:
		button.custom_minimum_size = Vector2(80, 80)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_carousel.add_child(button)
	button.populate(_hero_defs[index], false)
	if is_selected:
		button.set_selected(true)
	else:
		button.modulate = Color(1, 1, 1, 0.45)
		var target_index = index
		button.hero_selected.connect(func(_d): _navigate_hero_to(target_index))


# --- Arrow Buttons ---


func _create_arrow_button(symbol: String) -> Button:
	var btn = Button.new()
	btn.text = symbol
	btn.flat = true
	btn.custom_minimum_size = Vector2(36, 36)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1.0))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn


# --- Navigation ---


func _on_deck_prev() -> void:
	Audio.play_sfx("ui_click")
	_selected_deck_index = wrapi(_selected_deck_index - 1, 0, _deck_meta.size())
	_update_deck_carousel()


func _on_deck_next() -> void:
	Audio.play_sfx("ui_click")
	_selected_deck_index = wrapi(_selected_deck_index + 1, 0, _deck_meta.size())
	_update_deck_carousel()


func _navigate_deck_to(index: int) -> void:
	if index != _selected_deck_index:
		_selected_deck_index = index
		_update_deck_carousel()


func _on_hero_prev() -> void:
	Audio.play_sfx("ui_click")
	_selected_hero_index = wrapi(_selected_hero_index - 1, 0, _hero_defs.size())
	_update_hero_carousel()


func _on_hero_next() -> void:
	Audio.play_sfx("ui_click")
	_selected_hero_index = wrapi(_selected_hero_index + 1, 0, _hero_defs.size())
	_update_hero_carousel()


func _navigate_hero_to(index: int) -> void:
	if index != _selected_hero_index:
		_selected_hero_index = index
		_update_hero_carousel()


# --- Info Panel Updates ---


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
	for i in range(_hero_defs.size()):
		if _hero_defs[i].id == hero_id:
			_selected_hero_index = i
			_update_hero_carousel()
			return


func _select_deck_by_id(deck_id: String) -> void:
	for i in range(_deck_meta.size()):
		if _deck_meta[i].get("deck_id", "") == deck_id:
			_selected_deck_index = i
			_update_deck_carousel()
			return


func _on_start_run_pressed() -> void:
	if _selected_hero_def == null or _selected_deck_meta.is_empty():
		Audio.play_sfx("ui_error")
		return
	
	var hero_id = _selected_hero_def.id
	var deck_id = _selected_deck_meta.get("deck_id", "")
	
	var order_str = "REGULAR"
	if is_instance_valid(deck_order_option):
		if deck_order_option.selected == 1:
			order_str = "INVERTED"
		elif deck_order_option.selected == 2:
			order_str = "RANDOM"
	
	var size_str = "FULL"
	if is_instance_valid(deck_size_option):
		if deck_size_option.selected == 1:
			size_str = "HALF"
	
	# Pass test starters
	GameManager.test_starting_items = _test_starters.duplicate()
	
	# Ensure test mode is off for normal runs
	GameManager.is_test_mode = false
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id, order_str, size_str)


func _on_test_mode_pressed() -> void:
	if _selected_hero_def == null or _selected_deck_meta.is_empty():
		Audio.play_sfx("ui_error")
		return
	
	var hero_id = _selected_hero_def.id
	var deck_id = _selected_deck_meta.get("deck_id", "")
	
	var order_str = "REGULAR"
	if is_instance_valid(deck_order_option):
		if deck_order_option.selected == 1:
			order_str = "INVERTED"
		elif deck_order_option.selected == 2:
			order_str = "RANDOM"
	
	var size_str = "FULL"
	if is_instance_valid(deck_size_option):
		if deck_size_option.selected == 1:
			size_str = "HALF"
	
	# Pass test starters
	GameManager.test_starting_items = _test_starters.duplicate()
	
	# Set test mode flag
	GameManager.is_test_mode = true
	
	# Trigger normal run start
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id, order_str, size_str)

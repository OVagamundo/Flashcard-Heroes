# res://scripts/Loadout.gd
extends Control

## Loadout scene with hero and deck carousel selection.
## Displays heroes and decks in a carousel showing prev/selected/next.
## Separate info panels for hero and deck, both visible simultaneously.

const HeroSelectButtonScene = preload("res://scenes/HeroSelectButton.tscn")
const DeckSelectButtonScene = preload("res://scenes/DeckSelectButton.tscn")
const SlotViewScene = preload("res://scenes/SlotView.tscn")
const TraitTags = preload("res://scripts/ui/TraitTags.gd")
const STARTER_COMPACT_ART_SIZE := Vector2(84, 72)
const STARTER_UNIT_ART_SIZE := Vector2.ONE * (C.UNIT_SPRITE_SIZE + 8)
const STARTER_STATS_HEIGHT: float = 28.0

# UI References - Carousels
@onready var hero_title: Label = %HeroTitle
@onready var hero_carousel: HBoxContainer = %HeroCarousel
@onready var deck_title: Label = %DeckTitle
@onready var deck_carousel: HBoxContainer = %DeckCarousel

# UI References - Hero Info Panel
@onready var hero_info_panel: PanelContainer = %HeroInfoPanel
@onready var hero_scroll_container: ScrollContainer = %HeroScrollContainer
@onready var hero_sprite: TextureRect = %HeroSprite
@onready var hero_trait_tags: TraitTags = %HeroTraitTags
@onready var hero_name: Label = %HeroName
@onready var hero_stats: Label = %HeroStats
@onready var hero_description: RichTextLabel = %HeroDescription
@onready var starting_set_separator: HSeparator = %StartingSetSeparator
@onready var starting_set_container: VBoxContainer = %StartingSetContainer

# UI References - Deck Info Panel
@onready var deck_info_panel: PanelContainer = %DeckInfoPanel
@onready var deck_scroll_container: ScrollContainer = %DeckScrollContainer
@onready var deck_name: Label = %DeckName
@onready var deck_stats: Label = %DeckStats
@onready var deck_description: RichTextLabel = %DeckDescription

# UI References - Buttons & Controls
@onready var start_button: Button = %StartRunButton
@onready var tutorial_checkbox: CheckBox = %TutorialCheckbox

# UI References - Dev Starting Items
@onready var _test_starters_option: OptionButton = %TestStartersOption
@onready var _btn_add_starter: Button = %AddStarterButton
@onready var _btn_clear_starters: Button = %ClearStartersButton
@onready var _test_starters_label: Label = %TestStartersLabel
@onready var _dev_tools_container: VBoxContainer = $DevToolsContainer

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
var _active_inspected_card: Control = null
var _loadout_seed: int
var _starting_loadout: RunState.StartingLoadout
var _preview_hero: GachaBallInstance


func _ready() -> void:
	
	# AUDIO HOOK: Loadout BGM
	Audio.play_music(SoundRegistry.BGM_LOADOUT)
	
	_loadout_seed = SaveManager.get_loadout_seed()
	_load_hero_data()
	_load_deck_data()
	_selected_hero_index = _find_hero_index(&"hero_starter")
	_selected_deck_index = _find_deck_index(&"katakana_main")
	_update_hero_carousel()
	_update_deck_carousel()
	_dev_tools_container.visible = not DemoContent.is_demo_mode()
	
	# Create Deck Order setting UI
	var order_container = HBoxContainer.new()
	order_container.alignment = BoxContainer.ALIGNMENT_CENTER
	order_container.add_theme_constant_override("separation", 10)
	order_container.custom_minimum_size = Vector2(0, 38)
	
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
	
	# Add matching spacer under Hero Carousel so DeckSelection and HeroSelection match in height
	var hero_spacer = Control.new()
	hero_spacer.custom_minimum_size = Vector2(0, 38)
	hero_carousel.get_parent().add_child(hero_spacer)
	order_container.resized.connect(func():
		hero_spacer.custom_minimum_size.y = order_container.size.y
	)
	
	# Clickable hero sprite in HeaderBox to inspect hero unit
	hero_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	hero_sprite.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_inspect_preview_hero()
	)
	
	# Keep _active_inspected_card in sync when inspection windows close
	WindowManager.window_closed.connect(_on_window_closed)
	
	# Setup Test Starters UI (in bottom-left DevToolsContainer)
	var popup: PopupMenu = _test_starters_option.get_popup()
	popup.max_size = Vector2i(450, 400)
	_test_starters_option.add_item("--- Select Item ---", 0)
	_test_starters_option.set_item_metadata(0, "")
	
	var t_idx = 1
	var all_pool = Database.get_all_pool_definitions(&"ALL")
	for def in all_pool:
		var loc_name = tr(def.display_name_key)
		var display_text = loc_name if loc_name == String(def.id) else "%s (%s)" % [loc_name, def.id]
		_test_starters_option.add_item(display_text, t_idx)
		_test_starters_option.set_item_metadata(t_idx, def.id)
		t_idx += 1
	for t in Database.trinkets.values():
		var loc_name = tr(t.name_key)
		var display_text = loc_name if loc_name == String(t.id) else "%s (%s)" % [loc_name, t.id]
		_test_starters_option.add_item(display_text, t_idx)
		_test_starters_option.set_item_metadata(t_idx, t.id)
		t_idx += 1
		
	_btn_add_starter.pressed.connect(func():
		var sel_idx = _test_starters_option.selected
		if sel_idx > 0:
			var item_id = _test_starters_option.get_item_metadata(sel_idx)
			if item_id != "":
				_test_starters.append(StringName(item_id))
				_update_test_starters_label()
	)
	_btn_clear_starters.pressed.connect(func():
		_test_starters.clear()
		_update_test_starters_label()
	)
	
	start_button.pressed.connect(_on_start_run_pressed)
	
	tutorial_checkbox.button_pressed = TutorialManager.tutorials_enabled
	tutorial_checkbox.toggled.connect(func(enabled: bool):
		TutorialManager.tutorials_enabled = enabled
		TutorialManager.save_settings()
	)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# Draggable scroll containers (no scrollbars, drag up/down & keyboard Up/Down)
	_setup_draggable_scroll(hero_scroll_container)
	_setup_draggable_scroll(deck_scroll_container)


func _input(event: InputEvent) -> void:
	# Debug Header: Reset tutorials with Shift+T
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and event.shift_pressed:
		TutorialManager.reset_all_tutorials()
		tutorial_checkbox.button_pressed = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_preview_windows()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_scroll_active_panel(-45)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_scroll_active_panel(45)
			get_viewport().set_input_as_handled()


func _setup_draggable_scroll(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v_bar = scroll.get_v_scroll_bar()
	if is_instance_valid(v_bar):
		v_bar.modulate.a = 0.0
		v_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_bar.custom_minimum_size = Vector2.ZERO
	
	# Ensure nested text labels pass mouse events through so dragging works across the box
	for child in scroll.find_children("*", "RichTextLabel", true, false):
		if child is RichTextLabel:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var drag_state := {"active": false, "start_y": 0.0, "start_scroll": 0}
	
	scroll.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					drag_state["active"] = true
					drag_state["start_y"] = event.global_position.y
					drag_state["start_scroll"] = scroll.scroll_vertical
				else:
					drag_state["active"] = false
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				scroll.scroll_vertical = max(0, scroll.scroll_vertical - 40)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				scroll.scroll_vertical = min(_get_max_scroll(scroll), scroll.scroll_vertical + 40)
		elif event is InputEventMouseMotion:
			if drag_state.get("active", false):
				var dy: float = event.global_position.y - drag_state["start_y"]
				scroll.scroll_vertical = clamp(int(drag_state["start_scroll"] - dy), 0, _get_max_scroll(scroll))
		elif event is InputEventScreenTouch:
			if event.pressed:
				drag_state["active"] = true
				drag_state["start_y"] = event.position.y
				drag_state["start_scroll"] = scroll.scroll_vertical
			else:
				drag_state["active"] = false
		elif event is InputEventScreenDrag:
			if drag_state.get("active", false):
				var dy: float = event.position.y - drag_state["start_y"]
				scroll.scroll_vertical = clamp(int(drag_state["start_scroll"] - dy), 0, _get_max_scroll(scroll))
	)


func _scroll_active_panel(delta: int) -> void:
	var target_scroll: ScrollContainer = hero_scroll_container
	var mouse_pos = get_global_mouse_position()
	if is_instance_valid(deck_info_panel) and deck_info_panel.get_global_rect().has_point(mouse_pos):
		target_scroll = deck_scroll_container
	
	if is_instance_valid(target_scroll):
		var max_s = _get_max_scroll(target_scroll)
		target_scroll.scroll_vertical = clamp(target_scroll.scroll_vertical + delta, 0, max_s)


func _get_max_scroll(scroll: ScrollContainer) -> int:
	if not is_instance_valid(scroll):
		return 0
	var v_bar = scroll.get_v_scroll_bar()
	if not is_instance_valid(v_bar):
		return 0
	return int(max(0, v_bar.max_value - v_bar.page))


func _close_preview_windows() -> void:
	if WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows(true)
	_active_inspected_card = null


func _update_localized_text() -> void:
	hero_title.text = tr("ui.choose_your_hero")
	deck_title.text = tr("ui.choose_your_deck")
	start_button.text = tr("ui.play")
	tutorial_checkbox.text = tr("ui.show_tutorials")
	
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
	# Keep Dan first and Shiken immediately to his right in the carousel.
	_hero_defs.sort_custom(func(a: GachaBallDefinition, b: GachaBallDefinition) -> bool:
		var a_order := _hero_sort_priority(a.id)
		var b_order := _hero_sort_priority(b.id)
		if a_order != b_order:
			return a_order < b_order
		return String(a.id) < String(b.id)
	)
	_selected_hero_index = clampi(_selected_hero_index, 0, maxi(_hero_defs.size() - 1, 0))
	if _hero_defs.size() > 0:
		_selected_hero_def = _hero_defs[_selected_hero_index]


func _hero_sort_priority(hero_id: StringName) -> int:
	if hero_id == &"hero_starter":
		return 0
	if hero_id == &"hero_bounty_hunter":
		return 1
	return 2


func _find_hero_index(hero_id: StringName) -> int:
	for i in range(_hero_defs.size()):
		if _hero_defs[i].id == hero_id:
			return i
	assert(false, "Loadout: expected hero '%s' to exist" % hero_id)
	return -1


func _find_deck_index(deck_id: StringName) -> int:
	for i in range(_deck_meta.size()):
		if StringName(_deck_meta[i].get("deck_id", "")) == deck_id:
			return i
	assert(false, "Loadout: expected deck '%s' to exist" % deck_id)
	return -1


func _deck_sort_priority(deck_id: StringName) -> int:
	if deck_id == &"katakana_main":
		return 0
	if deck_id == &"hiragana_main":
		return 1
	return 2


func _load_deck_data() -> void:
	_deck_meta = Database.get_all_deck_metadata()
	
	# Keep the two demo decks together and put Katakana first.
	_deck_meta.sort_custom(func(a, b):
		var a_id := StringName(a.get("deck_id", ""))
		var b_id := StringName(b.get("deck_id", ""))
		var a_order: int = _deck_sort_priority(a_id)
		var b_order: int = _deck_sort_priority(b_id)
		if a_order != b_order:
			return a_order < b_order
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
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
	_update_start_button_state()


func _add_deck_carousel_item(index: int, is_selected: bool) -> void:
	var button = DeckSelectButtonScene.instantiate()
	if is_selected:
		button.custom_minimum_size = Vector2(170, 128)
	else:
		button.custom_minimum_size = Vector2(120, 80)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck_carousel.add_child(button)
	var deck_id := StringName(_deck_meta[index].get("deck_id", ""))
	button.populate(_deck_meta[index], not DemoContent.is_deck_unlocked(deck_id))
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
	_update_start_button_state()


func _add_hero_carousel_item(index: int, is_selected: bool) -> void:
	var button = HeroSelectButtonScene.instantiate()
	if is_selected:
		button.custom_minimum_size = Vector2(128, 128)
	else:
		button.custom_minimum_size = Vector2(80, 80)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_carousel.add_child(button)
	button.populate(_hero_defs[index], not DemoContent.is_hero_unlocked(_hero_defs[index].id))
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
	btn.custom_minimum_size = Vector2(36, 128)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1.0))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn


# --- Navigation ---


func _on_deck_prev() -> void:
	_close_preview_windows()
	Audio.play_sfx("ui_click")
	_selected_deck_index = wrapi(_selected_deck_index - 1, 0, _deck_meta.size())
	_update_deck_carousel()


func _on_deck_next() -> void:
	_close_preview_windows()
	Audio.play_sfx("ui_click")
	_selected_deck_index = wrapi(_selected_deck_index + 1, 0, _deck_meta.size())
	_update_deck_carousel()


func _navigate_deck_to(index: int) -> void:
	if index != _selected_deck_index:
		_close_preview_windows()
		_selected_deck_index = index
		_update_deck_carousel()


func _on_hero_prev() -> void:
	_close_preview_windows()
	Audio.play_sfx("ui_click")
	_selected_hero_index = wrapi(_selected_hero_index - 1, 0, _hero_defs.size())
	_update_hero_carousel()


func _on_hero_next() -> void:
	_close_preview_windows()
	Audio.play_sfx("ui_click")
	_selected_hero_index = wrapi(_selected_hero_index + 1, 0, _hero_defs.size())
	_update_hero_carousel()


func _navigate_hero_to(index: int) -> void:
	if index != _selected_hero_index:
		_close_preview_windows()
		_selected_hero_index = index
		_update_hero_carousel()


# --- Info Panel Updates ---


func _update_start_button_state() -> void:
	if _selected_hero_def == null or _selected_deck_meta.is_empty():
		start_button.disabled = true
		return
	var hero_unlocked := DemoContent.is_hero_unlocked(_selected_hero_def.id)
	var deck_id := StringName(_selected_deck_meta.get("deck_id", ""))
	start_button.disabled = not hero_unlocked or not DemoContent.is_deck_unlocked(deck_id)


func _update_hero_info_panel(hero_def: GachaBallDefinition) -> void:
	hero_info_panel.visible = true
	_starting_loadout = RunState.preview_starting_loadout(hero_def.id, _loadout_seed)
	_preview_hero = GachaBallInstance.new()
	_preview_hero.initialize(hero_def, "loadout_hero", hero_def.tags)
	_preview_hero.components.append(_starting_loadout.hero_traits)
	
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
	
	hero_trait_tags.populate(_preview_hero)
	var ability_texts: Array[String] = []
	for ability: AbilityDefinition in hero_def.ability_definitions:
		ability_texts.append(tr(ability.description_key))
	hero_description.text = "\n\n".join(ability_texts)
	hero_description.visible = not ability_texts.is_empty()

	_update_hero_starting_set()
	hero_scroll_container.scroll_vertical = 0


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
	if is_instance_valid(deck_scroll_container):
		deck_scroll_container.scroll_vertical = 0


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
	var selected_deck_id := StringName(_selected_deck_meta.get("deck_id", ""))
	if not DemoContent.is_hero_unlocked(_selected_hero_def.id) or not DemoContent.is_deck_unlocked(selected_deck_id):
		Audio.play_sfx("ui_error")
		return
	
	_close_preview_windows()

	var hero_id = _selected_hero_def.id
	var deck_id = String(selected_deck_id)
	
	assert(deck_order_option != null, "deck_order_option not initialized")
	assert(deck_size_option != null, "deck_size_option not initialized")

	var order_str = "REGULAR"
	if deck_order_option.selected == 1:
		order_str = "INVERTED"
	elif deck_order_option.selected == 2:
		order_str = "RANDOM"
	
	var size_str = "FULL"
	if deck_size_option.selected == 1:
		size_str = "HALF"
	
	# Pass test starters
	GameManager.test_starting_items = _test_starters.duplicate()
	
	if TutorialManager.tutorials_enabled:
		TutorialManager.reset_all_tutorials()
	
	SignalBus.emit_signal("start_run_requested", hero_id, deck_id, order_str, size_str)


# --- Hero Starting Set & Inspectable Views ---


func _update_hero_starting_set() -> void:
	for child in starting_set_container.get_children():
		starting_set_container.remove_child(child)
		child.queue_free()
	
	starting_set_separator.visible = true
	starting_set_container.visible = true
	
	var trait_trinket_id: StringName = &""
	var unit_ids: Array[StringName] = []
	var unit_counts: Dictionary = {}
	var item_ids: Array[StringName] = []
	var item_counts: Dictionary = {}
	
	for id: StringName in _starting_loadout.starter_ids:
		var def: Resource = Database.get_definition(id)
		if not def:
			continue
		if def is TrinketDefinition:
			trait_trinket_id = id
		elif def is GachaBallDefinition:
			var gb := def as GachaBallDefinition
			if gb.category == &"UNIT":
				if not unit_counts.has(id):
					unit_ids.append(id)
					unit_counts[id] = 1
				else:
					unit_counts[id] += 1
			elif gb.category in [&"ITEM", &"CONSUMABLE"]:
				if not item_counts.has(id):
					item_ids.append(id)
					item_counts[id] = 1
				else:
					item_counts[id] += 1
	
	# Trait Trinket
	if trait_trinket_id != &"":
		var trinket_lbl := Label.new()
		trinket_lbl.text = tr("ui.starting_trait_trinket")
		trinket_lbl.add_theme_font_size_override("font_size", 14)
		trinket_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45, 1.0))
		starting_set_container.add_child(trinket_lbl)
		
		var t_hbox := HBoxContainer.new()
		t_hbox.add_theme_constant_override("separation", 14)
		starting_set_container.add_child(t_hbox)
		
		_create_starter_slot_entry(trait_trinket_id, 1, 0, t_hbox)
		
		var t_def: Resource = Database.get_definition(trait_trinket_id)
		var desc_vbox := VBoxContainer.new()
		desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		desc_vbox.add_theme_constant_override("separation", 4)
		
		var t_name := Label.new()
		var t_name_key: String = t_def.name_key if "name_key" in t_def else (t_def.display_name_key if "display_name_key" in t_def else String(trait_trinket_id))
		t_name.text = tr(t_name_key)
		t_name.add_theme_font_size_override("font_size", 15)
		t_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5, 1.0))
		desc_vbox.add_child(t_name)
		
		var t_desc := Label.new()
		t_desc.text = tr(t_def.description_key) if "description_key" in t_def else ""
		t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_desc.add_theme_font_size_override("font_size", 13)
		t_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
		desc_vbox.add_child(t_desc)
		
		t_hbox.add_child(desc_vbox)
	
	# Starting Units
	if not unit_ids.is_empty():
		var units_lbl := Label.new()
		units_lbl.text = tr("ui.starting_units")
		units_lbl.add_theme_font_size_override("font_size", 14)
		units_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 1.0))
		starting_set_container.add_child(units_lbl)
		
		var units_flow := HFlowContainer.new()
		units_flow.add_theme_constant_override("h_separation", 6)
		units_flow.add_theme_constant_override("v_separation", 8)
		starting_set_container.add_child(units_flow)
		
		var slot_idx := 0
		for uid in unit_ids:
			_create_starter_slot_entry(uid, unit_counts[uid], slot_idx, units_flow)
			slot_idx += 1
	
	# Starting Items
	if not item_ids.is_empty():
		var items_lbl := Label.new()
		items_lbl.text = tr("ui.starting_items")
		items_lbl.add_theme_font_size_override("font_size", 14)
		items_lbl.add_theme_color_override("font_color", Color(0.65, 0.95, 0.8, 1.0))
		starting_set_container.add_child(items_lbl)
		
		var items_flow := HFlowContainer.new()
		items_flow.add_theme_constant_override("h_separation", 6)
		items_flow.add_theme_constant_override("v_separation", 8)
		starting_set_container.add_child(items_flow)
		
		var slot_idx := 0
		for iid in item_ids:
			_create_starter_slot_entry(iid, item_counts[iid], slot_idx, items_flow)
			slot_idx += 1


func _create_starter_slot_entry(def_id: StringName, count: int, slot_idx: int, parent_container: Container) -> void:
	var def: Resource = Database.get_definition(def_id)
	assert(def != null, "Definition not found for starter id: %s" % str(def_id))
	
	var inst := GachaBallInstance.new()
	var preview_uuid: String = "loadout_%s" % def_id
	if def is TrinketDefinition:
		inst.initialize_from_trinket(def, preview_uuid)
	else:
		var unit_or_item: GachaBallDefinition = def as GachaBallDefinition
		var preview_tags: Array[StringName] = _starting_loadout.unit_tag_overrides.get(def_id, unit_or_item.tags)
		inst.initialize(unit_or_item, preview_uuid, preview_tags)

	var is_unit: bool = def is GachaBallDefinition and def.category == &"UNIT"
	var art_size: Vector2 = STARTER_UNIT_ART_SIZE if is_unit else STARTER_COMPACT_ART_SIZE
	var stats_height: float = STARTER_STATS_HEIGHT if is_unit else 0.0
	var cell_size: Vector2 = art_size + Vector2(0.0, stats_height)
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = cell_size
	parent_container.add_child(cell)

	var slot_view: SlotView = SlotViewScene.instantiate()
	slot_view.set_size_scale(1.0)
	slot_view.show_background = false
	slot_view.custom_minimum_size = cell_size
	cell.add_child(slot_view)
	slot_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var container_name: StringName = &"PlayerTrinkets" if def is TrinketDefinition else &"RunInventoryT1"
	var loc := LocationIdentifier.new(container_name, slot_idx)
	loc.set_meta("gachaball_instance", inst)
	loc.set_meta("is_preview", true)
	slot_view.populate(loc)
	slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(inst)
	var gb: GachaBallView = slot_view.set_content(visual_data, true, false)
	assert(gb != null, "Failed to instantiate GachaBallView for %s" % def_id)
	gb.layout_loadout_preview(art_size.y)

	var anim_ctrl: UnitAnimationController = gb.get_node("AnimationController")
	anim_ctrl.set_active(false)
	anim_ctrl.process_mode = Node.PROCESS_MODE_DISABLED

	gb.set_meta("gachaball_instance", inst)
	gb.set_meta("is_preview", true)
	slot_view.set_meta("gachaball_instance", inst)
	slot_view.set_meta("is_preview", true)

	if count > 1:
		var badge := Label.new()
		badge.name = "Quantity"
		badge.text = "%dx" % count
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.z_index = 3
		cell.add_child(badge)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -32.0
		badge.offset_right = -4.0
		badge.offset_top = -stats_height - 24.0
		badge.offset_bottom = -stats_height - 2.0


func _inspect_preview_hero() -> void:
	Audio.play_sfx("ui_click")
	if _active_inspected_card == hero_sprite and WindowManager.is_any_inspection_window_open():
		WindowManager.close_all_inspection_windows(true)
		_active_inspected_card = null
		return

	_active_inspected_card = hero_sprite
	var context: Dictionary = {
		"window_type": &"UnitInspection",
		"anchor_view": hero_sprite,
		"populate_context": {
			"source_view": hero_sprite,
			"instance": _preview_hero,
			"is_preview": true
		}
	}
	WindowManager._open_contextual_window(context)

func _on_window_closed(_w: Control) -> void:
	if not WindowManager.is_any_inspection_window_open():
		_active_inspected_card = null

func _exit_tree() -> void:
	if WindowManager.window_closed.is_connected(_on_window_closed):
		WindowManager.window_closed.disconnect(_on_window_closed)


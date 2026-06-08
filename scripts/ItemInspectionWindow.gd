class_name ItemInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")

@onready var name_label: Label = %NameLabel
const BOLD_FONT = preload("res://assets/fonts/noto_sans_black_composite.tres")
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _inspected_item_uuid: String
var _long_press_timer: Timer
var _last_meta_at_pointer = null
var _locked_meta = null
var _last_child_window_id: int = -1

func _ready() -> void:
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)

	description_label.meta_clicked.connect(_on_description_meta_clicked)
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)
	
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = 0.32
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	
	if WindowManager.has_signal("window_closed"):
		WindowManager.window_closed.connect(_on_window_manager_window_closed)
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

func _exit_tree() -> void:
	if SignalBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		SignalBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_inventory_changed", _on_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("run_data_changed", _on_inventory_changed):
		SignalBus.run_data_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_stat_changed", _on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(_on_unit_stat_changed)

## Recursively set mouse filters to PASS for child controls so clicks bubble to the root
func _configure_mouse_filters() -> void:
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Keep nodes with their own logic at STOP
				if child == internal_background or child == description_label:
					(child as Control).mouse_filter = MOUSE_FILTER_STOP
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, name_label, recipe_container, separator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	# Keep gui_input connected but do not consume non-link clicks (see handler below)
	description_label.gui_input.connect(_on_description_gui_input)

	# Prune children when clicking anywhere on the window background area
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)
func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants.
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()


func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		WindowManager.request_close_inspection_window(self , &"INVALID_DEFINITION")
		return

	_inspected_item_uuid = _instance.ball_uuid
	_update_description_and_stats(item_def)

func _update_description_and_stats(item_def: Resource) -> void:
	var name_key: String
	if item_def is GachaBallDefinition:
		name_key = item_def.display_name_key
	else:
		# TrinketDefinition uses name_key instead of display_name_key
		name_key = item_def.name_key
	
	name_label.text = tr(name_key)
	name_label.add_theme_font_override("font", BOLD_FONT)
	name_label.add_theme_font_size_override("font_size", 32)
	
	var title_color = Color(0, 0.4, 0.8, 1) # Default blue
	if item_def is GachaBallDefinition:
		match item_def.tier:
			1: title_color = Color.YELLOW
			2: title_color = Color.MAGENTA
			3: title_color = Color.CYAN
	name_label.add_theme_color_override("font_color", title_color)

	var trait_id := _get_linked_trait_id(item_def)
	var full_text := ""
	
	if not trait_id.is_empty():
		full_text = _build_trait_trinket_description(trait_id)
		description_label.set_meta("effect_definition", null)
		
		# Trigger tutorial for traits (deferred to allow window to position itself)
		_trigger_trait_tutorial()
	else:
		# Base flavor description for trinkets (often contains passive effect info)
		var base_desc = ""
		if item_def.get("description_key") and item_def.description_key != "":
			base_desc = tr(item_def.description_key)
		elif item_def is TrinketDefinition:
			base_desc = tr(item_def.description_key)
		
		var effect_desc = ""
		if item_def is GachaBallDefinition:
			if item_def.bonus_hp > 0 and item_def.bonus_pwr > 0:
				effect_desc = tr("item.effect.both").replace("(HP)", str(item_def.bonus_hp)).replace("(PWR)", str(item_def.bonus_pwr))
			elif item_def.bonus_hp > 0:
				effect_desc = tr("item.effect.hp").replace("(HP)", str(item_def.bonus_hp))
			elif item_def.bonus_pwr > 0 or (is_instance_valid(_instance) and _instance.definition_id == &"item_t2_d"):
				var display_pwr = item_def.bonus_pwr
				if is_instance_valid(_instance) and _instance.definition_id == &"item_t2_d":
					display_pwr += _instance.current_pwr
				if display_pwr > 0:
					effect_desc = tr("item.effect.pwr").replace("(PWR)", str(display_pwr))
		
		# Build abilities section: list all abilities with name and localized description
		var abilities_block := ""
		var abilities_lines: Array[String] = []
		for entry in _instance.get_active_ability_entries(_get_all_instances_db()):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			var ability_name := tr(ability.name_key) if "name_key" in ability else ""
			if "name_key" in ability and ability_name == ability.name_key and ability.name_key.begins_with("ability."):
				ability_name = ""
			var ability_desc := tr(ability.description_key) if "description_key" in ability else ""
			if "description_key" in ability and ability_desc == ability.description_key and ability.description_key.begins_with("ability."):
				ability_desc = ""
			if is_instance_valid(_instance):
				ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
				ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
				if ability.id == &"ability_echoing_orb_scale":
					var current_bonus = _instance.current_pwr
					var suffix = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
					ability_desc += " [color=#4ade80]%s[/color]" % suffix
			
			if not ability_name.is_empty() or not ability_desc.is_empty():
				abilities_lines.append("[b]%s[/b]: %s" % [ability_name, ability_desc])
		abilities_block = "\n".join(abilities_lines)

		if not base_desc.is_empty() and abilities_block.is_empty():
			full_text += base_desc
		if not effect_desc.is_empty():
			if not full_text.is_empty(): full_text += "\n"
			full_text += effect_desc
		if not abilities_block.is_empty():
			if not full_text.is_empty():
				full_text += "\n"
			full_text += abilities_block
		
		# Store the full definition for the child window to use (if generic effect link is clicked, though we removed it)
		description_label.set_meta("effect_definition", item_def)

	if not full_text.is_empty():
		full_text = DescriptionParser.parse(full_text)

	var final_text = full_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	description_label.text = final_text
	
	_update_recipe_display(item_def)

	# Manage separator visibility based on recipe container
	if is_instance_valid(separator):
		separator.visible = recipe_container.visible

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
		return
	var all_instances: Dictionary = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_item_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
		return
	
	_instance = current_instance
	var item_def = _instance.get_definition()
	if is_instance_valid(item_def):
		_update_description_and_stats(item_def)

func _on_unit_stat_changed(unit_uuid: String, _stat_name: StringName, _old_value: int, _new_value: int) -> void:
	if is_instance_valid(_instance):
		if unit_uuid == _instance.equipped_on_uuid or unit_uuid == _inspected_item_uuid:
			_on_inventory_changed()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		if is_instance_valid(recipe_container) and not recipe_container.visible:
			recipe_container.custom_minimum_size = Vector2.ZERO
		
		# Enforce shrinking on EVERY container in the hierarchy
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(480, 0)
		size = Vector2.ZERO # Force immediate recalculation of minimum size
		reset_size()

func _get_all_instances_db() -> Dictionary:
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		return bm.get_all_instances() if is_instance_valid(bm) else {}
	return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _get_linked_trait_id(item_def: Resource) -> String:
	if not is_instance_valid(item_def):
		return ""
	if "linked_trait_id" in item_def and item_def.linked_trait_id != &"":
		return String(item_def.linked_trait_id)
	
	# Check for trait tags (Emblems)
	var tags := _instance.get_active_tags(_get_all_instances_db()) if is_instance_valid(_instance) else []
	for tag in tags:
		match tag:
			&"SOUL_FIRE": return "FIRE"
			&"SOUL_EARTH": return "EARTH"
			&"SOUL_WATER": return "WATER"
			&"SOUL_AIR": return "AIR"

	for trait_name in C.TRAIT_SORT_ORDER:
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
		if trait_def.get("trinket_id", &"") == item_def.id:
			return trait_name
	return ""

func _build_trait_trinket_description(trait_id: String) -> String:
	var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_id, {})
	if trait_def.is_empty():
		return ""

	var current_count := _get_trait_count_for_context(trait_id)
	var lines: Array[String] = []
	for level in trait_def.get("levels", []):
		var min_req := int(level.get("min", 0))
		var is_active := current_count >= min_req
		var color_tag := "[color=#FFFF00]" if is_active else "[color=#888888]"
		var prefix := "* " if is_active else "- "
		lines.append("%s%s%d: %s[/color]" % [color_tag, prefix, min_req, tr(level.get("desc_key", ""))])

	return "\n".join(lines)

func _get_trait_count_for_context(trait_id: String) -> int:
	if GameManager.is_in_battle:
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(battle_manager):
			var team := _get_trait_team_for_context()
			var active_traits: Dictionary = battle_manager.get_active_traits(team)
			return int(active_traits.get(trait_id, 0))
	return _get_run_trait_count(trait_id)

func _get_trait_team_for_context() -> String:
	if is_instance_valid(_location) and _location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
		return "ENEMY"
	return "PLAYER"

func _get_run_trait_count(trait_id: String) -> int:
	if not is_instance_valid(GameManager.run_state):
		return 0

	var counts := {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	var lineup = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_LINEUP)
	if not is_instance_valid(lineup):
		return 0

	for unit_uuid in lineup.get_all_non_empty_uuids():
		var unit = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if not is_instance_valid(unit):
			continue
		var soul_counts = unit.get_trait_soul_counts(GameManager.run_state.get_all_instances())
		for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
			counts[soul_type] += soul_counts[soul_type]

	return int(counts.get(trait_id, 0))

func _accumulate_trait_tag(counts: Dictionary, tag: StringName) -> void:
	match tag:
		&"SOUL_FIRE":
			counts["FIRE"] += 1
		&"SOUL_EARTH":
			counts["EARTH"] += 1
		&"SOUL_WATER":
			counts["WATER"] += 1
		&"SOUL_AIR":
			counts["AIR"] += 1

func _update_recipe_display(item_def: Resource) -> void:
	if not is_instance_valid(recipe_container):
		return
	
	for child in recipe_container.get_children():
		child.queue_free()
	
	if not item_def is GachaBallDefinition:
		recipe_container.visible = false
		return
	
	var recipe: MergeRecipe = Database.get_recipe_for_result(item_def.id)
	if not is_instance_valid(recipe):
		recipe_container.visible = false
		return
	
	var def_a = Database.get_definition(recipe.ingredient_a_id)
	var def_b = Database.get_definition(recipe.ingredient_b_id)
	
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		recipe_container.visible = false
		return
	
	var _make_icon = func(def: Resource) -> TextureRect:
		var tex = TextureRect.new()
		if def and def.icon:
			tex.texture = def.icon
			tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.custom_minimum_size = Vector2(96, 96)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = MOUSE_FILTER_IGNORE
		return tex
	
	var _make_label = func(txt: String) -> Control:
		var container = CenterContainer.new()
		container.custom_minimum_size = Vector2(32, 96)
		container.mouse_filter = MOUSE_FILTER_IGNORE
		
		var lbl = Label.new()
		lbl.text = txt
		lbl.add_theme_font_override("font", BOLD_FONT)
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		
		container.add_child(lbl)
		return container
	
	recipe_container.add_child(_make_icon.call(def_a))
	recipe_container.add_child(_make_label.call("+"))
	recipe_container.add_child(_make_icon.call(def_b))
	recipe_container.visible = true

func _on_description_meta_clicked(meta) -> void:
	if _locked_meta == meta:
		# Toggle off: close child and unlock
		_locked_meta = null
		WindowManager.close_children_of(self )
	else:
		_locked_meta = meta
		_handle_effect_meta_interaction(meta)

func _on_description_meta_hover_started(meta) -> void:
	if _locked_meta != null:
		return
	_last_meta_at_pointer = meta
	_handle_effect_meta_interaction(meta)

func _on_description_meta_hover_ended(_meta) -> void:
	_last_meta_at_pointer = null

func _on_long_press_timeout() -> void:
	var meta = _last_meta_at_pointer
	if meta == null:
		meta = description_label.get_meta_at_point(description_label.get_local_mouse_position())
	
	if meta:
		_handle_effect_meta_interaction(meta)

func _handle_effect_meta_interaction(meta) -> void:
	if meta == "effect":
		var definition: Variant = description_label.get_meta("effect_definition")
		if definition:
			var parent_win: Control = WindowManager.find_ancestor_window_for_view(self )
			var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
			var inside_unit: bool = parent_win is UnitInspectionWindow
			var win = WindowManager.open_child_contextual_window(
				&"EffectInspection",
				self ,
				{
					"effect_definition": definition.ability_definitions,
					"is_inside_unit_inspection": inside_unit,
					"target_parent_window_id": parent_id
				}
			)
			if win:
				_last_child_window_id = win.get_instance_id()
			get_viewport().set_input_as_handled()
			accept_event()
	elif str(meta).begins_with("effect_"):
		var effect_type = str(meta).replace("effect_", "")
		var name_key = "STATUS_" + effect_type.to_upper()
		var desc_key = "STATUS_" + effect_type.to_upper() + "_DESC"
		
		var parent_win: Control = WindowManager.find_ancestor_window_for_view(self )
		var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
		var inside_unit: bool = parent_win is UnitInspectionWindow
		
		var win = WindowManager.open_child_contextual_window(
			&"EffectInspection",
			self ,
			{
				"effect_definition": {
					"name_key": name_key,
					"description_key": desc_key
				},
				"is_inside_unit_inspection": inside_unit,
				"target_parent_window_id": parent_id
			}
		)
		if win:
			_last_child_window_id = win.get_instance_id()
		get_viewport().set_input_as_handled()
		accept_event()

func _on_window_manager_window_closed(window: Control) -> void:
	if window.get_instance_id() == _last_child_window_id:
		_locked_meta = null
		_last_child_window_id = -1

func _on_description_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			_long_press_timer.start()
		else:
			_long_press_timer.stop()
	pass

func _on_internal_background_gui_input(_event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(_event):
		_locked_meta = null # Unlock on background click
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()
		accept_event()

func get_location() -> LocationIdentifier:
	return _location

func _trigger_trait_tutorial() -> void:
	# Wait 1.0s before showing tutorial to avoid "quick pass" triggers as requested
	await get_tree().create_timer(1.0).timeout
	
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	TutorialManager.show_tutorial(&"traits", [
		{
			"text": tr("tutorial.traits"),
			"anchor_side": "AUTO_HORIZONTAL" # Attempt to place next to the inspection window without overlapping
		}
	], self)

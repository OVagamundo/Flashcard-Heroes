class_name ItemInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")
const _SlotView = preload("res://scenes/SlotView.tscn")
const C = preload("res://scripts/Constants.gd")

@onready var name_label: Label = %NameLabel
@onready var view_container: CenterContainer = %ViewContainer
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var bottom_description_label: RichTextLabel = %BottomDescriptionLabel
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _inspected_item_uuid: String
var _is_preview: bool = false
var _explicit_recipe_id: StringName = &""

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)

	for child in [description_label, bottom_description_label, name_label, recipe_container, separator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(description_label):
		description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	if is_instance_valid(bottom_description_label):
		bottom_description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		bottom_description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	
	enforce_display_only()


func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_preview = context.get("is_preview", false)
	_explicit_recipe_id = context.get("recipe_id", &"")

	if not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	if not _is_preview and not is_instance_valid(_source_view):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		WindowManager.request_close_inspection_window(self , &"INVALID_DEFINITION")
		return

	_inspected_item_uuid = _instance.ball_uuid
	_update_item_view()
	_update_description_and_stats(item_def)

func _update_description_and_stats(item_def: Resource) -> void:
	var name_key: String
	if item_def is GachaBallDefinition:
		name_key = item_def.display_name_key
	else:
		# TrinketDefinition uses name_key instead of display_name_key
		name_key = item_def.name_key
	
	name_label.text = tr(name_key)
	name_label.add_theme_font_override("font", Database.get_current_locale_font())
	name_label.add_theme_font_size_override("font_size", 26)
	
	var title_color := Color("#0F172A") # High-contrast charcoal default
	if item_def is GachaBallDefinition:
		match item_def.tier:
			1: title_color = Color("#854D0E") # Deep Bronze / Amber
			2: title_color = Color("#701A75") # Deep Crimson Violet / Purple
			3: title_color = Color("#1E3A8A") # Deep Royal Navy / Azure
	name_label.add_theme_color_override("font_color", title_color)

	var crest_trait_id: String = _get_crest_trait_id(item_def.id) if item_def is TrinketDefinition else ""
	var full_text := ""
	
	if not crest_trait_id.is_empty():
		var trait_ladder := _build_trait_trinket_description(crest_trait_id)
		description_label.set_meta("effect_definition", null)
		
		var base_desc := ""
		if "description_key" in item_def and not item_def.description_key.is_empty():
			var description_key: String = item_def.description_key
			var is_trait_threshold_summary: bool = description_key.begins_with("trinket.trait_") and description_key != "trinket.trait_novice.desc"
			if not is_trait_threshold_summary:
				var raw_desc: String = tr(description_key)
				base_desc = raw_desc
		
		if not base_desc.is_empty():
			full_text = base_desc + "\n\n" + trait_ladder
		else:
			full_text = trait_ladder
		
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
			elif item_def.bonus_pwr > 0:
				effect_desc = tr("item.effect.pwr").replace("(PWR)", str(item_def.bonus_pwr))
		
		# Item and trinket abilities are shown as descriptions only.
		var abilities_block := ""
		var abilities_lines: Array[String] = []
		var seen_ability_descriptions: Dictionary = {}
		for entry in _instance.get_active_ability_entries(_get_all_instances_db()):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			var ability_desc := tr(ability.description_key) if "description_key" in ability else ""
			if "description_key" in ability and ability_desc == ability.description_key and ability.description_key.begins_with("ability."):
				ability_desc = ""
			if is_instance_valid(_instance):
				ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
				ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
				if ability.id == &"ability_slime_cell_scale":
					var current_bonus = 0
					var all_db = _get_all_instances_db()
					if not _instance.equipped_on_uuid.is_empty():
						var holder = all_db.get(_instance.equipped_on_uuid)
						if is_instance_valid(holder):
							current_bonus = holder.get_status_effect_amount(StringName("slime_cell_scaling_" + _instance.ball_uuid))
					if current_bonus == 0:
						var count = 0
						for uuid in all_db:
							var inst = all_db[uuid]
							if is_instance_valid(inst) and inst.definition_id == &"item_t2_d":
								count += 1
						current_bonus = maxi(1, count)
					var suffix = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
					ability_desc += " [color=#4ade80]%s[/color]" % suffix
			
			var description_signature := ability_desc.strip_edges()
			if not description_signature.is_empty() and not seen_ability_descriptions.has(description_signature):
				seen_ability_descriptions[description_signature] = true
				abilities_lines.append(ability_desc)
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
	
	var font = Database.get_current_locale_font()
	description_label.custom_minimum_size = Vector2.ZERO
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	description_label.add_theme_font_size_override("normal_font_size", 22)
	description_label.add_theme_font_size_override("bold_font_size", 22)
	description_label.add_theme_constant_override("line_separation", 3)
	description_label.add_theme_constant_override("p_separation", 6)
	description_label.text = final_text
	description_label.visible = not final_text.is_empty()
	description_label.set_meta("effect_definition", item_def if not _is_trinket(item_def) else null)
	
	if is_instance_valid(bottom_description_label):
		bottom_description_label.text = ""
		bottom_description_label.visible = false
		bottom_description_label.custom_minimum_size = Vector2.ZERO
	
	_update_recipe_display(item_def)

	# Manage separator visibility based on recipe container (hidden to eliminate grey line)
	if is_instance_valid(separator):
		separator.visible = false
		separator.custom_minimum_size = Vector2.ZERO

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()
	call_deferred("_deferred_shrink")

func _deferred_shrink() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_reset_window_size()

func _on_inventory_changed() -> void:
	if _is_preview or not is_instance_valid(self):
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
	if _is_preview:
		return
	if is_instance_valid(_instance):
		if unit_uuid == _instance.equipped_on_uuid or unit_uuid == _inspected_item_uuid:
			_on_inventory_changed()

func _is_trinket(item_def: Resource) -> bool:
	return item_def is TrinketDefinition or (item_def is GachaBallDefinition and item_def.category == &"TRINKET")

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		for container in [recipe_container, separator, bottom_description_label]:
			if is_instance_valid(container) and not container.visible:
				container.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(view_container) and not view_container.visible:
			view_container.custom_minimum_size = Vector2.ZERO
		
		# Enforce shrinking on EVERY container in the hierarchy
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(0 if _is_preview else 360, 0)
		size = Vector2(0 if _is_preview else 360, 0) # Force immediate recalculation of minimum size
		reset_size()
		enforce_display_only()

func _get_all_instances_db() -> Dictionary:
	var result: Dictionary = {}
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		result = bm.get_all_instances() if is_instance_valid(bm) else {}
	elif is_instance_valid(GameManager.run_state):
		result = GameManager.run_state.run_instances
	if _is_preview and is_instance_valid(_instance):
		result = result.duplicate()
		result[_instance.ball_uuid] = _instance
	return result

func _get_crest_trait_id(trinket_id: StringName) -> String:
	for trait_name: String in C.TRAIT_SORT_ORDER:
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS[trait_name]
		if trait_def["trinket_id"] == trinket_id:
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
		var color_tag := "[color=#8B0000]" if is_active else "[color=#888888]"
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
	if is_instance_valid(_location) and _location.container in [C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER]:
		return "ENEMY"
	return "PLAYER"

func _get_run_trait_count(trait_id: String) -> int:
	if not is_instance_valid(GameManager.run_state):
		return 0

	var counts: Dictionary = {}
	for t in C.TRAIT_SORT_ORDER:
		counts[t] = 0

	var lineup = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_LINEUP)
	if not is_instance_valid(lineup):
		return 0

	var all_inst = GameManager.run_state.get_all_instances()
	for unit_uuid in lineup.get_all_non_empty_uuids():
		var unit = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if not is_instance_valid(unit):
			continue
		var soul_counts = unit.get_trait_soul_counts(all_inst)
		for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
			if counts.has(soul_type):
				counts[soul_type] += soul_counts.get(soul_type, 0)
		for tag in unit.get_active_tags(all_inst):
			var upper = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] += 1

	return int(counts.get(trait_id, 0))

func _accumulate_trait_tag(counts: Dictionary, tag: StringName) -> void:
	match tag:
		&"SOUL_FIRE":
			counts["FIRE"] = counts.get("FIRE", 0) + 1
		&"SOUL_EARTH":
			counts["EARTH"] = counts.get("EARTH", 0) + 1
		&"SOUL_WATER":
			counts["WATER"] = counts.get("WATER", 0) + 1
		&"SOUL_AIR":
			counts["AIR"] = counts.get("AIR", 0) + 1
		_:
			var upper = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] = counts.get(upper, 0) + 1


## Populate the ViewContainer to show the resulting item's view at 2x scale (battle board size) during merge preview.
func _update_item_view() -> void:
	if not is_instance_valid(view_container):
		return
	
	for child in view_container.get_children():
		view_container.remove_child(child)
		child.queue_free()
	
	if not _is_preview or not is_instance_valid(_instance):
		view_container.visible = false
		view_container.custom_minimum_size = Vector2.ZERO
		return
	
	var item_def = _instance.get_definition()
	if _is_trinket(item_def):
		view_container.visible = false
		view_container.custom_minimum_size = Vector2.ZERO
		return
	
	var slot_view: SlotView = _SlotView.instantiate()
	slot_view.show_background = false
	slot_view.set_size_scale(2.0)
	slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
	
	var slot_color: StringName = _location.container if is_instance_valid(_location) else &"EquippedItem"
	slot_view.set_slot_color(slot_color)
	
	if SignalBus.show_slot_indicators.is_connected(slot_view._on_show_slot_indicators):
		SignalBus.show_slot_indicators.disconnect(slot_view._on_show_slot_indicators)
	if SignalBus.hide_slot_indicators.is_connected(slot_view._on_hide_slot_indicators):
		SignalBus.hide_slot_indicators.disconnect(slot_view._on_hide_slot_indicators)
	if SignalBus.unit_stat_changed.is_connected(slot_view._on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(slot_view._on_unit_stat_changed)
		
	slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
	
	view_container.add_child(slot_view)
	slot_view.z_as_relative = true
	slot_view.z_index = 1
	view_container.visible = true
	view_container.custom_minimum_size = Vector2(0, C.SLOT_SIZE_2X)
	
	var all_instances_db = _get_all_instances_db()
	var visual_data = VisualDataAdapter.create_visual_data(_instance, all_instances_db)
	var gb = slot_view.set_content(visual_data, false, false)
	if is_instance_valid(gb):
		gb.z_as_relative = true
		gb.z_index = 1
		gb._base_z_index = 1
		gb._slot_base_z_index = 1
		gb.show_capsule_overlay = false
		gb.set_is_interactive(false)
		var overlay = gb.get_node_or_null("GachaBallOverlay")
		if is_instance_valid(overlay):
			overlay.queue_free()
		var trait_count = gb.get_node_or_null("%TraitCountLabel")
		if is_instance_valid(trait_count):
			trait_count.visible = false

func _update_recipe_display(item_def: Resource) -> void:
	if not is_instance_valid(recipe_container):
		return
	
	for child in recipe_container.get_children():
		recipe_container.remove_child(child)
		child.queue_free()
	
	if _is_preview:
		recipe_container.visible = false
		recipe_container.custom_minimum_size = Vector2.ZERO
		return
	
	if not item_def is GachaBallDefinition:
		recipe_container.visible = false
		return
	
	var recipe: MergeRecipe = null
	if not _explicit_recipe_id.is_empty():
		recipe = Database.recipes.get(_explicit_recipe_id)
	if not is_instance_valid(recipe):
		recipe = Database.get_recipe_for_result(item_def.id)
	if not is_instance_valid(recipe):
		recipe_container.visible = false
		return
	
	var def_a = Database.get_definition(recipe.ingredient_a_id)
	var def_b = Database.get_definition(recipe.ingredient_b_id)
	
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		recipe_container.visible = false
		return
	
	recipe_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	recipe_container.custom_minimum_size = Vector2(0, 96)
	
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
		lbl.add_theme_font_override("font", Database.get_current_locale_font())
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

func get_glossary_terms() -> Array[String]:
	var terms: Array[String] = []
	var text_to_search: String = ""
	if is_instance_valid(description_label):
		text_to_search += description_label.text + " "
	if is_instance_valid(bottom_description_label) and bottom_description_label.visible:
		text_to_search += bottom_description_label.text + " "
	
	terms.append_array(DescriptionParser.find_keywords(text_to_search))
	return terms

func get_child_window_specs() -> Array[Dictionary]:
	return []

func get_location() -> LocationIdentifier:
	return _location

func _trigger_trait_tutorial() -> void:
	if _is_preview:
		return
	# Wait 1.0s before showing tutorial to avoid "quick pass" triggers as requested
	await get_tree().create_timer(1.0, true).timeout
	
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	TutorialManager.show_tutorial(&"traits", [
		{
			"text": "tutorial.traits",
			"anchor_side": "AUTO_HORIZONTAL",
			"pause_game": true
		}
	], description_label)

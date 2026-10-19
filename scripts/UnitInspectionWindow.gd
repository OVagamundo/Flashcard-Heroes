class_name UnitInspectionWindow
extends InspectionWindow

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")
const _InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")

@onready var name_label: Label = %NameLabel
@onready var trait_tags_container: HFlowContainer = %TraitTagsContainer
@onready var view_container: CenterContainer = %ViewContainer
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var bottom_description_label: RichTextLabel = %BottomDescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel
@onready var trait_icons_container: HBoxContainer = %TraitIconsContainer
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

const TRAIT_COLORS: Dictionary = {
	"FIRE": Color(0.85, 0.22, 0.12, 1.0),       # Fiery Vermilion
	"EARTH": Color(0.58, 0.35, 0.18, 1.0),      # Terracotta Brown
	"WATER": Color(0.12, 0.46, 0.86, 1.0),      # Ocean Blue
	"AIR": Color(0.15, 0.68, 0.82, 1.0),        # Sky Cyan
	"TANK": Color(0.32, 0.42, 0.54, 1.0),       # Slate Steel
	"FIGHTER": Color(0.72, 0.12, 0.22, 1.0),    # Ruby Crimson
	"SUPPORT": Color(0.12, 0.65, 0.48, 1.0),    # Emerald Mint
	"SPECIALIST": Color(0.58, 0.22, 0.78, 1.0), # Royal Violet
	"FOOD": Color(0.90, 0.52, 0.08, 1.0),       # Warm Tangerine
	"MECHA": Color(0.24, 0.28, 0.33, 1.0),      # Dark Gunmetal
	"ANIMAL": Color(0.48, 0.56, 0.18, 1.0),     # Wild Olive
	"PLANT": Color(0.18, 0.58, 0.18, 1.0),      # Leaf Green
	"TOY": Color(0.85, 0.18, 0.55, 1.0),        # Hot Pink
	"APPLIANCE": Color(0.82, 0.65, 0.08, 1.0),  # Electric Gold
	"COSTUME": Color(0.34, 0.14, 0.52, 1.0)     # Velvet Indigo
}

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _is_enemy_context: bool = false
var _is_preview: bool = false
var _explicit_recipe_id: StringName = &""
var _window_group_id: int = 1 # Inspection window group

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [%DescriptionLabel, %BottomDescriptionLabel, %NameLabel, %TraitTagsContainer, %ItemGrid, %TraitIconsContainer, %RecipeContainer, %HSeparator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(description_label):
		description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	if is_instance_valid(bottom_description_label):
		bottom_description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		bottom_description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	
	enforce_display_only()

func _exit_tree() -> void:
	if SignalBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		SignalBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if SignalBus.is_connected("run_data_changed", _on_inventory_changed):
		SignalBus.run_data_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_stat_changed", _on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(_on_unit_stat_changed)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants.
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_enemy_context = context.get("is_enemy_context", false)
	_is_preview = context.get("is_preview", false)
	_explicit_recipe_id = context.get("recipe_id", &"")

	if not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	if not _is_preview and not is_instance_valid(_source_view):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		WindowManager.request_close_inspection_window(self, &"INVALID_DEFINITION")
		return

	_inspected_unit_uuid = _instance.ball_uuid


	name_label.text = tr(unit_definition.display_name_key)
	name_label.add_theme_font_override("font", Database.get_current_locale_font())
	name_label.add_theme_font_size_override("font_size", 32)
	
	var title_color = Color(0, 0.4, 0.8, 1) # Default blue
	match unit_definition.tier:
		1: title_color = Color.YELLOW
		2: title_color = Color.MAGENTA
		3: title_color = Color.CYAN
	name_label.add_theme_color_override("font_color", title_color)
	# Description content is built in _update_description()
	_update_description()

	# --- Core UI Population Logic ---
	_rebuild_item_grid()
	_update_trait_display()
	_update_unit_view()
	_update_recipe_display()

	# Manage separator visibility based on any visible footers (hidden to eliminate grey line crossing stats)
	if is_instance_valid(separator):
		separator.visible = false
		separator.custom_minimum_size = Vector2.ZERO

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()
	call_deferred("_deferred_shrink")
	enforce_display_only()

func _deferred_shrink() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_reset_window_size()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		# Zero out hidden containers completely to ensure they contribute NO height
		for container in [item_grid, recipe_container, trait_icons_container, trait_tags_container, separator, bottom_description_label]:
			if is_instance_valid(container) and not container.visible:
				container.custom_minimum_size = Vector2.ZERO
		
		# Enforce shrinking on EVERY container in the hierarchy
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(0 if _is_preview else 480, 0)
		size = Vector2(0 if _is_preview else 480, 0) # Force immediate recalculation of minimum size
		reset_size()
		# Let WindowManager know we have settled so it can refine the position if needed
		# (Note: Standard contextual window positioning happens in WindowManager)



func _rebuild_item_grid() -> void:
	# Units with equipped items don't show the items in their inspection window,
	# as the item's own inspection window is opened at the same time alongside.
	if is_instance_valid(item_grid_label):
		item_grid_label.visible = false
		item_grid_label.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(item_grid):
		for child in item_grid.get_children():
			child.queue_free()
		item_grid.visible = false
		item_grid.custom_minimum_size = Vector2.ZERO

	
func _update_description() -> void:
	if not is_instance_valid(_instance):
		return
	
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		return
	

	# Build abilities section: list all abilities with name and localized description
	var abilities_lines: Array[String] = []
	var seen_ability_ids: Dictionary = {}
	var all_instances_db := _get_all_instances_db()
	
	for entry in _instance.get_active_ability_entries(all_instances_db):
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if not ability_def or ability_def.id == &"basic_attack":
			continue
		
		# Units with equipped items don't show item abilities in the unit window,
		# since the item's own inspection window is opened at the same time alongside.
		if entry.get("source_type") == &"EQUIPMENT":
			continue
		
		if seen_ability_ids.has(ability_def.id):
			continue
		seen_ability_ids[ability_def.id] = true
		
		var ability_desc = tr(ability_def.description_key)
		if ability_desc == ability_def.description_key and ability_def.description_key.begins_with("ability."):
			ability_desc = ""
		if is_instance_valid(_instance):
			ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
			ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
			if ability_def.id == &"ability_echoing_orb_scale":
				var source_uuid = entry.get("source_uuid", "")
				var current_bonus = _instance.get_status_effect_amount(StringName("echoing_orb_scaling_" + source_uuid))
				if current_bonus == 0:
					var count = 0
					for uuid in all_instances_db:
						var inst = all_instances_db[uuid]
						if is_instance_valid(inst) and inst.definition_id == &"item_t2_d":
							count += 1
					current_bonus = maxi(1, count) * 2
				var suffix = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
				ability_desc += " [color=#4ade80]%s[/color]" % suffix
			elif ability_def.id == &"ability_doppleganger_scale":
				var current_bonus = _instance.get_status_effect_amount(&"doppleganger_scaling")
				var suffix = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
				ability_desc += " [color=#4ade80]%s[/color]" % suffix
		
		if not ability_desc.is_empty():
			abilities_lines.append(ability_desc)

	var abilities_block := "\n".join(abilities_lines)
	
	var full_text := ""
	var unit_desc := tr(unit_definition.description_key) if "description_key" in unit_definition else ""
	if not unit_desc.is_empty() and unit_desc != unit_definition.description_key and abilities_block.is_empty():
		full_text = unit_desc
	
	if not abilities_block.is_empty():
		if not full_text.is_empty():
			full_text += "\n\n"
		full_text += abilities_block

	if not full_text.is_empty():
		full_text = DescriptionParser.parse(full_text)

	var final_text = full_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	var font = Database.get_current_locale_font()
	var font_size = 32
	var plain_text = DescriptionParser.strip_bbcode(final_text)
	
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	if is_instance_valid(bottom_description_label):
		bottom_description_label.add_theme_font_override("normal_font", font)
		bottom_description_label.add_theme_font_override("bold_font", font)

	var p = TextParagraph.new()
	p.width = 256.0
	p.set_line_spacing(-4)
	p.add_string(plain_text, font, font_size)
	
	var max_view_h = 212.0
	var cutoff_line := -1
	var cum_h := 0.0
	for i in range(p.get_line_count()):
		var line_h = p.get_line_size(i).y - 4
		if cum_h + line_h <= max_view_h:
			cum_h += line_h
			cutoff_line = i
		else:
			break
	
	if cutoff_line >= 0 and cutoff_line < p.get_line_count() - 1:
		var split_char_idx = p.get_line_range(cutoff_line + 1).x
		var parts = DescriptionParser.split_bbcode(final_text, split_char_idx)
		description_label.text = parts[0]
		if is_instance_valid(bottom_description_label):
			bottom_description_label.text = parts[1]
			bottom_description_label.visible = true
			bottom_description_label.set_meta("definition", unit_definition)
			bottom_description_label.set_meta("effect_definition", unit_definition)
	else:
		description_label.text = final_text
		if is_instance_valid(bottom_description_label):
			bottom_description_label.text = ""
			bottom_description_label.visible = false
			bottom_description_label.custom_minimum_size = Vector2.ZERO
			
	description_label.set_meta("definition", unit_definition)
	description_label.set_meta("effect_definition", unit_definition)
## Granular stat change handler - updates description when any stat changes
func _on_unit_stat_changed(unit_uuid: String, _stat_name: StringName, _old_value: int, _new_value: int) -> void:
	if _is_preview:
		return
	if unit_uuid == _inspected_unit_uuid:
		# Update the instance reference and refresh the description
		var all_instances: Dictionary = _get_all_instances_db()
		var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
		if is_instance_valid(current_instance):
			_instance = current_instance
			_update_description()
			_update_unit_view()
			_reset_window_size()

func _on_inventory_changed() -> void:
	if _is_preview or not is_instance_valid(self):
		return
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances: Dictionary = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_description()
	_update_unit_view()
	_rebuild_item_grid()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	if _is_preview or not is_instance_valid(self):
		return
	
	# Only update if the changed unit is the one we're inspecting
	if unit_uuid != _inspected_unit_uuid:
		return
	
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_UNIT_INV_CHANGE")
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_description()
	_rebuild_item_grid()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _get_all_instances_db() -> Dictionary:
	var result: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		result = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		result = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}
	
	if _is_preview and is_instance_valid(_instance):
		result = result.duplicate()
		result[_instance.ball_uuid] = _instance
	return result

func get_child_window_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	if not is_instance_valid(_instance):
		return specs
	
	var seen_effects: Dictionary = {}
	
	# 1. Keywords from description / abilities
	var text_to_search: String = ""
	if is_instance_valid(description_label):
		text_to_search += description_label.text + " "
	if is_instance_valid(bottom_description_label) and bottom_description_label.visible:
		text_to_search += bottom_description_label.text + " "
	
	var keywords = DescriptionParser.find_keywords(text_to_search)
	for kw in keywords:
		if not seen_effects.has(kw):
			seen_effects[kw] = true
			var name_key = "STATUS_" + kw.to_upper()
			var desc_key = "STATUS_" + kw.to_upper() + "_DESC"
			specs.append({
				"window_type": &"EffectInspection",
				"populate_context": {
					"effect_definition": {
						"name_key": name_key,
						"description_key": desc_key
					},
					"is_inside_unit_inspection": true,
					"target_parent_window_id": get_instance_id()
				}
			})
	
	# 2. Active status effects on the unit (burn, armor, spikes, static)
	for status_key in DescriptionParser.KEYWORDS:
		var effect_id = StringName(status_key.to_lower())
		if _instance.get_status_effect_amount(effect_id) > 0 and not seen_effects.has(status_key):
			seen_effects[status_key] = true
			var name_key = "STATUS_" + status_key
			var desc_key = "STATUS_" + status_key + "_DESC"
			specs.append({
				"window_type": &"EffectInspection",
				"populate_context": {
					"effect_definition": {
						"name_key": name_key,
						"description_key": desc_key
					},
					"is_inside_unit_inspection": true,
					"target_parent_window_id": get_instance_id()
				}
			})
	
	# 3. Equipped items
	var unit_definition = _instance.get_definition()
	if is_instance_valid(unit_definition):
		var all_instances_db = _get_all_instances_db()
		var seen_items: Dictionary = {}
		for i in range(unit_definition.item_slot_count):
			var item_uuid = _instance.get_equipped_item_uuid(i)
			if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
				if seen_items.has(item_uuid):
					continue
				seen_items[item_uuid] = true
				var item_instance = all_instances_db[item_uuid]
				var item_loc = LocationIdentifier.new()
				item_loc.container = C.CONTAINER_EQUIPPED_ITEM
				item_loc.index = i
				item_loc.unit_uuid = _instance.ball_uuid
				specs.append({
					"window_type": &"ItemInspection",
					"populate_context": {
						"source_view": self,
						"instance": item_instance,
						"location": item_loc,
						"is_inside_unit_inspection": true,
						"target_parent_window_id": get_instance_id()
					}
				})
				
	return specs

func get_location() -> LocationIdentifier:
	return _location

## Calculate trait counts for the inspected unit (including emblems)
func _calculate_unit_trait_counts() -> Dictionary:
	var counts: Dictionary = {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	
	if not is_instance_valid(_instance):
		return counts
	
	var all_instances_db = _get_all_instances_db()
	var soul_counts = _instance.get_trait_soul_counts(all_instances_db)
	
	for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
		counts[soul_type] += soul_counts[soul_type]
	
	return counts

## Populate the ViewContainer to show the resulting unit's view at 2x scale.
func _update_unit_view() -> void:
	if not is_instance_valid(view_container):
		return
	
	for child in view_container.get_children():
		view_container.remove_child(child)
		child.queue_free()
	
	if not is_instance_valid(_instance):
		view_container.visible = false
		return
	
	var slot_view: SlotView = _SlotView.instantiate()
	slot_view.show_background = false
	slot_view.set_size_scale(2.0)
	slot_view.custom_minimum_size = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)
	
	var slot_color: StringName = _location.container if is_instance_valid(_location) else &"PlayerBench"
	slot_view.set_slot_color(slot_color)
	
	# Disconnect interactive / indicator signals for inspection view
	if SignalBus.show_slot_indicators.is_connected(slot_view._on_show_slot_indicators):
		SignalBus.show_slot_indicators.disconnect(slot_view._on_show_slot_indicators)
	if SignalBus.hide_slot_indicators.is_connected(slot_view._on_hide_slot_indicators):
		SignalBus.hide_slot_indicators.disconnect(slot_view._on_hide_slot_indicators)
	if SignalBus.unit_stat_changed.is_connected(slot_view._on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(slot_view._on_unit_stat_changed)
	
	slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)
	
	view_container.add_child(slot_view)
	view_container.visible = true

	var all_instances_db = _get_all_instances_db()
	var visual_data = VisualDataAdapter.create_visual_data(_instance, all_instances_db)
	slot_view.set_content(visual_data, false, false)
	
	for child in slot_view.get_children():
		if child is GachaBallView:
			child.show_capsule_overlay = false
			child.set_is_interactive(false)
			var overlay = child.get_node_or_null("GachaBallOverlay")
			if is_instance_valid(overlay):
				overlay.queue_free()
			var trait_count = child.get_node_or_null("%TraitCountLabel")
			if is_instance_valid(trait_count):
				trait_count.visible = false

## Populate the RecipeContainer to show the merge ingredients for this unit.
func _update_recipe_display() -> void:
	if not is_instance_valid(recipe_container):
		return
	
	for child in recipe_container.get_children():
		recipe_container.remove_child(child)
		child.queue_free()
	
	var unit_def = _instance.get_definition() if is_instance_valid(_instance) else null
	if not is_instance_valid(unit_def):
		recipe_container.visible = false
		return
	
	var recipe: MergeRecipe = null
	if not _explicit_recipe_id.is_empty():
		recipe = Database.recipes.get(_explicit_recipe_id)
	if not is_instance_valid(recipe):
		recipe = Database.get_recipe_for_result(unit_def.id)
	if not is_instance_valid(recipe):
		recipe_container.visible = false
		return
	
	var def_a = Database.get_definition(recipe.ingredient_a_id)
	var def_b = Database.get_definition(recipe.ingredient_b_id)
	
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		recipe_container.visible = false
		return
	
	# Build: [Icon A] [+] [Icon B]
	var _make_icon = func(def: Resource) -> TextureRect:
		var tex = TextureRect.new()
		if def and def.icon:
			tex.texture = def.icon
		tex.custom_minimum_size = Vector2(96, 96)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
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

## Update the trait tags display at the top
func _update_trait_display() -> void:
	if is_instance_valid(trait_icons_container):
		for child in trait_icons_container.get_children():
			trait_icons_container.remove_child(child)
			child.queue_free()
		trait_icons_container.visible = false

	if not is_instance_valid(trait_tags_container):
		return

	# Clear existing trait tags
	for child in trait_tags_container.get_children():
		trait_tags_container.remove_child(child)
		child.queue_free()

	if not is_instance_valid(_instance):
		trait_tags_container.visible = false
		return

	var all_instances_db = _get_all_instances_db()
	var soul_counts = _instance.get_trait_soul_counts(all_instances_db)
	var active_tags = _instance.get_active_tags(all_instances_db)

	for trait_id in C.TRAIT_SORT_ORDER:
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_id, {})
		var trait_name: String = tr(trait_def.get("display_name_key", trait_id.capitalize()))

		if trait_id in ["FIRE", "EARTH", "WATER", "AIR"]:
			var count: int = soul_counts.get(trait_id, 0)
			if count > 0:
				var tag_text = "%dx %s" % [count, trait_name]
				_create_trait_tag(trait_id, tag_text)
		else:
			var has_trait := false
			for tag in active_tags:
				if String(tag).to_upper() == trait_id:
					has_trait = true
					break
			if has_trait:
				_create_trait_tag(trait_id, trait_name)

	trait_tags_container.visible = trait_tags_container.get_child_count() > 0

func _create_trait_tag(trait_id: String, text: String) -> void:
	var tag_panel = PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	var base_color: Color = TRAIT_COLORS.get(trait_id, Color(0.35, 0.35, 0.35, 1.0))
	style.bg_color = base_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	tag_panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Database.get_current_locale_font())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	tag_panel.add_child(label)
	trait_tags_container.add_child(tag_panel)

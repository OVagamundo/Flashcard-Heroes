class_name UnitInspectionWindow
extends InspectionWindow

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")
const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel
@onready var trait_icons_container: HBoxContainer = %TraitIconsContainer
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _is_enemy_context: bool = false
var _window_group_id: int = 1 # Inspection window group

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [%DescriptionLabel, %NameLabel, %ItemGrid, %TraitIconsContainer, %RecipeContainer, %HSeparator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
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

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		WindowManager.request_close_inspection_window(self, &"INVALID_DEFINITION")
		return

	_inspected_unit_uuid = _instance.ball_uuid


	name_label.text = tr(unit_definition.display_name_key) + " (Lv. %d)" % _instance.level
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
	_update_recipe_display()

	# Manage separator visibility based on any visible footers
	if is_instance_valid(separator):
		separator.visible = item_grid.visible or trait_icons_container.visible or recipe_container.visible

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()
	enforce_display_only()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		# Zero out hidden containers completely to ensure they contribute NO height
		for container in [item_grid, recipe_container, trait_icons_container, separator]:
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
			
		custom_minimum_size = Vector2(480, 0)
		size = Vector2.ZERO # Force immediate recalculation of minimum size
		reset_size()
		# Let WindowManager know we have settled so it can refine the position if needed
		# (Note: Standard contextual window positioning happens in WindowManager)



func _rebuild_item_grid() -> void:
	# This function now handles the complete lifecycle of the item grid UI.
	# It ensures that slots are persistent and correctly represent the data model.
	if not is_instance_valid(_instance):
		return
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		return

	# Clear existing content from slots, but don't delete the slots themselves.
	for slot_view in item_grid.get_children():
		for content in slot_view.get_children():
			content.queue_free()

	# Ensure the correct number of persistent SlotViews exist.
	var children = item_grid.get_children()
	# Filter out any lingering children that are already queued for deletion
	var active_children = []
	for child in children:
		if not child.is_queued_for_deletion():
			active_children.append(child)
	
	while active_children.size() < unit_definition.item_slot_count:
		var slot_view = _SlotView.instantiate()
		slot_view.custom_minimum_size = Vector2(64, 80)
		slot_view.set_size_scale(1.0)
		item_grid.add_child(slot_view)
		active_children.append(slot_view)
		
	while active_children.size() > unit_definition.item_slot_count:
		var slot_to_remove = active_children.pop_back()
		item_grid.remove_child(slot_to_remove)
		slot_to_remove.queue_free()

	if unit_definition.item_slot_count == 0:
		item_grid_label.visible = false
		item_grid.visible = false
		return
	else:
		item_grid_label.visible = false
		item_grid.visible = true
		item_grid.columns = unit_definition.item_slot_count

	var all_instances_db = _get_all_instances_db()
	if all_instances_db.is_empty():
		return

	# Iterate through all defined slots and populate them.
	for i in range(unit_definition.item_slot_count):
		var slot_view = item_grid.get_child(i)
		
		# CRITICAL: Create a valid LocationIdentifier for EVERY slot, empty or not.
		var loc = LocationIdentifier.new()
		loc.container = C.CONTAINER_EQUIPPED_ITEM
		loc.index = i
		loc.unit_uuid = _instance.ball_uuid
		slot_view.populate(loc) # This makes the empty slot a valid drop target.
		slot_view.set_slot_color(loc.container) # Ensure correct texture (ItemSlot.png)
		
		# Set interaction context for the slot
		var slot_interaction_mode = &"INSPECTION_ONLY" if _is_enemy_context else &"FULLY_INTERACTIVE"
		slot_view.set_interaction_context(slot_interaction_mode, _window_group_id)

		var item_uuid = _instance.get_equipped_item_uuid(i)

		if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
			var item_instance = all_instances_db[item_uuid]
			
			# Enhanced contextual behavior for player vs enemy units
			var is_interactive = not _is_enemy_context
			var single_click_inspect = _is_enemy_context
			var interaction_mode = &"INSPECTION_ONLY" if _is_enemy_context else &"FULLY_INTERACTIVE"
			
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(item_instance)
			slot_view.set_content(visual_data, true, _is_enemy_context)
			
			if slot_view.get_child_count() > 0:
				var gacha_view = slot_view.get_child(0)
				if gacha_view is GachaBallView:
					gacha_view.set_is_interactive(is_interactive)
					gacha_view.set_interaction_context(interaction_mode, &"ITEM", _window_group_id)

	
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
	
	# --- Source-Aware Stat Breakdown ---
	var breakdown = _instance.get_stat_breakdown(all_instances_db)
	var breakdown_lines: Array[String] = []
	breakdown_lines.append("\n[color=gray][i]--- Stat Breakdown ---[/i][/color]")
	
	var hp_line = "[b]HP[/b]: %d" % breakdown.current.hp
	var hp_parts: Array[String] = []
	hp_parts.append("%d Base" % breakdown.base.hp)
	if breakdown.persistent.hp != 0: hp_parts.append("%+d Merge" % breakdown.persistent.hp)
	if breakdown.equipment.hp != 0: hp_parts.append("%+d Item" % breakdown.equipment.hp)
	if breakdown.battle.hp != 0: hp_parts.append("%+d Battle" % breakdown.battle.hp)
	if hp_parts.size() > 1: hp_line += " (%s)" % ", ".join(hp_parts)
	breakdown_lines.append(hp_line)
	
	var pwr_line = "[b]PWR[/b]: %d" % breakdown.current.pwr
	var pwr_parts: Array[String] = []
	pwr_parts.append("%d Base" % breakdown.base.pwr)
	if breakdown.persistent.pwr != 0: pwr_parts.append("%+d Merge" % breakdown.persistent.pwr)
	if breakdown.equipment.pwr != 0: pwr_parts.append("%+d Item" % breakdown.equipment.pwr)
	if breakdown.battle.pwr != 0: pwr_parts.append("%+d Battle" % breakdown.battle.pwr)
	if pwr_parts.size() > 1: pwr_line += " (%s)" % ", ".join(pwr_parts)
	breakdown_lines.append(pwr_line)
	
	full_text += "\n" + "\n".join(breakdown_lines)

	if not full_text.is_empty():
		full_text = DescriptionParser.parse(full_text)

	var final_text = full_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	description_label.text = final_text
	description_label.set_meta("definition", unit_definition)
	description_label.set_meta("effect_definition", unit_definition)
## Granular stat change handler - updates description when any stat changes
func _on_unit_stat_changed(unit_uuid: String, _stat_name: StringName, _old_value: int, _new_value: int) -> void:
	if unit_uuid == _inspected_unit_uuid:
		# Update the instance reference and refresh the description
		var all_instances: Dictionary = _get_all_instances_db()
		var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
		if is_instance_valid(current_instance):
			_instance = current_instance
			_update_description()
			_reset_window_size()

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
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
	_rebuild_item_grid()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	if not is_instance_valid(self):
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

## Populate the RecipeContainer to show the merge ingredients for this unit.
func _update_recipe_display() -> void:
	if not is_instance_valid(recipe_container):
		return
	
	for child in recipe_container.get_children():
		child.queue_free()
	
	var unit_def = _instance.get_definition() if is_instance_valid(_instance) else null
	if not is_instance_valid(unit_def):
		recipe_container.visible = false
		return
	
	var recipe: MergeRecipe = Database.get_recipe_for_result(unit_def.id)
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

## Update the trait icons display
func _update_trait_display() -> void:
	if not is_instance_valid(trait_icons_container):
		return
	
	# Clear existing trait icons
	for child in trait_icons_container.get_children():
		child.queue_free()
	
	var trait_counts = _calculate_unit_trait_counts()
	
	# Display Fire trait if count > 0
	if trait_counts["FIRE"] > 0:
		var fire_container = HBoxContainer.new()
		fire_container.add_theme_constant_override("separation", 4)
		
		var fire_icon = TextureRect.new()
		fire_icon.texture = preload("res://assets/Realistic/sprites/items/FireEmblem.png")
		fire_icon.custom_minimum_size = Vector2(96, 96)
		fire_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		fire_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var fire_label = Label.new()
		fire_label.text = "x%d" % trait_counts["FIRE"]
		fire_label.add_theme_font_size_override("font_size", 32)
		fire_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		fire_container.add_child(fire_icon)
		fire_container.add_child(fire_label)
		trait_icons_container.add_child(fire_container)
	
	# Display Earth trait if count > 0
	if trait_counts["EARTH"] > 0:
		var earth_container = HBoxContainer.new()
		earth_container.add_theme_constant_override("separation", 4)
		
		var earth_icon = TextureRect.new()
		earth_icon.texture = preload("res://assets/Realistic/sprites/items/EarthEmblem.png")
		earth_icon.custom_minimum_size = Vector2(96, 96)
		earth_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		earth_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var earth_label = Label.new()
		earth_label.text = "x%d" % trait_counts["EARTH"]
		earth_label.add_theme_font_size_override("font_size", 32)
		earth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		earth_container.add_child(earth_icon)
		earth_container.add_child(earth_label)
		trait_icons_container.add_child(earth_container)
	
	# Display Water trait if count > 0
	if trait_counts["WATER"] > 0:
		var water_container = HBoxContainer.new()
		water_container.add_theme_constant_override("separation", 4)
		
		var water_icon = TextureRect.new()
		water_icon.texture = preload("res://assets/Realistic/sprites/items/WaterEmblem.png")
		water_icon.custom_minimum_size = Vector2(96, 96)
		water_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		water_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var water_label = Label.new()
		water_label.text = "x%d" % trait_counts["WATER"]
		water_label.add_theme_font_size_override("font_size", 32)
		water_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		water_container.add_child(water_icon)
		water_container.add_child(water_label)
		trait_icons_container.add_child(water_container)
	
	# Display Air trait if count > 0
	if trait_counts["AIR"] > 0:
		var air_container = HBoxContainer.new()
		air_container.add_theme_constant_override("separation", 4)
		
		var air_icon = TextureRect.new()
		air_icon.texture = preload("res://assets/Realistic/sprites/items/AirEmblem.png")
		air_icon.custom_minimum_size = Vector2(96, 96)
		air_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		air_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var air_label = Label.new()
		air_label.text = "x%d" % trait_counts["AIR"]
		air_label.add_theme_font_size_override("font_size", 32)
		air_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		air_container.add_child(air_icon)
		air_container.add_child(air_label)
		trait_icons_container.add_child(air_container)
	
	# Only show the container if it actually has content
	trait_icons_container.visible = trait_icons_container.get_child_count() > 0

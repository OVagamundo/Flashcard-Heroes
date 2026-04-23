class_name UnitInspectionWindow
extends "res://scripts/InspectionWindow.gd"

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")
const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
const BOLD_FONT = preload("res://assets/fonts/noto_sans_black_composite.tres")
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
var _stable_anchor: Control = null # Stable anchor for positioning

func _ready() -> void:
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	
	# Allow non-link clicks on the description to bubble to the window root
	# Hover handlers below will set STOP only while over UI links
	description_label.mouse_filter = MOUSE_FILTER_PASS

	# Prune children when clicking anywhere on the window background area
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)

	# Also treat clicks on the item grid (empty slots area) as background for pruning
	if is_instance_valid(item_grid):
		item_grid.mouse_filter = MOUSE_FILTER_STOP
		item_grid.gui_input.connect(_on_item_grid_gui_input)

	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

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
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_enemy_context = context.get("is_enemy_context", false)

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		WindowManager.request_close_inspection_window(self , &"INVALID_DEFINITION")
		return

	_inspected_unit_uuid = _instance.ball_uuid

	# Set up stable anchor pattern
	_setup_stable_anchor()

	name_label.text = tr(unit_definition.display_name_key)
	name_label.add_theme_font_override("font", BOLD_FONT)
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

func _reset_window_size() -> void:
	# Defer for TWO frames to ensure Godot's layout engine has settled all queue_free and fit_content operations
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		# Let WindowManager know we have settled so it can refine the position if needed
		# (Note: Standard contextual window positioning happens in WindowManager)

## Set up stable anchor pattern for robust positioning
func _setup_stable_anchor() -> void:
	if is_instance_valid(_source_view):
		# Find the nearest stable container (SlotView or PanelContainer)
		_stable_anchor = _find_stable_anchor(_source_view)
		if is_instance_valid(_stable_anchor):
			# Connect to anchor movement for dynamic positioning
			_stable_anchor.item_rect_changed.connect(_on_anchor_moved)
			_stable_anchor.tree_exited.connect(_on_anchor_freed)

## Find stable anchor for positioning
func _find_stable_anchor(original_anchor: Control) -> Control:
	# If the original anchor is already a stable container, use it
	if original_anchor.get_class() == "SlotView" or original_anchor.get_class() == "PanelContainer":
		return original_anchor
	
	# Otherwise, find the nearest stable container parent
	var current = original_anchor
	while is_instance_valid(current) and current != get_tree().root:
		if current.get_class() == "SlotView" or current.get_class() == "PanelContainer":
			return current
		current = current.get_parent()
	
	# If no stable container found, fall back to the original anchor
	return original_anchor

## Handle anchor movement for dynamic positioning
func _on_anchor_moved() -> void:
	if is_instance_valid(_stable_anchor):
		# Reposition window relative to anchor
		global_position = _calculate_position_relative_to_anchor()

## Handle anchor being freed
func _on_anchor_freed() -> void:
	# Defer briefly to allow UI to settle (e.g., during inventory reflow) before deciding to close.
	# This avoids premature self-closing that bypasses WindowManager suppression during actions.
	var self_ref = self
	var tree = get_tree()
	if not is_instance_valid(tree):
		return
	await tree.create_timer(0.25).timeout
	if not is_instance_valid(self_ref) or not is_instance_valid(self ):
		return
	# Try to re-establish a stable anchor from the current source view
	_setup_stable_anchor()
	if not is_instance_valid(_stable_anchor):
		WindowManager.request_close_inspection_window(self , &"ANCHOR_LOST_NO_STABLE")

## Calculate position relative to stable anchor
func _calculate_position_relative_to_anchor() -> Vector2:
	if not is_instance_valid(_stable_anchor):
		return global_position
	
	var anchor_rect = _stable_anchor.get_global_rect()
	var window_size = size
	var viewport_rect = get_viewport().get_visible_rect()
	
	# Try to position to the right of the anchor
	var pos_right = Vector2(anchor_rect.end.x + 20, anchor_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_right, window_size)):
		return pos_right
	
	# Try to position below the anchor
	var pos_below = Vector2(anchor_rect.position.x, anchor_rect.end.y + 20)
	if viewport_rect.encloses(Rect2(pos_below, window_size)):
		return pos_below
	
	# Try to position above the anchor
	var pos_above = Vector2(anchor_rect.position.x, anchor_rect.position.y - window_size.y - 20)
	if viewport_rect.encloses(Rect2(pos_above, window_size)):
		return pos_above
	
	# Fallback: position to the left of the anchor
	var pos_left = Vector2(anchor_rect.position.x - window_size.x - 20, anchor_rect.position.y)
	if viewport_rect.encloses(Rect2(pos_left, window_size)):
		return pos_left
	
	# Last resort: position in the top-right corner of the anchor
	return Vector2(anchor_rect.end.x - window_size.x - 20, anchor_rect.position.y + 20)


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
			slot_view.set_content(visual_data, true, single_click_inspect, false)
			
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
	var seen_ability_names: Dictionary = {}
	
	for ability_def: AbilityDefinition in unit_definition.ability_definitions:
		if not ability_def or ability_def.id == &"basic_attack":
			continue
		
		var ability_name = tr(ability_def.name_key)
		if ability_name.is_empty() or seen_ability_names.has(ability_name):
			continue
		seen_ability_names[ability_name] = true
		
		var ability_desc = tr(ability_def.description_key)
		if is_instance_valid(_instance):
			ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
			ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
		
		if not ability_desc.is_empty():
			abilities_lines.append("[b]%s[/b]: %s" % [ability_name, ability_desc])

	var abilities_block := "\n".join(abilities_lines)
	var full_text: String = abilities_block
	if not full_text.is_empty():
		full_text += "\n"
	full_text += "[url=effect]EFFECTS[/url]"

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
	if not is_instance_valid(self ):
		return
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances: Dictionary = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self , &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_description()
	_rebuild_item_grid()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	if not is_instance_valid(self ):
		return
	
	# Only update if the changed unit is the one we're inspecting
	if unit_uuid != _inspected_unit_uuid:
		return
	
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self , &"INSTANCE_MISSING_AFTER_UNIT_INV_CHANGE")
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

func _on_description_meta_clicked(meta) -> void:
	if meta == "effect":
		var definition: Variant = description_label.get_meta("effect_definition")
		if definition:
			# Ensure EffectInspection uses the Unit window as its parent when inside unit inspection.
			var parent_win: Control = WindowManager.find_ancestor_window_for_view(self )
			var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
			WindowManager.open_child_contextual_window(
				&"EffectInspection",
				self ,
				{
					"effect_definition": definition.ability_definitions,
					"is_inside_unit_inspection": true,
					"target_parent_window_id": parent_id
				}
			)
			# Prevent this click from propagating as a WINDOW_BACKGROUND/global click
			get_viewport().set_input_as_handled()
			accept_event()

## Recursively set mouse filters to PASS for child controls that should bubble to the root
func _configure_mouse_filters() -> void:
	var stack: Array = [ self ]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Skip nodes that have explicit handlers or must remain STOP
				if child == internal_background or child == item_grid or child == description_label:
					pass
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

func _on_description_gui_input(_event: InputEvent) -> void:
	if not is_instance_valid(_instance):
		return
	# No-op: we rely on meta hover/click to manage link interactions.
	pass

func _on_internal_background_gui_input(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()
		accept_event()

func _on_item_grid_gui_input(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()
		accept_event()

func _on_description_meta_hover_started(_meta) -> void:
	description_label.mouse_filter = MOUSE_FILTER_STOP

func _on_description_meta_hover_ended(_meta) -> void:
	description_label.mouse_filter = MOUSE_FILTER_PASS

func get_location() -> LocationIdentifier:
	return _location

## Calculate trait counts for the inspected unit (including emblems)
func _calculate_unit_trait_counts() -> Dictionary:
	var counts: Dictionary = {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	
	if not is_instance_valid(_instance):
		return counts
	
	# Count traits from unit's definition tags
	var unit_def = _instance.get_definition()
	if is_instance_valid(unit_def) and "tags" in unit_def:
		for tag in unit_def.tags:
			if tag == &"SOUL_FIRE":
				counts["FIRE"] += 1
			elif tag == &"SOUL_EARTH":
				counts["EARTH"] += 1
			elif tag == &"SOUL_WATER":
				counts["WATER"] += 1
			elif tag == &"SOUL_AIR":
				counts["AIR"] += 1
	
	# Count traits from equipped items (emblems)
	var all_instances_db = _get_all_instances_db()
	if all_instances_db.is_empty():
		return counts
	
	for item_uuid in _instance.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		
		var item_instance = all_instances_db.get(item_uuid)
		if not is_instance_valid(item_instance):
			continue
		
		var item_def = item_instance.get_definition()
		if not is_instance_valid(item_def) or not "tags" in item_def:
			continue
		
		for tag in item_def.tags:
			if tag == &"SOUL_FIRE":
				counts["FIRE"] += 1
			elif tag == &"SOUL_EARTH":
				counts["EARTH"] += 1
			elif tag == &"SOUL_WATER":
				counts["WATER"] += 1
			elif tag == &"SOUL_AIR":
				counts["AIR"] += 1
	
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
		if "icon" in def and def.icon != null:
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
		fire_icon.texture = preload("res://assets/sprites/items/FireEmblem.png")
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
		earth_icon.texture = preload("res://assets/sprites/items/EarthEmblem.png")
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
		water_icon.texture = preload("res://assets/sprites/items/WaterEmblem.png")
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
		air_icon.texture = preload("res://assets/sprites/items/AirEmblem.png")
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

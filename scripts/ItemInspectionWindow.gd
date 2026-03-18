class_name ItemInspectionWindow
extends "res://scripts/InspectionWindow.gd"

const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _stable_anchor: Control = null # Stable anchor for positioning

func _ready() -> void:
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Allow non-link clicks to bubble to the window root so it can prune children
	description_label.mouse_filter = MOUSE_FILTER_PASS
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

	# Set up stable anchor pattern
	_setup_stable_anchor()

	var name_key: String
	if item_def is GachaBallDefinition:
		name_key = item_def.display_name_key
	else:
		# TrinketDefinition uses name_key instead of display_name_key
		name_key = item_def.name_key
	
	name_label.text = tr(name_key)
	# Omit base flavor description for items; we will show only stats and abilities.
	
	# Add item effect description (only for GachaBallDefinition items)
	var effect_desc = ""
	if item_def is GachaBallDefinition:
		if item_def.bonus_hp > 0 and item_def.bonus_pwr > 0:
			effect_desc = tr("item.effect.both").replace("(HP)", str(item_def.bonus_hp)).replace("(PWR)", str(item_def.bonus_pwr))
		elif item_def.bonus_hp > 0:
			effect_desc = tr("item.effect.hp").replace("(HP)", str(item_def.bonus_hp))
		elif item_def.bonus_pwr > 0:
			effect_desc = tr("item.effect.pwr").replace("(PWR)", str(item_def.bonus_pwr))
	
	# Build abilities section: list all abilities with name and localized description
	var abilities_block := ""
	if "ability_definitions" in item_def and item_def.ability_definitions.size() > 0:
		var abilities_lines: Array[String] = []
		for ability in item_def.ability_definitions:
			if not is_instance_valid(ability):
				continue
			var ability_name := tr(ability.name_key) if "name_key" in ability else ""
			var ability_desc := tr(ability.description_key) if "description_key" in ability else ""
			if is_instance_valid(_instance):
				ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
				ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
			
			if not ability_name.is_empty() or not ability_desc.is_empty():
				abilities_lines.append("[b]%s[/b]: %s" % [ability_name, ability_desc])
		abilities_block = "\n".join(abilities_lines)

	var full_text: String = ""
	if not effect_desc.is_empty():
		full_text += effect_desc
	if not abilities_block.is_empty():
		if not full_text.is_empty():
			full_text += "\n"
		full_text += abilities_block
	if not full_text.is_empty():
		full_text += "\n[url=effect]EFFECTS[/url]"
	else:
		full_text = "[url=effect]EFFECTS[/url]"

	description_label.text = full_text.strip_edges()
	
	# Store the full definition for the child window to use.
	description_label.set_meta("effect_definition", item_def)
	
	_update_recipe_display(item_def)

	# Manage separator visibility based on recipe container
	if is_instance_valid(separator):
		separator.visible = recipe_container.visible

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()

func _reset_window_size() -> void:
	# Defer for TWO frames to ensure Godot's layout engine has settled all queue_free and fit_content operations
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO

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
		if "icon" in def and def.icon != null:
			tex.texture = def.icon
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = MOUSE_FILTER_IGNORE
		return tex
	
	var _make_label = func(txt: String) -> Label:
		var lbl = Label.new()
		lbl.text = txt
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		return lbl
	
	recipe_container.add_child(_make_icon.call(def_a))
	recipe_container.add_child(_make_label.call("+"))
	recipe_container.add_child(_make_icon.call(def_b))
	recipe_container.visible = true
func _on_description_meta_clicked(meta) -> void:
	if meta == "effect":
		var definition: Variant = description_label.get_meta("effect_definition")
		if definition:
			# Open EffectInspection as a CHILD contextual window anchored to this window.
			# Provide context so WindowManager can pick the correct parent (e.g., UnitInspection).
			var parent_win: Control = WindowManager.find_ancestor_window_for_view(self )
			var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
			var inside_unit: bool = parent_win is UnitInspectionWindow
			WindowManager.open_child_contextual_window(
				&"EffectInspection",
				self ,
				{
					"effect_definition": definition.ability_definitions,
					"is_inside_unit_inspection": inside_unit,
					"target_parent_window_id": parent_id
				}
			)
			# Prevent this click from propagating as a WINDOW_BACKGROUND/global click
			get_viewport().set_input_as_handled()
			accept_event()

func _on_description_gui_input(_event: InputEvent) -> void:
	# No-op: non-link clicks should bubble to the window root to trigger pruning.
	# Link clicks are handled in _on_description_meta_clicked and are consumed there.
	pass

func _on_internal_background_gui_input(_event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(_event):
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()
		accept_event()

func get_location() -> LocationIdentifier:
	return _location

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
	# This avoids premature self-closing that can bypass WindowManager suppression during actions.
	var self_ref = self
	await get_tree().create_timer(0.25).timeout
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

class_name InspectionWindow
extends PanelContainer

const _C = preload("res://scripts/Constants.gd")
const _PREVIEW_SLOT_VIEW_PATH: String = "res://scenes/SlotView.tscn"

## ID of the parent inspection window, or -1 if this is a root inspection window.
var parent_inspection_window_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enforce_display_only()

func enforce_display_only() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mouse_filter_recursive(self)

func populate(_context: Dictionary) -> void:
	pass

func _apply_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		if node.get_meta("interactive", false):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_apply_mouse_filter_recursive(child)

func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		# WindowManager might not exist if the game is shutting down.
		if WindowManager:
			WindowManager.stop_tracking_window(self.get_instance_id())

func get_child_window_specs() -> Array[Dictionary]:
	return []

func get_glossary_terms() -> Array[String]:
	return []

func _position_child_window(parent_window: Control) -> void:
	# This method is called by WindowManager to position child windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_child_window_position(parent_window, self)
		set_global_position(position)

func _position_root_window(source_view: Control) -> void:
	# This method is called by WindowManager to position root windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_window_position(source_view, self)
		set_global_position(position)

func _reset_window_size() -> void:
	pass

func _schedule_deferred_shrink() -> void:
	call_deferred("_deferred_shrink_step", 2)

func _deferred_shrink_step(frames_remaining: int) -> void:
	if not is_inside_tree():
		return
	if frames_remaining > 0:
		call_deferred("_deferred_shrink_step", frames_remaining - 1)
		return
	_reset_window_size()

func _shrink_window_layout(width: float, zero_size_on_reset: bool = false, collapsible_containers: Array = []) -> void:
	for container: Variant in collapsible_containers:
		if container is Control and is_instance_valid(container) and not (container as Control).visible:
			(container as Control).custom_minimum_size = Vector2.ZERO

	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin_container: Control = get_node_or_null("MarginContainer") as Control
	if is_instance_valid(margin_container):
		margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var vbox: Control = get_node_or_null("MarginContainer/VBoxContainer") as Control
	if is_instance_valid(vbox):
		vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	custom_minimum_size = Vector2(width, 0)
	size = Vector2.ZERO if zero_size_on_reset else Vector2(width, 0)
	reset_size()

func _populate_preview_slot_view(
	target_container: Control,
	instance: GachaBallInstance,
	location: LocationIdentifier,
	all_instances_db: Dictionary,
	is_preview: bool,
	fallback_container: StringName = &"PlayerShelf"
) -> void:
	if not is_instance_valid(target_container):
		return
	for child in target_container.get_children():
		target_container.remove_child(child)
		child.queue_free()

	if not is_preview or not is_instance_valid(instance):
		target_container.visible = false
		target_container.custom_minimum_size = Vector2.ZERO
		return

	var slot_scene: PackedScene = load(_PREVIEW_SLOT_VIEW_PATH) as PackedScene
	var slot_view: SlotView = slot_scene.instantiate() as SlotView
	slot_view.show_background = false
	slot_view.set_size_scale(2.0)
	slot_view.custom_minimum_size = Vector2(_C.SLOT_SIZE_2X, _C.SLOT_SIZE_2X)

	var slot_color: StringName = location.container if is_instance_valid(location) else fallback_container
	slot_view.set_slot_color(slot_color)

	if SignalBus.show_slot_indicators.is_connected(slot_view._on_show_slot_indicators):
		SignalBus.show_slot_indicators.disconnect(slot_view._on_show_slot_indicators)
	if SignalBus.hide_slot_indicators.is_connected(slot_view._on_hide_slot_indicators):
		SignalBus.hide_slot_indicators.disconnect(slot_view._on_hide_slot_indicators)
	if SignalBus.unit_stat_changed.is_connected(slot_view._on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(slot_view._on_unit_stat_changed)

	slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

	target_container.add_child(slot_view)
	slot_view.z_as_relative = true
	slot_view.z_index = 1
	target_container.visible = true
	target_container.custom_minimum_size = Vector2(0, _C.SLOT_SIZE_2X)

	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance, all_instances_db)
	var gb: GachaBallView = slot_view.set_content(visual_data, false, false)
	if is_instance_valid(gb):
		gb.z_as_relative = true
		gb.z_index = 1
		gb._base_z_index = 1
		gb._slot_base_z_index = 1
		gb.show_capsule_overlay = false
		gb.set_is_interactive(false)
		var overlay: Node = gb.get_node_or_null("GachaBallOverlay")
		if is_instance_valid(overlay):
			overlay.queue_free()
		var trait_count: Control = gb.get_node_or_null("%TraitCountLabel") as Control
		if is_instance_valid(trait_count):
			trait_count.visible = false

func _populate_recipe_container(
	target_container: HBoxContainer,
	result_def: Resource,
	explicit_recipe_id: StringName,
	is_preview: bool
) -> void:
	if not is_instance_valid(target_container):
		return
	for child in target_container.get_children():
		target_container.remove_child(child)
		child.queue_free()

	if is_preview:
		target_container.visible = false
		target_container.custom_minimum_size = Vector2.ZERO
		return

	if not result_def is GachaBallDefinition:
		target_container.visible = false
		return

	var def_id: StringName = (result_def as GachaBallDefinition).id
	var recipe: MergeRecipe = null
	if explicit_recipe_id != &"":
		recipe = Database.recipes.get(explicit_recipe_id)
	if not is_instance_valid(recipe):
		recipe = Database.get_recipe_for_result(def_id)
	if not is_instance_valid(recipe):
		target_container.visible = false
		return

	var def_a: Resource = Database.get_definition(recipe.ingredient_a_id)
	var def_b: Resource = Database.get_definition(recipe.ingredient_b_id)
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		target_container.visible = false
		return

	target_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	target_container.custom_minimum_size = Vector2(0, 96)

	target_container.add_child(_make_recipe_icon(def_a))
	target_container.add_child(_make_recipe_operator_label("+"))
	target_container.add_child(_make_recipe_icon(def_b))
	target_container.visible = true

func _make_recipe_icon(def: Resource) -> TextureRect:
	var tex := TextureRect.new()
	if def is GachaBallDefinition and is_instance_valid((def as GachaBallDefinition).icon):
		tex.texture = (def as GachaBallDefinition).icon
	elif def is TrinketDefinition and is_instance_valid((def as TrinketDefinition).icon):
		tex.texture = (def as TrinketDefinition).icon
	tex.custom_minimum_size = Vector2(96, 96)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = MOUSE_FILTER_IGNORE
	return tex

func _make_recipe_operator_label(txt: String) -> Control:
	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(32, 96)
	container.mouse_filter = MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", Database.get_current_locale_font())
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = MOUSE_FILTER_IGNORE

	container.add_child(lbl)
	return container

func _collect_glossary_terms_from_labels(labels: Array) -> Array[String]:
	var text_to_search: String = ""
	for lbl_val: Variant in labels:
		if lbl_val is RichTextLabel and is_instance_valid(lbl_val):
			var rtl := lbl_val as RichTextLabel
			if rtl.visible and not rtl.text.is_empty():
				text_to_search += rtl.text + " "
	var terms: Array[String] = []
	terms.append_array(DescriptionParser.find_keywords(text_to_search))
	return terms

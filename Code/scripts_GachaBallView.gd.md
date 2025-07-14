<!-- Original: scripts/GachaBallView.gd -->

```gdscript
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _location: LocationIdentifier
var _instance_uuid: String
var _is_selected: bool = false
var _is_inspectable: bool = true
var _single_click_inspect: bool = false

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	EventBus.invalid_action_triggered.connect(func(v): _on_invalid_action_triggered(v))
	EventBus.unit_stats_changed.connect(_on_unit_stats_changed)

func populate(loc: LocationIdentifier, instance: GachaBallInstance, is_inspectable: bool = true, single_click_inspect: bool = false):
	self._location = loc
	self._instance_uuid = instance.ball_uuid
	self._is_inspectable = is_inspectable
	self._single_click_inspect = single_click_inspect
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

	var definition = instance.get_definition()
	if not is_instance_valid(definition):
		visible = false
		return
	
	visible = true
	icon_rect.texture = definition.icon
	tier_label.text = "T%d" % definition.tier
	tooltip_text = tr(definition.display_name_key)
	
	# Update stats and item slots
	_update_stats(instance)
	_update_item_slots(instance)
	_apply_selection_feedback()

func set_is_enemy(is_enemy: bool):
	if is_instance_valid(icon_rect):
		icon_rect.flip_h = is_enemy

func _update_stats(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var definition = instance.get_definition()
	if not definition or definition.category != &"UNIT":
		hp_label.visible = false
		pwr_label.visible = false
		return
	
	hp_label.visible = true
	pwr_label.visible = true
	hp_label.text = "HP: %d" % instance.current_hp
	pwr_label.text = "PWR: %d" % instance.current_pwr

func _update_item_slots(instance: GachaBallInstance):
	for child in item_grid.get_children():
		child.queue_free()
	
	var all_instances = _get_all_instances_db()
	if all_instances.is_empty(): return
		
	for item_uuid in instance.equipped_item_uuids:
		var slot_panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(12, 12)
		if not item_uuid.is_empty() and all_instances.has(item_uuid):
			var item_instance = all_instances[item_uuid]
			var item_def = item_instance.get_definition()
			if is_instance_valid(item_def):
				var icon = TextureRect.new()
				icon.texture = item_def.icon
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				slot_panel.add_child(icon)
				icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_grid.add_child(slot_panel)

# Helper: climb the tree to find the nearest SlotView for correct window anchoring.
func _find_slot_anchor() -> Control:
	var node: Node = self.get_parent()
	while node and node != get_tree().root:
		# Use class name string to avoid hard dependency.
		if "SlotView" in node.get_class():
			return node as Control
		node = node.get_parent()
	return self # fallback if none found

func _on_unit_stats_changed(unit_uuid: String):
	if _instance_uuid == unit_uuid:
		var instance = _get_instance_by_uuid(unit_uuid)
		if is_instance_valid(instance):
			_update_stats(instance)

func _gui_input(event: InputEvent):
	if not is_instance_valid(_location): return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		get_viewport().set_input_as_handled()
		
		if _is_inspectable:
			var open_inspect := false
			if event.double_click:
				open_inspect = true
			elif _single_click_inspect:
				# Make sure we are not in the middle of a drag start
				open_inspect = true
			if open_inspect:
				EventBus.emit_signal("inspection_requested", _location, _find_slot_anchor())
				InteractionManager.clear_selection()
				return

			var selected_loc = InteractionManager.get_selected_location()
			if is_instance_valid(selected_loc) and selected_loc != _location:
				EventBus.emit_signal("inventory_action_requested", selected_loc, _location)
			else:
				InteractionManager.select_view(self, _location)
		else: # Not inspectable, but might be part of another window
			# Pass the stable parent (SlotView) for positioning and the location for data.
			EventBus.emit_signal("inspection_requested", _location, _find_slot_anchor())

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _is_inspectable or not is_instance_valid(_location): return null

	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)

	var placeholder = Control.new()
	placeholder.custom_minimum_size = self.size
	get_parent().add_child(placeholder)
	get_parent().move_child(placeholder, get_index())

	InteractionManager.start_drag(self, placeholder)
	return { "source_loc": _location }

func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
	# Notify game logic to process the inventory action
	EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)
	# Clean up the drag state so the placeholder and transparency are removed
	InteractionManager.end_drag(true)

func _on_view_selected(view: Control, _loc: LocationIdentifier):
	if view == self:
		_is_selected = true
		_apply_selection_feedback()

func _on_view_deselected(view: Control):
	if view == self:
		_is_selected = false
		_apply_selection_feedback()

func _on_invalid_action_triggered(view: Control):
	if view == self and animation_player.has_animation("shake"):
		animation_player.play("shake")

func _apply_selection_feedback():
	if not is_inside_tree(): return
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if _is_selected:
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
	else:
		stylebox.border_width_left = 0
		stylebox.border_width_top = 0
		stylebox.border_width_right = 0
		stylebox.border_width_bottom = 0
	add_theme_stylebox_override("panel", stylebox)

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		if InteractionManager.is_drag_active() and InteractionManager.get_drag_source_view() == self:
			InteractionManager.end_drag(true)

func _get_all_instances_db() -> Dictionary:
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		return bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	var db = _get_all_instances_db()
	return db.get(uuid)

```
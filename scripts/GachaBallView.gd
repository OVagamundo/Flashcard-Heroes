# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var instance_data: GachaBallInstance = null
var is_selectable: bool = true
var _is_selected: bool = false

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	EventBus.invalid_action_triggered.connect(_on_invalid_action_triggered)
	InteractionManager.drag_operation_ended.connect(_on_drag_operation_ended)
	_update_visuals()

func _update_visuals():
	if not is_instance_valid(self): return
	
	if instance_data:
		var definition = Database.units.get(instance_data.definition_id, Database.items.get(instance_data.definition_id))
		if definition:
			icon_rect.texture = definition.icon
			tier_label.text = "T%d" % definition.tier
			self.tooltip_text = tr(definition.display_name_key)
		else:
			icon_rect.texture = null
			tier_label.text = "ERR"
			self.tooltip_text = "Unknown ID: %s" % instance_data.definition_id
		visible = true
	else:
		visible = false

func set_instance_data(data: GachaBallInstance):
	self.instance_data = data
	# If the node is already in the scene tree and ready, update visuals now.
	# Otherwise, _ready() will handle the initial update.
	if is_node_ready():
		_update_visuals()

func get_instance_data() -> GachaBallInstance:
	return instance_data

func initialize(tier: int, index: int, container_name: StringName = ""):
	var location_identifier = {"tier": tier, "index": index, "container": container_name}
	set_meta("location_identifier", location_identifier)

func _gui_input(event: InputEvent):
	if not instance_data:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_selectable:
			var selected_view = InteractionManager.get_selected_view()
			if is_instance_valid(selected_view) and selected_view != self:
				EventBus.emit_signal("inventory_action_requested", selected_view, self)
			else:
				InteractionManager.select_view(self)
		else: # Is not selectable, so it's "inspect-only"
			EventBus.emit_signal("inspection_requested", self)

		get_viewport().set_input_as_handled()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_selectable or not instance_data: return null # Use is_selectable here
	InteractionManager.start_drag(self)
	var preview = self.duplicate()
	preview.custom_minimum_size = self.size
	set_drag_preview(preview)
	self.visible = false
	return self

func _can_drop_data(_at_position, data) -> bool:
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	InteractionManager.end_drag(true)
	EventBus.emit_signal("inventory_action_requested", source_view, self)

func _on_view_selected(view: Control):
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

func _on_drag_operation_ended(was_handled: bool):
	if not was_handled and InteractionManager.get_drag_source_view() == self:
		if not self.visible:
			self.visible = true

func _apply_selection_feedback():
	if _is_selected:
		var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
		add_theme_stylebox_override("panel", stylebox)
	else:
		remove_theme_stylebox_override("panel")

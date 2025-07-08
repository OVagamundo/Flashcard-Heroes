<!-- Original: scripts/GachaBallView.gd -->

```gdscript
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel

var instance_data: GachaBallInstance = null
var is_selectable: bool = true
var _is_selected: bool = false

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	EventBus.invalid_action_triggered.connect(func(v): _on_invalid_action_triggered(v))
	EventBus.unit_stats_changed.connect(_on_unit_stats_changed)
	_update_visuals()

func _update_visuals():
	if not is_instance_valid(self): return
	
	if instance_data:
		var definition = instance_data.get_definition()
		if definition:
			icon_rect.texture = definition.icon
			tier_label.text = "T%d" % definition.tier
			self.tooltip_text = tr(definition.display_name_key)
			_update_stats() # Update stats on visual refresh
		else:
			icon_rect.texture = null
			tier_label.text = "ERR"
			self.tooltip_text = "Unknown ID: %s" % instance_data.definition_id
		visible = true
	else:
		visible = false

func _update_stats():
	if not is_instance_valid(instance_data): return
	var definition = instance_data.get_definition()
	if not definition or definition.category != &"UNIT":
		hp_label.visible = false
		pwr_label.visible = false
		return
		
	hp_label.visible = true
	pwr_label.visible = true
	hp_label.text = "HP: %d" % instance_data.current_hp
	pwr_label.text = "PWR: %d" % instance_data.current_pwr

func _on_unit_stats_changed(unit_uuid: String):
	if is_instance_valid(instance_data) and instance_data.ball_uuid == unit_uuid:
		_update_stats()

func set_instance_data(data: GachaBallInstance):
	self.instance_data = data
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
			if event.double_click:
				EventBus.emit_signal("inspection_requested", self)
				InteractionManager.clear_selection()
				get_viewport().set_input_as_handled()
				return

			var selected_view = InteractionManager.get_selected_view()
			if is_instance_valid(selected_view) and selected_view != self:
				EventBus.emit_signal("inventory_action_requested", selected_view, self)
			else:
				InteractionManager.select_view(self)
		else:
			WindowManager.open_grandchild_inspection_window(self)

		get_viewport().set_input_as_handled()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_selectable or not instance_data: return null

	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	
	set_drag_preview(preview)

	var placeholder = Control.new()
	placeholder.custom_minimum_size = self.size
	var parent = get_parent()
	if is_instance_valid(parent):
		parent.add_child(placeholder)
		parent.move_child(placeholder, get_index())

	InteractionManager.start_drag(self, placeholder)
	
	return { "source_view": self }

func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.has("source_view")

func _drop_data(_at_position, data):
	var source_view = data.source_view as GachaBallView
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if InteractionManager.is_drag_active() and InteractionManager.get_drag_source_view() == self:
			InteractionManager.end_drag(false)
```
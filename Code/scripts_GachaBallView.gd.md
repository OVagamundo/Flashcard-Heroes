<!-- Original: scripts/GachaBallView.gd -->

```gdscript
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

# --- Node References ---
@onready var icon_rect: TextureRect = get_node("VBoxContainer/Icon")
@onready var item_grid: GridContainer = get_node("VBoxContainer/ItemGrid")

# --- Data Properties ---
var instance_data: GachaBallInstance = null
var is_interactable: bool = true

# --- Internal State ---
var _is_selected: bool = false
const DRAG_CLICK_MAX_DIST_SQ = 10 * 10 # 10 pixels, squared for efficiency
var _mouse_down_pos: Vector2

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	EventBus.invalid_action_triggered.connect(_on_invalid_action_triggered)
	# Add a default stylebox to visualize the view's frame
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color.DARK_GRAY
	add_theme_stylebox_override("panel", stylebox)

# --- Public Methods ---
func set_instance_data(data: GachaBallInstance):
	self.instance_data = data
	_update_visuals()

func get_instance_data() -> GachaBallInstance:
	return instance_data

func clear_view():
	self.instance_data = null
	_update_visuals()

# --- Input Handling ---
func _gui_input(event: InputEvent):
	if not is_interactable or not instance_data:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_mouse_down_pos = get_global_mouse_position()
			if InteractionManager.get_selected_view() and InteractionManager.get_selected_view() != self:
				EventBus.emit_signal("inventory_action_requested", InteractionManager.get_selected_view(), self)
				get_viewport().set_input_as_handled()
			else:
				InteractionManager.select_view(self)
				get_viewport().set_input_as_handled()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_interactable or not instance_data: return null
	# Only start a drag if the mouse has moved a minimum distance.
	if get_global_mouse_position().distance_squared_to(_mouse_down_pos) <= DRAG_CLICK_MAX_DIST_SQ: return null

	InteractionManager.is_drag_active = true
	var preview = self.duplicate()
	preview.custom_minimum_size = self.size
	set_drag_preview(preview)
	self.visible = false
	return self # The data being dragged is the view itself.
	
func _can_drop_data(_at_position, data) -> bool:
	# This view can receive drops from other views.
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	source_view.visible = true # Make the original visible again.
	InteractionManager.is_drag_active = false
	EventBus.emit_signal("inventory_action_requested", source_view, self)

# --- Visual Updates ---
func _update_visuals():
	if not is_instance_valid(self): return
	
	if instance_data:
		var definition = Database.units.get(instance_data.definition_id, Database.items.get(instance_data.definition_id))
		if definition:
			icon_rect.texture = definition.icon
			# For MVP, we use the ID as the tooltip. In full game, this would use display_name_key.
			self.tooltip_text = str(definition.id)
		else:
			icon_rect.texture = null
			self.tooltip_text = "Unknown ID: %s" % instance_data.definition_id
		visible = true
	else:
		# If no data, the view is empty and should not be visible.
		# A parent placeholder PanelContainer will be visible instead.
		icon_rect.texture = null
		tooltip_text = "Empty Slot"
		visible = false

func _on_view_selected(view: Control):
	if view == self:
		_is_selected = true
		_apply_selection_feedback()

func _on_view_deselected(view: Control):
	if view == self:
		_is_selected = false
		_apply_selection_feedback()

func _on_invalid_action_triggered(view: Control):
	if view == self:
		var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		var original_modulate = self.modulate
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", original_modulate, 0.2)

func _apply_selection_feedback():
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if _is_selected:
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
	else:
		stylebox.border_color = Color.DARK_GRAY
		stylebox.border_width_left = 2
		stylebox.border_width_top = 2
		stylebox.border_width_right = 2
		stylebox.border_width_bottom = 2
	add_theme_stylebox_override("panel", stylebox)

func _notification(what):
	# This ensures that if a drag is cancelled (e.g., by pressing Esc),
	# the original view becomes visible again.
	if what == NOTIFICATION_DRAG_END:
		if InteractionManager.is_drag_active:
			self.visible = true
			InteractionManager.is_drag_active = false

```
<!-- Original: scripts/tests/TestItemView.gd -->

```gdscript
# res://scripts/tests/TestItemView.gd
extends PanelContainer
class_name TestItemView

# This property controls the click behavior, aligning with the TDD.
var is_selectable: bool = true

@onready var name_label: Label = %NameLabel

var _is_selected: bool = false

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	_apply_selection_feedback()

func initialize(item_data: Dictionary):
	set_meta("item_data", item_data)
	name_label.text = item_data.get("name", "N/A")
	self.name = "TestItemView_%s" % item_data.get("id", "ERR")
	if is_node_ready():
		_apply_selection_feedback()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_selectable:
			# Handle double-click for inspection
			if event.double_click:
				EventBus.emit_signal("inspection_requested", self)
				# Clear selection after inspection
				InteractionManager.clear_selection()
			else:
				# Single click just selects
				InteractionManager.select_view(self)
		else:
			# Non-selectable views still use single-click for inspection
			EventBus.emit_signal("inspection_requested", self)

		get_viewport().set_input_as_handled()

func _on_view_selected(view: Control):
	if view == self:
		_is_selected = true
		_apply_selection_feedback()

func _on_view_deselected(view: Control):
	if view == self:
		_is_selected = false
		_apply_selection_feedback()

func _apply_selection_feedback():
	if not is_inside_tree(): return

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

```
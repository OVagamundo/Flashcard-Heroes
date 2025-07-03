<!-- Original: scripts/ItemInspectionWindow.gd -->

```gdscript
# res://scripts/ItemInspectionWindow.gd
class_name ItemInspectionWindow
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel

func _gui_input(event: InputEvent):
	# TDD Rule 3: Hierarchical Closing.
	# This window currently cannot have children, but for consistency and future-proofing,
	# it follows the same pattern as the UnitInspectionWindow.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_window_click(self)
		# Consume the input so it doesn't trigger other actions (like global closing).
		get_viewport().set_input_as_handled()
		return

func populate(context: Dictionary):
	var source_view = context.get("source_view") as GachaBallView
	if not source_view: queue_free(); return

	var item_instance = source_view.get_instance_data()
	if not item_instance: queue_free(); return
	
	var item_definition = Database.items.get(item_instance.definition_id)
	if not item_definition: queue_free(); return
		
	name_label.text = tr(item_definition.display_name_key)
	description_label.text = tr(item_definition.description_key)

```
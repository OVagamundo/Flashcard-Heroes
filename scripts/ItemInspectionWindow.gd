# res://scripts/ItemInspectionWindow.gd
class_name ItemInspectionWindow
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready():
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	# Set mouse filter to pass to detect background clicks
	description_label.mouse_filter = MOUSE_FILTER_PASS
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)


func _gui_input(event: InputEvent):
	# This now handles clicks on the panel's borders/background only.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_window_click(self)
		get_viewport().set_input_as_handled()


func populate(context: Dictionary):
	var window_purpose = context.get("window_purpose", "item")

	if window_purpose == "effect":
		name_label.text = "Effect Details"
		description_label.text = "description of the effect"
		return

	var source_view = context.get("source_view") as GachaBallView
	if not source_view:
		queue_free()
		return

	var item_instance = source_view.get_instance_data()
	if not item_instance:
		queue_free()
		return

	var item_definition = Database.items.get(item_instance.definition_id)
	if not item_definition:
		queue_free()
		return

	name_label.text = item_definition.id
	description_label.text = "description of the items [url=effect]EFFECTS[/url]."
	description_label.set_meta("definition", item_definition)


func _on_description_meta_clicked(meta):
	# This handler's only job is to open the effects window.
	if meta == "effect":
		var definition = description_label.get_meta("definition")
		if definition:
			var context = {"window_purpose": "effect", "parent_definition": definition}
			WindowManager.open_child_inspection_window(self, &"EffectInspection", context)


func _on_description_meta_hover_started(_meta):
	description_label.mouse_filter = MOUSE_FILTER_STOP


func _on_description_meta_hover_ended(_meta):
	description_label.mouse_filter = MOUSE_FILTER_PASS

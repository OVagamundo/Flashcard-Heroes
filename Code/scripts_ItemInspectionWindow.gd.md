<!-- Original: scripts/ItemInspectionWindow.gd -->

```gdscript
class_name ItemInspectionWindow
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

var _source_view: Control
var _instance: GachaBallInstance

func _ready():
	description_label.meta_clicked.connect(_on_description_meta_clicked)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	_source_view = context.get("source_view")
	_instance = context.get("instance")

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		printerr("ItemInspectionWindow: Invalid context provided.")
		queue_free()
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		queue_free()
		return

	name_label.text = tr(item_def.display_name_key)
	var description_text = tr(item_def.description_key)
	description_label.text = "%s\n\n[url=effect]EFFECTS[/url]" % description_text
	
	# Store the full definition for the child window to use.
	description_label.set_meta("effect_definition", item_def)

func _on_description_meta_clicked(meta):
	if meta == "effect":
		var definition = description_label.get_meta("effect_definition")
		if definition:
			var context = {"effect_definition": definition.ability_definitions}
			WindowManager.open_child_inspection_window(self, &"EffectInspection", context)

```
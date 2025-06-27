<!-- Original: scripts/ItemInspectionWindow.gd -->

```gdscript
# res://scripts/ItemInspectionWindow.gd
class_name ItemInspectionWindow
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel

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
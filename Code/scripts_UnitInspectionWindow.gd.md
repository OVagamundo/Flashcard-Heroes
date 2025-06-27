<!-- Original: scripts/UnitInspectionWindow.gd -->

```gdscript
# res://scripts/UnitInspectionWindow.gd
extends PanelContainer
class_name UnitInspectionWindow

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel

func populate(context: Dictionary):
	var source_view = context.get("source_view") as GachaBallView
	if not source_view: queue_free(); return
		
	var unit_instance = source_view.get_instance_data()
	if not unit_instance: queue_free(); return
	
	var unit_definition = Database.units.get(unit_instance.definition_id)
	if not unit_definition: queue_free(); return
		
	name_label.text = tr(unit_definition.display_name_key)
	description_label.text = tr(unit_definition.description_key)
	
	for child in item_grid.get_children():
		child.queue_free()
		
	if unit_definition.item_slot_count == 0:
		item_grid_label.visible = false
		item_grid.visible = false
		return
	else:
		item_grid_label.visible = true
		item_grid.visible = true
		item_grid.columns = unit_definition.item_slot_count

	# In MVP, just show placeholder slots for equipped items.
	for i in range(unit_definition.item_slot_count):
		var placeholder = PanelContainer.new()
		placeholder.custom_minimum_size = Vector2(32, 32)
		var style = StyleBoxFlat.new()
		style.set_bg_color(Color(0,0,0,0.4))
		style.set_border_width_all(1)
		style.set_border_color(Color(0.5, 0.5, 0.5, 0.8))
		placeholder.add_theme_stylebox_override("panel", style)
		item_grid.add_child(placeholder)

```
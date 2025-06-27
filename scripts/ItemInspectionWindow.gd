# res://scripts/ItemInspectionWindow.gd
extends PanelContainer

## Placeholder script for the item inspection window.

func populate_data(context: Dictionary) -> void:
	# This function will be called by the WindowManager.
	# In the future, it will display details about the item.
	var label = Label.new()
	label.text = "Item Inspection Window (Placeholder)"
	add_child(label)
	print("Populating item inspection window with context: ", context)

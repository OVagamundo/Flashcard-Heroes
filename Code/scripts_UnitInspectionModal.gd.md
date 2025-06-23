<!-- Original: scripts/UnitInspectionModal.gd -->

```gdscript
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var unit_view: PanelContainer = %UnitView
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid

var _inventory_context: Dictionary = {}

func _ready():
	# Ensure the modal closes when requested.
	EventBus.close_modal_requested.connect(queue_free)

## Populates the modal with data from a specific unit instance.
func display_unit(unit_instance: GachaBallInstance, inventory_context: Dictionary):
	if not is_instance_valid(unit_instance):
		printerr("UnitInspectionModal: display_unit called with an invalid instance.")
		queue_free()
		return
		
	self._inventory_context = inventory_context
	
	# Clear any previous state
	for child in item_grid.get_children():
		child.queue_free()
	for child in unit_view.get_children():
		child.queue_free()

	# --- Display the main unit ---
	var unit_definition = Database.units.get(unit_instance.definition_id)
	if unit_definition:
		name_label.text = unit_definition.display_name_key # In a real game, this would be tr(key)
		description_label.text = unit_definition.description_key # In a real game, this would be tr(key)
		
		var main_view = GACHA_BALL_VIEW_SCENE.instantiate()
		unit_view.add_child(main_view)
		main_view.set_instance_data(unit_instance)
		# The main unit view in the modal is for display only, not interaction.
		main_view.is_interactable = false
	
	# --- Display equipped items ---
	if unit_instance.equipped_item_uuids.is_empty():
		return

	for item_uuid in unit_instance.equipped_item_uuids:
		if item_uuid.is_empty():
			continue # Skip empty item slots

		var item_instance = _find_instance_by_uuid(item_uuid)
		if item_instance:
			var item_view = GACHA_BALL_VIEW_SCENE.instantiate()
			item_grid.add_child(item_view)
			item_view.set_instance_data(item_instance)
			item_view.is_interactable = false # Items in the modal are not interactable
		else:
			printerr("UnitInspectionModal: Could not find item instance with UUID: ", item_uuid)

## Helper to find a specific GachaBallInstance by its UUID within the provided inventory context.
func _find_instance_by_uuid(uuid: String) -> GachaBallInstance:
	for tier_key in _inventory_context:
		var tier_array = _inventory_context[tier_key]
		for instance in tier_array:
			if instance is GachaBallInstance and instance.ball_uuid == uuid:
				return instance
	return null

```
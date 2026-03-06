class_name DiscardPileWindow
extends Control

@onready var physics_container: PhysicsTierContainer = $DiscardPhysicsContainer

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)

func _on_battle_inventory_changed() -> void:
	if not visible:
		return
	if has_meta("wm_opening") and get_meta("wm_opening"):
		return
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm):
		populate({"inventory": bm.get_discard_pile_inventory()})

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	var instances: Array = context.get("inventory", [])
	var valid_instances: Array = []
	for inst in instances:
		if is_instance_valid(inst):
			valid_instances.append(inst)
	if is_instance_valid(physics_container):
		physics_container.sync_state(valid_instances)

func get_window_to_animate() -> Control:
	return self

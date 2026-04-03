class_name DiscardPileWindow
extends Control

const InputUtils = preload("res://scripts/InputUtils.gd")

@onready var physics_container: PhysicsTierContainer = $DiscardPhysicsContainer

var _cached_instances: Array = []

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	SignalBus.battle_inventory_changed.connect(_on_battle_inventory_changed)
	if InputUtils.prefers_touch_input() and is_instance_valid(physics_container):
		physics_container.use_static_bounds = false
		if physics_container.has_method("refresh_runtime_bounds"):
			physics_container.refresh_runtime_bounds()

func _on_battle_inventory_changed() -> void:
	if not visible:
		return
	if has_meta("wm_opening") and get_meta("wm_opening"):
		return
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm):
		populate({"inventory": bm.get_discard_pile_inventory()})

func _on_gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self )
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()

func populate(context: Dictionary) -> void:
	var instances: Array = context.get("inventory", [])
	_cache_valid_instances(instances)
	refresh_cached_inventory()

func refresh_cached_inventory() -> void:
	if not _can_sync_physics():
		return
	physics_container.sync_state(_cached_instances)

func clear_cached_inventory_visuals() -> void:
	if is_instance_valid(physics_container):
		physics_container.clear()

func on_window_opened() -> void:
	await get_tree().process_frame
	if is_instance_valid(physics_container):
		if physics_container.has_method("refresh_runtime_bounds"):
			physics_container.refresh_runtime_bounds()
		if physics_container.has_method("finish_open"):
			physics_container.finish_open()
	refresh_cached_inventory()
	if is_instance_valid(physics_container):
		physics_container.apply_jolt(Vector2(-500, 0))

func prepare_for_open() -> void:
	if is_instance_valid(physics_container) and physics_container.has_method("prepare_for_open"):
		physics_container.prepare_for_open()

func _cache_valid_instances(instances: Array) -> void:
	_cached_instances.clear()
	for inst in instances:
		if is_instance_valid(inst):
			_cached_instances.append(inst)

func _can_sync_physics() -> bool:
	if not visible:
		return false
	if has_meta("wm_opening") and get_meta("wm_opening"):
		return false
	return is_instance_valid(physics_container)

func get_window_to_animate() -> Control:
	return self

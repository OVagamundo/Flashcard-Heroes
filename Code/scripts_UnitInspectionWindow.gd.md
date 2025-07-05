<!-- Original: scripts/UnitInspectionWindow.gd -->

```gdscript
extends PanelContainer
class_name UnitInspectionWindow

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel

var _inspected_unit_uuid: String # We now track the specific unit instance

func _ready():
	# TDD Compliance: Make this UI component reactive to state changes.
	EventBus.battle_inventory_changed.connect(_on_battle_inventory_changed)

func _exit_tree():
	# TDD Compliance: Clean up connections.
	if EventBus.is_connected("battle_inventory_changed", _on_battle_inventory_changed):
		EventBus.battle_inventory_changed.disconnect(_on_battle_inventory_changed)

func _gui_input(event: InputEvent):
	# TDD Rule 3: Hierarchical Closing.
	# When this window is clicked, it tells the WindowManager.
	# The WindowManager will then close any children of this window.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_window_click(self)
		# Consume the input so it doesn't trigger other actions (like global closing).
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	# Store the UUID of the inspected unit so we can find it again on refresh.
	if context.has("source_view"):
		_inspected_unit_uuid = context.get("source_view").get_instance_data().ball_uuid
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

	# TDD Compliance: Populate with real, non-selectable GachaBallViews.
	var inventory_context = {}
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		inventory_context = {
			"battle_inventory": bm.get_battle_inventory(),
			"lineup_data": bm.lineup_data, "bench_data": bm.bench_data, "item_data": bm.item_data
		}
	else:
		inventory_context = {"run_inventory": GameManager.run_state.run_inventory}

	var equipped_items = MergeManager._get_equipped_item_instances(unit_instance, inventory_context)

	for i in range(unit_definition.item_slot_count):
		var item_instance = equipped_items[i] if i < equipped_items.size() else null

		if is_instance_valid(item_instance):
			var view = GACHA_BALL_VIEW_SCENE.instantiate()
			item_grid.add_child(view)
			view.set_instance_data(item_instance)
			view.custom_minimum_size = Vector2(32, 32)
			# TDD Rule: Items in an inspection window are not selectable, only inspectable.
			view.is_selectable = false
		else:
			# Show a placeholder for empty slots.
			var placeholder = PanelContainer.new()
			placeholder.custom_minimum_size = Vector2(32, 32)
			var style = StyleBoxFlat.new()
			style.set_bg_color(Color(0,0,0,0.4))
			style.set_border_width_all(1)
			style.set_border_color(Color(0.5, 0.5, 0.5, 0.8))
			placeholder.add_theme_stylebox_override("panel", style)
			item_grid.add_child(placeholder)

func _on_battle_inventory_changed():
	# If this window is open when the inventory changes, re-populate to refresh its state.
	if self.visible and not _inspected_unit_uuid.is_empty():
		# Don't use the old context. Find the CURRENT view for our tracked unit.
		var current_view = _find_view_for_uuid(_inspected_unit_uuid)
		if is_instance_valid(current_view):
			populate({"source_view": current_view})
		else:
			# The unit we were inspecting no longer exists (e.g., was merged away). Close the window.
			queue_free()

func _find_view_for_uuid(uuid: String) -> GachaBallView:
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(battle_manager): return null
	
	# Search all active data arrays on the board.
	var all_board_data = battle_manager.lineup_data + battle_manager.bench_data + battle_manager.item_data
	for instance in all_board_data:
		if is_instance_valid(instance) and instance.ball_uuid == uuid and instance.has_meta("view_node"):
			return instance.get_meta("view_node") as GachaBallView
	return null

```
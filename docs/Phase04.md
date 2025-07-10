Phase 4: UI Layer Alignment - Implementation Plan
Objective:
To refactor all UI scenes and scripts into pure "views" that are reactive to state changes. They will emit intent signals using LocationIdentifier and redraw themselves based on global state change signals, fully aligning with the TDD's architectural model.
Step 4.1: Update Core View Components
Instruction: Overwrite GachaBallView.gd and SlotView.gd. These are the most fundamental UI components, and they must be updated to use the new LocationIdentifier system and communicate correctly with InteractionManager and WindowManager.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file modification operations:
Overwrite the file res://scripts/GachaBallView.gd with the following content:
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _location: LocationIdentifier
var _instance_uuid: String
var _is_selected: bool = false
var _is_inspectable: bool = true

func _ready():
    EventBus.view_selected.connect(_on_view_selected)
    EventBus.view_deselected.connect(_on_view_deselected)
    EventBus.invalid_action_triggered.connect(func(v): _on_invalid_action_triggered(v))
    EventBus.unit_stats_changed.connect(_on_unit_stats_changed)

func populate(loc: LocationIdentifier, instance: GachaBallInstance, is_inspectable: bool = true):
    self._location = loc
    self._instance_uuid = instance.ball_uuid
    self._is_inspectable = is_inspectable
    set_meta("location_identifier", loc) # For InteractionManager and WindowManager

    var definition = instance.get_definition()
    if not is_instance_valid(definition):
        visible = false
        return
    
    visible = true
    icon_rect.texture = definition.icon
    tier_label.text = "T%d" % definition.tier
    tooltip_text = tr(definition.display_name_key)
    
    # Update stats and item slots
    _update_stats(instance)
    _update_item_slots(instance)
    _apply_selection_feedback()

func set_is_enemy(is_enemy: bool):
    if is_instance_valid(icon_rect):
        icon_rect.flip_h = is_enemy

func _update_stats(instance: GachaBallInstance):
    if not is_instance_valid(instance): return
    var definition = instance.get_definition()
    if not definition or definition.category != &"UNIT":
        hp_label.visible = false
        pwr_label.visible = false
        return
    
    hp_label.visible = true
    pwr_label.visible = true
    hp_label.text = "HP: %d" % instance.current_hp
    pwr_label.text = "PWR: %d" % instance.current_pwr

func _update_item_slots(instance: GachaBallInstance):
    for child in item_grid.get_children():
        child.queue_free()
    
    var all_instances = _get_all_instances_db()
    if all_instances.is_empty(): return
        
    for item_uuid in instance.equipped_item_uuids:
        var slot_panel = Panel.new()
        slot_panel.custom_minimum_size = Vector2(12, 12)
        if not item_uuid.is_empty() and all_instances.has(item_uuid):
            var item_instance = all_instances[item_uuid]
            var item_def = item_instance.get_definition()
            if is_instance_valid(item_def):
                var icon = TextureRect.new()
                icon.texture = item_def.icon
                icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                slot_panel.add_child(icon)
                icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        item_grid.add_child(slot_panel)

func _on_unit_stats_changed(unit_uuid: String):
    if _instance_uuid == unit_uuid:
        var instance = _get_instance_by_uuid(unit_uuid)
        if is_instance_valid(instance):
            _update_stats(instance)

func _gui_input(event: InputEvent):
    if not is_instance_valid(_location): return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        get_viewport().set_input_as_handled()
        
        if _is_inspectable:
            if event.double_click:
                WindowManager.open_inspection_window(self)
                InteractionManager.clear_selection()
                return

            var selected_loc = InteractionManager.get_selected_location()
            if is_instance_valid(selected_loc) and selected_loc != _location:
                EventBus.emit_signal("inventory_action_requested", selected_loc, _location)
            else:
                InteractionManager.select_view(self, _location)
        else: # Not inspectable, but might be part of another window
            WindowManager.open_inspection_window(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
    if not _is_inspectable or not is_instance_valid(_location): return null

    var preview = TextureRect.new()
    preview.texture = icon_rect.texture
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.custom_minimum_size = Vector2(64, 64)
    set_drag_preview(preview)

    var placeholder = Control.new()
    placeholder.custom_minimum_size = self.size
    get_parent().add_child(placeholder)
    get_parent().move_child(placeholder, get_index())

    InteractionManager.start_drag(self, placeholder)
    return { "source_loc": _location }

func _can_drop_data(_at_position, data) -> bool:
    return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
    EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)

func _on_view_selected(view: Control, _loc: LocationIdentifier):
    if view == self:
        _is_selected = true
        _apply_selection_feedback()

func _on_view_deselected(view: Control):
    if view == self:
        _is_selected = false
        _apply_selection_feedback()

func _on_invalid_action_triggered(view: Control):
    if view == self and animation_player.has_animation("shake"):
        animation_player.play("shake")

func _apply_selection_feedback():
    if not is_inside_tree(): return
    var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
    if _is_selected:
        stylebox.border_color = Color.GOLD
        stylebox.border_width_left = 3
        stylebox.border_width_top = 3
        stylebox.border_width_right = 3
        stylebox.border_width_bottom = 3
    else:
        stylebox.border_width_left = 0
        stylebox.border_width_top = 0
        stylebox.border_width_right = 0
        stylebox.border_width_bottom = 0
    add_theme_stylebox_override("panel", stylebox)

func _notification(what: int):
    if what == NOTIFICATION_DRAG_END:
        if InteractionManager.is_drag_active() and InteractionManager.get_drag_source_view() == self:
            InteractionManager.end_drag(false)

func _get_all_instances_db() -> Dictionary:
    if GameManager.is_in_battle:
        var bm = get_tree().get_first_node_in_group("battle_manager")
        return bm.get_all_instances() if is_instance_valid(bm) else {}
    else:
        return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _get_instance_by_uuid(uuid: String) -> GachaBallInstance:
    var db = _get_all_instances_db()
    return db.get(uuid)

Overwrite the file res://scripts/SlotView.gd with the following content:
# res://scripts/SlotView.gd
class_name SlotView
extends PanelContainer

var _location: LocationIdentifier

func _ready():
    var style = StyleBoxFlat.new()
    style.set_bg_color(Color(0,0,0,0.2))
    style.set_border_width_all(1)
    style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
    add_theme_stylebox_override("panel", style)

func populate(loc: LocationIdentifier):
    self._location = loc
    set_meta("location_identifier", loc) # For drop data

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        get_viewport().set_input_as_handled()
        var selected_loc = InteractionManager.get_selected_location()
        if is_instance_valid(selected_loc):
            EventBus.emit_signal("inventory_action_requested", selected_loc, _location)
        else:
            EventBus.emit_signal("global_background_clicked")

func _can_drop_data(_at_position, data) -> bool:
    return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
    EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)

</details>
Step 4.2: Update All Modal Windows
Instruction: Overwrite the scripts for InventoryWindow, DiscardPileWindow, and ChoiceWindow. They will now be populated by WindowManager and fetch their own data based on the game's context (is_in_battle).
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file modification operations:
Overwrite the file res://scripts/InventoryWindow.gd with the following content:
# res://scripts/InventoryWindow.gd
class_name InventoryWindow
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")

@onready var panel_container: PanelContainer = %PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var tier_1_grid: GridContainer = %Tier1Grid
@onready var tier_2_grid: GridContainer = %Tier2Grid
@onready var tier_3_grid: GridContainer = %Tier3Grid

var _is_battle_context: bool = false

func _ready():
    panel_container.gui_input.connect(_on_panel_gui_input)

func _exit_tree():
    EventBus.run_state_changed.disconnect(_redraw)
    EventBus.battle_inventory_changed.disconnect(_redraw)

func populate(context: Dictionary):
    _is_battle_context = context.get("is_battle_context", false)
    if _is_battle_context:
        title_label.text = "Battle Inventory"
        EventBus.battle_inventory_changed.connect(_redraw)
    else:
        title_label.text = "Run Inventory"
        EventBus.run_state_changed.connect(_redraw)
    _redraw()

func _on_panel_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        if InteractionManager.is_drag_active():
            InteractionManager.cancel_active_drag()
        else:
            WindowManager.close_all_inspection_windows()
        get_viewport().set_input_as_handled()

func _redraw():
    if not is_inside_tree(): return
    
    var data_owner = get_tree().get_first_node_in_group("battle_manager") if _is_battle_context else GameManager.run_state
    if not is_instance_valid(data_owner): return
        
    var all_instances = data_owner.get_all_instances() if _is_battle_context else data_owner.run_instances
    var grids = {
        1: { "grid_node": tier_1_grid, "container_name": &"BattleInventoryT1" if _is_battle_context else &"RunInventoryT1" },
        2: { "grid_node": tier_2_grid, "container_name": &"BattleInventoryT2" if _is_battle_context else &"RunInventoryT2" },
        3: { "grid_node": tier_3_grid, "container_name": &"BattleInventoryT3" if _is_battle_context else &"RunInventoryT3" },
    }

    for tier in grids:
        var grid_info = grids[tier]
        var grid_node = grid_info.grid_node
        var container_name = grid_info.container_name
        
        for child in grid_node.get_children():
            child.queue_free()

        var container = data_owner.get_container(container_name) if _is_battle_context else data_owner.run_inventory_containers[container_name]
        if not is_instance_valid(container): continue
        
        var uuids = container.get_all_uuids()
        for i in range(uuids.size()):
            var uuid = uuids[i]
            var loc = LocationIdentifier.new()
            loc.container = container_name
            loc.index = i
            loc.tier = tier
            
            if not uuid.is_empty() and all_instances.has(uuid):
                var instance = all_instances[uuid]
                var view = GACHA_BALL_VIEW_SCENE.instantiate()
                grid_node.add_child(view)
                view.populate(loc, instance)
            else:
                var slot_view = SLOT_VIEW_SCENE.instantiate()
                grid_node.add_child(slot_view)
                slot_view.populate(loc)

Overwrite the file res://scripts/DiscardPileWindow.gd with the following content:
# res://scripts/DiscardPileWindow.gd
class_name DiscardPileWindow
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

func _ready():
    panel_container.gui_input.connect(_on_panel_gui_input)
    EventBus.battle_inventory_changed.connect(_redraw)

func _exit_tree():
    EventBus.battle_inventory_changed.disconnect(_redraw)

func populate(_context: Dictionary):
    _redraw()

func _on_panel_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        WindowManager.close_all_inspection_windows()
        get_viewport().set_input_as_handled()

func _redraw():
    if not is_inside_tree(): return
    
    for child in discard_grid.get_children():
        child.queue_free()
        
    var bm = get_tree().get_first_node_in_group("battle_manager")
    if not is_instance_valid(bm): return

    var container = bm.get_container(&"DiscardPile")
    var all_instances = bm.get_all_instances()
    var uuids = container.get_all_uuids()
    
    for i in range(uuids.size()):
        var uuid = uuids[i]
        if not uuid.is_empty() and all_instances.has(uuid):
            var instance = all_instances[uuid]
            var loc = LocationIdentifier.new()
            loc.container = &"DiscardPile"
            loc.index = i
            
            var view = GACHA_BALL_VIEW_SCENE.instantiate()
            discard_grid.add_child(view)
            view.populate(loc, instance, false) # Items in discard are not interactable

Overwrite the file res://scripts/ChoiceWindow.gd with the following content:
# res://scripts/ChoiceWindow.gd
class_name ChoiceWindow
extends Control

@onready var merge_button: Button = %MergeButton
@onready var swap_button: Button = %SwapButton

func _ready():
    merge_button.pressed.connect(func(): _on_choice_made(&"MERGE"))
    swap_button.pressed.connect(func(): _on_choice_made(&"SWAP"))

func populate(_context: Dictionary):
    # This window doesn't need context to populate, it's static.
    pass

func _on_choice_made(choice: StringName):
    EventBus.emit_signal("choice_made", choice)
    EventBus.emit_signal("close_modal_requested")

</details>
Step 4.3: Update All Inspection Windows
Instruction: Overwrite UnitInspectionWindow.gd and ItemInspectionWindow.gd. They will now use the "Dynamic Mouse Filter" pattern for clickable links and be populated with a source_view context from WindowManager.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file modification operations:
Overwrite the file res://scripts/UnitInspectionWindow.gd with the following content:
# res://scripts/UnitInspectionWindow.gd
extends PanelContainer
class_name UnitInspectionWindow

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_grid_label: Label = %ItemGridLabel

var _inspected_view: WeakRef

func _ready():
    description_label.meta_clicked.connect(_on_meta_clicked)
    description_label.meta_hover_started.connect(func(_meta): mouse_filter = MOUSE_FILTER_STOP)
    description_label.meta_hover_ended.connect(func(_meta): mouse_filter = MOUSE_FILTER_PASS)
    EventBus.battle_inventory_changed.connect(_redraw_if_visible)
    EventBus.run_state_changed.connect(_redraw_if_visible)

func _exit_tree():
    EventBus.battle_inventory_changed.disconnect(_redraw_if_visible)
    EventBus.run_state_changed.disconnect(_redraw_if_visible)

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        WindowManager.handle_inspection_background_click(self)
        get_viewport().set_input_as_handled()

func populate(context: Dictionary):
    var source_view = context.get("source_view")
    if not is_instance_valid(source_view):
        queue_free()
        return

    _inspected_view = weakref(source_view)
    _redraw()

func _redraw_if_visible():
    if self.visible:
        _redraw()

func _redraw():
    var source_view = _inspected_view.get_ref() if _inspected_view else null
    if not is_instance_valid(source_view):
        queue_free()
        return
        
    var loc = source_view.get_meta("location_identifier")
    var data_owner = get_tree().get_first_node_in_group("battle_manager") if GameManager.is_in_battle else GameManager.run_state
    var all_instances = data_owner.get_all_instances() if GameManager.is_in_battle else data_owner.run_instances
    var container = data_owner.get_container(loc.container) if GameManager.is_in_battle else data_owner.run_inventory_containers[loc.container]
    var uuid = container.get_uuid(loc.index)
    var unit_instance = all_instances.get(uuid)
    
    if not is_instance_valid(unit_instance):
        queue_free() # The instance this window was inspecting is gone.
        return

    var unit_def = unit_instance.get_definition()
    name_label.text = tr(unit_def.display_name_key)
    description_label.text = tr(unit_def.description_key).format({"pwr": unit_instance.current_pwr})

    for child in item_grid.get_children():
        child.queue_free()

    if unit_def.item_slot_count == 0:
        item_grid.visible = false
        item_grid_label.visible = false
        return
    else:
        item_grid.visible = true
        item_grid_label.visible = true
        item_grid.columns = unit_def.item_slot_count

    for i in range(unit_def.item_slot_count):
        var item_uuid = unit_instance.equipped_item_uuids[i] if i < unit_instance.equipped_item_uuids.size() else ""
        if not item_uuid.is_empty() and all_instances.has(item_uuid):
            var item_instance = all_instances[item_uuid]
            var view = GACHA_BALL_VIEW_SCENE.instantiate()
            # Dummy location for inspection purposes
            var dummy_loc = LocationIdentifier.new()
            dummy_loc.container = &"Equipped"
            dummy_loc.index = i
            view.populate(dummy_loc, item_instance, true)
            view.custom_minimum_size = Vector2(40, 40)
            item_grid.add_child(view)
        else:
            var placeholder = SLOT_VIEW_SCENE.instantiate()
            placeholder.custom_minimum_size = Vector2(40, 40)
            item_grid.add_child(placeholder)

func _on_meta_clicked(meta):
    # Placeholder for future clickable effects
    print("Clicked on meta: ", meta)

Overwrite the file res://scripts/ItemInspectionWindow.gd with the following content:
# res://scripts/ItemInspectionWindow.gd
class_name ItemInspectionWindow
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready():
    description_label.meta_clicked.connect(func(meta): print("Clicked meta: ", meta))
    description_label.meta_hover_started.connect(func(_meta): mouse_filter = MOUSE_FILTER_STOP)
    description_label.meta_hover_ended.connect(func(_meta): mouse_filter = MOUSE_FILTER_PASS)

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        WindowManager.handle_inspection_background_click(self)
        get_viewport().set_input_as_handled()

func populate(context: Dictionary):
    var source_view = context.get("source_view")
    if not is_instance_valid(source_view):
        queue_free()
        return
        
    var loc = source_view.get_meta("location_identifier")
    var data_owner = get_tree().get_first_node_in_group("battle_manager") if GameManager.is_in_battle else GameManager.run_state
    var all_instances = data_owner.get_all_instances() if GameManager.is_in_battle else data_owner.run_instances
    var container = data_owner.get_container(loc.container) if GameManager.is_in_battle else data_owner.run_inventory_containers[loc.container]
    var uuid = container.get_uuid(loc.index)
    var item_instance = all_instances.get(uuid)

    if not is_instance_valid(item_instance):
        queue_free()
        return

    var item_def = item_instance.get_definition()
    name_label.text = tr(item_def.display_name_key)
    description_label.text = tr(item_def.description_key)

</details>
Step 4.4: Update Battle UI
Instruction: Overwrite Battle.tscn to remove the old data arrays and connect UI elements to the new BattleManager signals. We also need a BackgroundClickDetector for deselection.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file creation and modification operations:
Create the file res://scripts/BackgroundClickDetector.gd with the following content:
# res://scripts/BackgroundClickDetector.gd
extends ColorRect

# This control sits at the back of a scene. If a click reaches it,
# it means the user clicked on the "empty" background area.
func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        # Emit a clear, global signal indicating the user's intent.
        EventBus.emit_signal("global_background_clicked")
        # Consume the input to prevent any further processing.
        get_viewport().set_input_as_handled()

Overwrite the file res://scenes/Battle.tscn with the following content:
[gd_scene load_steps=3 format=3 uid="uid://uiilu4273ttr"]

[ext_resource type="Script" path="res://scripts/Battle.gd" id="1_battle_script"]
[ext_resource type="Script" path="res://scripts/BackgroundClickDetector.gd" id="2_detector_script"]

[node name="Battle" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_battle_script")

[node name="BackgroundClickDetector" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.1, 1)
script = ExtResource("2_detector_script")

[node name="TeamAreas" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
alignment = 1

[node name="PlayerArea" type="VBoxContainer" parent="TeamAreas"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="Control" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="PlayerLineup" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot5" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="Control2" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="BenchAndInventory" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="PlayerBench" type="HBoxContainer" parent="TeamAreas/PlayerArea/BenchAndInventory"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="BenchSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="BenchSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="BenchSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemInventory" type="HBoxContainer" parent="TeamAreas/PlayerArea/BenchAndInventory"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="ItemIventorySlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemIventorySlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemIventorySlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="Control3" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="Spacer" type="Control" parent="TeamAreas"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="EnemyArea" type="VBoxContainer" parent="TeamAreas"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="Control" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="EnemyLineup" type="HBoxContainer" parent="TeamAreas/EnemyArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot5" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="Control2" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="DiscardArea" type="HBoxContainer" parent="TeamAreas/EnemyArea"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="DiscardPileButton" type="Button" parent="TeamAreas/EnemyArea/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 1
text = "Discard Pile (0)"

[node name="EndTurnButton" type="Button" parent="TeamAreas/EnemyArea/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
text = "End Turn"

[node name="GachaTokenLabel" type="Label" parent="TeamAreas/EnemyArea/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
text = "Tokens: 0"

[node name="Control3" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="ModalLayer" type="CanvasLayer" parent="."]
unique_name_in_owner = true
layer = 128

Overwrite the file res://scripts/Battle.gd with the following content (This is the corrected version):
# res://scripts/Battle.gd
extends Control

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")

@onready var lineup_container: HBoxContainer = %PlayerLineup
@onready var bench_container: HBoxContainer = %PlayerBench
@onready var item_container: HBoxContainer = %ItemInventory
@onready var enemy_lineup_container: HBoxContainer = %EnemyLineup
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var gacha_token_label: Label = %GachaTokenLabel
@onready var end_turn_button: Button = %EndTurnButton

var _battle_manager: BattleManager

func _ready():
    # The Battle scene now creates its own manager instance.
    _battle_manager = BattleManager.new()
    # CORRECTION: Add the manager as a direct child of the Battle scene root.
    add_child(_battle_manager)
    
    EventBus.battle_inventory_changed.connect(_redraw_board)
    EventBus.gacha_tokens_changed.connect(_update_gacha_token_label)
    EventBus.battle_phase_changed.connect(_on_battle_phase_changed)
    
    _redraw_board()
    # Initial label update since the signal might fire before this node is ready
    _update_gacha_token_label(_battle_manager._gacha_tokens)

func _exit_tree():
    EventBus.battle_inventory_changed.disconnect(_redraw_board)
    EventBus.gacha_tokens_changed.disconnect(_update_gacha_token_label)
    EventBus.battle_phase_changed.disconnect(_on_battle_phase_changed)

func _redraw_board():
    if not is_instance_valid(_battle_manager): return
    
    _populate_container(lineup_container, &"PlayerLineup", true)
    _populate_container(bench_container, &"PlayerBench", true)
    _populate_container(item_container, &"ItemInventory", true)
    _populate_container(enemy_lineup_container, &"EnemyLineup", false)
    
    var discard_container = _battle_manager.get_container(&"DiscardPile")
    var discard_count = discard_container.get_all_non_empty_uuids().size()
    discard_pile_button.text = "Discard Pile (%d)" % discard_count

func _populate_container(container_node: HBoxContainer, container_name: StringName, is_player_team: bool):
    var all_slots = container_node.get_children()
    var container_data = _battle_manager.get_container(container_name)
    var all_instances = _battle_manager.get_all_instances()
    
    if not is_instance_valid(container_data): return

    var uuids = container_data.get_all_uuids()
    for i in range(all_slots.size()):
        var slot_node = all_slots[i]
        var uuid = uuids[i] if i < uuids.size() else ""
        
        for child in slot_node.get_children():
            child.queue_free()

        var loc = LocationIdentifier.new()
        loc.container = container_name
        loc.index = i
        
        if not uuid.is_empty() and all_instances.has(uuid):
            var instance = all_instances[uuid]
            var view = GACHA_BALL_VIEW_SCENE.instantiate()
            slot_node.add_child(view)
            view.populate(loc, instance)
            if not is_player_team:
                view.set_is_enemy(true)
        elif is_player_team: # Only player side has empty, interactable slots
            var slot_view = SLOT_VIEW_SCENE.instantiate()
            slot_node.add_child(slot_view)
            slot_view.populate(loc)

func _update_gacha_token_label(new_amount: int):
    gacha_token_label.text = "Tokens: %d" % new_amount

func _on_battle_phase_changed(phase_name: StringName):
    end_turn_button.disabled = (phase_name != &"MANAGEMENT")

</details>
Step 4.5: Finalize Scene Transitions and Main UI
Instruction: Update Main.gd, Title.gd, and SceneManager.gd to use the new signals and ensure the game flow from title screen to battle is correct.
<details>
<summary>Prompt for AI Code Editor</summary>
PROMPT:
Please perform the following file modification operations:
Overwrite the file res://scripts/Main.gd with the following content:
# res://scripts/Main.gd
extends Control

@onready var content_area: SubViewportContainer = %ContentArea
@onready var inspect_inventory_button: Button = %InspectInventoryButton
@onready var draw_tier1_button: Button = %DrawTier1Button
@onready var draw_tier2_button: Button = %DrawTier2Button
@onready var draw_tier3_button: Button = %DrawTier3Button

const PATH_CHOICE_SCENE = preload("res://scenes/PathChoice.tscn")
const BATTLE_SCENE = preload("res://scenes/Battle.tscn")

var _current_content_node: Node = null

func _ready():
    inspect_inventory_button.pressed.connect(EventBus.inspect_inventory_requested.emit)
    draw_tier1_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 1))
    draw_tier2_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 2))
    draw_tier3_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 3))
    
    EventBus.battle_start_requested.connect(_on_battle_start_requested)
    EventBus.battle_state_changed.connect(_on_battle_state_changed)
    
    _on_battle_state_changed(GameManager.is_in_battle)
    if not GameManager.is_in_battle:
        _load_content(PATH_CHOICE_SCENE)

func _clear_content_area():
    if is_instance_valid(_current_content_node):
        _current_content_node.queue_free()
    _current_content_node = null

func _load_content(scene_resource: PackedScene):
    _clear_content_area()
    var instance = scene_resource.instantiate()
    _current_content_node = instance
    content_area.get_node("SubViewport").add_child(instance)

func _on_battle_start_requested():
    _load_content(BATTLE_SCENE)

func _on_battle_state_changed(is_in_battle: bool):
    draw_tier1_button.visible = is_in_battle
    draw_tier2_button.visible = is_in_battle
    draw_tier3_button.visible = is_in_battle

Overwrite the file res://scripts/Title.gd with the following content:
# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton
@onready var inspection_test_button: Button = %InspectionTestButton

func _ready():
    start_run_button.pressed.connect(EventBus.start_run_requested.emit)
    inspection_test_button.pressed.connect(EventBus.inspection_test_scene_requested.emit)

Overwrite the file res://scripts/SceneManager.gd with the following content:
# res://scripts/SceneManager.gd
extends Node

var scene_paths: Dictionary = {
    "Title": "res://scenes/Title.tscn",
    "Loadout": "res://scenes/Loadout.tscn",
    "Main": "res://scenes/Main.tscn",
    "TestInspectionSystem": "res://scenes/tests/TestInspectionSystem.tscn"
}
var current_scene: Node = null

func _ready() -> void:
    EventBus.loadout_scene_requested.connect(func(): _change_scene_to(scene_paths["Loadout"]))
    EventBus.main_scene_requested.connect(func(): _change_scene_to(scene_paths["Main"]))
    EventBus.inspection_test_scene_requested.connect(func(): _change_scene_to(scene_paths["TestInspectionSystem"]))
    EventBus.title_scene_requested.connect(func(): _change_scene_to(scene_paths["Title"]))
    
    var root = get_tree().root
    current_scene = root.get_child(root.get_child_count() - 1)

func _change_scene_to(path: String) -> void:
    if is_instance_valid(current_scene):
        current_scene.queue_free()
        
    var new_scene_res = load(path)
    if not new_scene_res:
        printerr("SceneManager: Failed to load scene at path: ", path)
        return
        
    current_scene = new_scene_res.instantiate()
    get_tree().root.add_child(current_scene)

</details>
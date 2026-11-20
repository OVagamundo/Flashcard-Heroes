# res://scripts/ui/EncounterDropZoneBar.gd
class_name EncounterDropZoneBar
extends RefCounted

## Manages the three bottom-bar encounter drop-zone overlays in Main:
## 1. ConfirmDropZone (Shop / Rewards single confirm)
## 2. SplitActionDropZones + ActionInstructionOverlay (Shrine / UnitTrainingGround)
## 3. RewardDropZones (Collect / Sell split)

const InputUtils = preload("res://scripts/InputUtils.gd")
const DropZoneScript = preload("res://scripts/utils/DropZone.gd")

enum ActionZoneCategoryFilter {
	ALL,
	UNITS_ONLY
}

var _confirm_drop_zone: PanelContainer = null
var _confirm_drop_zone_label: RichTextLabel = null
var _confirm_drop_zone_mode: StringName = &""
var _confirm_drop_zone_visible: bool = false
var _drop_zone_drag_context: InteractionContext = null

var _split_action_drop_zone_container: PanelContainer = null
var _action_zone_2: PanelContainer = null
var _action_zone_1: PanelContainer = null
var _action_label_2: RichTextLabel = null
var _action_label_1: RichTextLabel = null
var _split_action_drop_zones_visible: bool = false

var _reward_drop_zone_container: PanelContainer = null
var _reward_collect_zone: PanelContainer = null
var _reward_sell_zone: PanelContainer = null
var _reward_collect_label: RichTextLabel = null
var _reward_sell_label: RichTextLabel = null
var _reward_drop_zones_visible: bool = false

var _action_drop_zone_drag_context: InteractionContext = null
var _action_instruction_overlay: PanelContainer = null
var _action_instruction_label: Label = null
var _action_instruction_visible: bool = false

var _action_zone_1_text: String = ""
var _action_zone_2_text: String = ""
var _action_zone_category_filter: ActionZoneCategoryFilter = ActionZoneCategoryFilter.ALL


func build_all(main: Control) -> void:
	_build_confirm_drop_zone(main)
	_build_split_action_drop_zones(main)
	_build_reward_drop_zones(main)


func _build_confirm_drop_zone(main: Control) -> void:
	var bottom_area: Control = main.bottom_area
	_confirm_drop_zone = PanelContainer.new()
	_confirm_drop_zone.name = "ConfirmDropZone"
	_confirm_drop_zone.unique_name_in_owner = true
	_confirm_drop_zone.layout_mode = 1
	_confirm_drop_zone.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_confirm_drop_zone.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_confirm_drop_zone.offset_top = -bottom_area.size.y
	_confirm_drop_zone.offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.93, 0.95)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	_confirm_drop_zone.add_theme_stylebox_override("panel", style)
	_confirm_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_drop_zone.add_child(center)

	_confirm_drop_zone_label = RichTextLabel.new()
	_confirm_drop_zone_label.bbcode_enabled = true
	_confirm_drop_zone_label.fit_content = true
	_confirm_drop_zone_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_confirm_drop_zone_label.custom_minimum_size = Vector2(800, 0)
	_confirm_drop_zone_label.add_theme_color_override("default_color", Color(0.35, 0.35, 0.32, 0.85))
	_confirm_drop_zone_label.add_theme_color_override("font_outline_color", Color(0.15, 0.17, 0.22, 0.3))
	_confirm_drop_zone_label.add_theme_constant_override("outline_size", 2)
	_confirm_drop_zone_label.add_theme_font_size_override("normal_font_size", 42)
	_confirm_drop_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_confirm_drop_zone_label)

	var hud_container: Node = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_confirm_drop_zone)
		_confirm_drop_zone.z_index = 5

	_confirm_drop_zone.gui_input.connect(func(event: InputEvent) -> void: _on_confirm_drop_zone_gui_input(main, event))
	_confirm_drop_zone.set_script(DropZoneScript)
	_confirm_drop_zone.visible = false
	_confirm_drop_zone.modulate.a = 0.0


func show_confirm_drop_zone(main: Control, mode: StringName) -> void:
	if not is_instance_valid(_confirm_drop_zone):
		return
	_confirm_drop_zone_mode = mode
	if mode == &"Rewards":
		_confirm_drop_zone_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_get_multi") + "[/center]"
	elif mode == &"Shop":
		_confirm_drop_zone_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_buy_multi") + "[/center]"
	else:
		_confirm_drop_zone_label.text = "[center]" + TranslationServer.translate("ui.confirm") + "[/center]"

	if _confirm_drop_zone_visible:
		return
	_confirm_drop_zone_visible = true
	_confirm_drop_zone.visible = true
	var tween: Tween = main.create_tween()
	tween.tween_property(_confirm_drop_zone, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_confirm_drop_zone(main: Control) -> void:
	if not is_instance_valid(_confirm_drop_zone) or not _confirm_drop_zone_visible:
		return
	_confirm_drop_zone_visible = false
	_confirm_drop_zone_mode = &""
	var tween: Tween = main.create_tween()
	tween.tween_property(_confirm_drop_zone, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_confirm_drop_zone):
			_confirm_drop_zone.visible = false
	)


func _on_confirm_drop_zone_gui_input(main: Control, event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		if _drop_zone_drag_context != null:
			return
		if _confirm_drop_zone_mode != &"":
			SignalBus.emit_signal("confirm_drop_zone_activated", false, Vector2.ZERO)
			Audio.play_sfx("ui_click")
		main.get_viewport().set_input_as_handled()


func on_selection_changed(main: Control, new_location: LocationIdentifier) -> void:
	if new_location and new_location.container == &"Rewards":
		show_reward_drop_zones(main)
		_instant_hide_instruction()
	elif new_location and new_location.container == &"Shop":
		show_confirm_drop_zone(main, &"Shop")
	else:
		main.call_deferred("_deferred_maybe_hide_drop_zone")

	if _action_instruction_visible or _split_action_drop_zones_visible:
		var is_inventory_source: bool = new_location != null and String(new_location.container).begins_with("RunInventoryT")
		var is_valid_for_training: bool = _is_valid_category_for_action_zones(new_location)
		if is_inventory_source and is_valid_for_training and not MergeManager.is_merge_encounter_active():
			show_split_action_drop_zones(main)
			_instant_hide_instruction()
		else:
			main.call_deferred("_deferred_maybe_hide_action_drop_zones")


func deferred_maybe_hide_drop_zone(main: Control) -> void:
	if _confirm_drop_zone_mode == &"" and not _reward_drop_zones_visible:
		return
	var sel: InteractionContext = GlobalInteractionRouter.get_current_selection()
	if sel and is_instance_valid(sel.location) and sel.location.container == &"Shop":
		return
	hide_confirm_drop_zone(main)
	if not (sel and is_instance_valid(sel.location) and sel.location.container == &"Rewards"):
		hide_reward_drop_zones(main)
		_restore_reward_instruction_if_active(main)


func deferred_maybe_hide_action_drop_zones(main: Control) -> void:
	if not _split_action_drop_zones_visible:
		return
	var sel: InteractionContext = GlobalInteractionRouter.get_current_selection()
	if sel and is_instance_valid(sel.location) and String(sel.location.container).begins_with("RunInventoryT"):
		var sel_type: StringName = _resolve_entity_category(sel.entity_type, sel.location)
		if not (_action_zone_category_filter == ActionZoneCategoryFilter.UNITS_ONLY and sel_type != &"UNIT"):
			return
	if _action_drop_zone_drag_context != null:
		return
	hide_split_action_drop_zones(main)
	show_action_instruction(main)


func on_drag_started(main: Control, origin_context: InteractionContext) -> void:
	_drop_zone_drag_context = null
	_action_drop_zone_drag_context = null
	if origin_context == null or not is_instance_valid(origin_context.location):
		return
	if origin_context.location.container == &"Rewards":
		_drop_zone_drag_context = origin_context
		show_reward_drop_zones(main)
		_instant_hide_instruction()
	elif origin_context.location.container == &"Shop":
		_drop_zone_drag_context = origin_context
		show_confirm_drop_zone(main, &"Shop")
	elif (_action_instruction_visible or _split_action_drop_zones_visible) and String(origin_context.location.container).begins_with("RunInventoryT") and not MergeManager.is_merge_encounter_active():
		if _action_zone_category_filter == ActionZoneCategoryFilter.UNITS_ONLY and origin_context.entity_type != &"UNIT":
			return
		_action_drop_zone_drag_context = origin_context
		show_split_action_drop_zones(main)
		_instant_hide_instruction()


func on_drag_ended(main: Control) -> void:
	var saved_ctx: InteractionContext = _drop_zone_drag_context
	var saved_action_ctx: InteractionContext = _action_drop_zone_drag_context
	_drop_zone_drag_context = null
	_action_drop_zone_drag_context = null

	if _check_action_drag_drop_on_zones_with_context(main, saved_action_ctx):
		return
	if _check_reward_drag_drop_on_zones_with_context(main, saved_ctx):
		return
	if _confirm_drop_zone_mode == &"":
		return

	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		var pointer_pos: Vector2 = _get_pointer_pos(main)
		if _confirm_drop_zone.get_global_rect().has_point(pointer_pos) and saved_ctx != null:
			GlobalInteractionRouter.set_current_selection(saved_ctx)
			SignalBus.emit_signal("selection_changed", saved_ctx.location)
			SignalBus.emit_signal("confirm_drop_zone_activated", true, pointer_pos)
			Audio.play_sfx("ui_click")
			return

	hide_confirm_drop_zone(main)
	var sel: InteractionContext = GlobalInteractionRouter.get_current_selection()
	if not (sel and is_instance_valid(sel.location) and sel.location.container == &"Rewards"):
		hide_reward_drop_zones(main)
		_restore_reward_instruction_if_active(main)


func get_confirm_drop_zone_rect() -> Rect2:
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		return _confirm_drop_zone.get_global_rect()
	return Rect2()


func is_point_inside_active_drop_zone(pos: Vector2) -> bool:
	if is_instance_valid(_confirm_drop_zone) and _confirm_drop_zone.visible:
		if _confirm_drop_zone.get_global_rect().has_point(pos):
			return true
	if _reward_drop_zones_visible:
		if is_instance_valid(_reward_collect_zone) and _reward_collect_zone.get_global_rect().has_point(pos):
			return true
		if is_instance_valid(_reward_sell_zone) and _reward_sell_zone.get_global_rect().has_point(pos):
			return true
	if _split_action_drop_zones_visible:
		if is_instance_valid(_action_zone_1) and _action_zone_1.get_global_rect().has_point(pos):
			return true
		if is_instance_valid(_action_zone_2) and _action_zone_2.get_global_rect().has_point(pos):
			return true
	return false


func _build_split_action_drop_zones(main: Control) -> void:
	var bottom_area: Control = main.bottom_area
	_split_action_drop_zone_container = _create_split_zone_shell("ShrineDropZones", bottom_area)
	var hbox: HBoxContainer = _split_action_drop_zone_container.get_child(0) as HBoxContainer

	_action_zone_1 = _create_action_zone_panel(TranslationServer.translate("ui.drop_zone_transform_multi"), Color(0.93, 0.96, 0.98, 0.95))
	_action_zone_1.name = "TransformZone"
	_action_label_1 = _action_zone_1.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_action_zone_1)
	_action_zone_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_zone_1.gui_input.connect(func(event: InputEvent) -> void: _on_action_zone_1_gui_input(main, event))

	_action_zone_2 = _create_action_zone_panel(TranslationServer.translate("ui.drop_zone_remove_multi"), Color(0.98, 0.93, 0.93, 0.95))
	_action_zone_2.name = "RemoveZone"
	_action_label_2 = _action_zone_2.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_action_zone_2)
	_action_zone_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_zone_2.gui_input.connect(func(event: InputEvent) -> void: _on_action_zone_2_gui_input(main, event))

	_build_action_instruction_overlay(main)


func _build_action_instruction_overlay(main: Control) -> void:
	var bottom_area: Control = main.bottom_area
	_action_instruction_overlay = PanelContainer.new()
	_action_instruction_overlay.name = "ShrineInstruction"
	_action_instruction_overlay.layout_mode = 1
	_action_instruction_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_action_instruction_overlay.custom_minimum_size = Vector2(0, bottom_area.size.y)
	_action_instruction_overlay.offset_top = -bottom_area.size.y
	_action_instruction_overlay.offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	_action_instruction_overlay.add_theme_stylebox_override("panel", style)
	_action_instruction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_instruction_overlay.add_child(center)

	_action_instruction_label = Label.new()
	_action_instruction_label.text = TranslationServer.translate("ui.shrine_instruction")
	_action_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_instruction_label.add_theme_font_size_override("font_size", 24)
	_action_instruction_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.8))
	_action_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_action_instruction_label)

	var hud_container: Node = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(_action_instruction_overlay)
		_action_instruction_overlay.z_index = 4

	_action_instruction_overlay.visible = false
	_action_instruction_overlay.modulate.a = 0.0


func update_programmatic_labels() -> void:
	if is_instance_valid(_confirm_drop_zone_label):
		if _confirm_drop_zone_mode == &"Rewards":
			_confirm_drop_zone_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_get_multi") + "[/center]"
		elif _confirm_drop_zone_mode == &"Shop":
			_confirm_drop_zone_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_buy_multi") + "[/center]"
	if is_instance_valid(_action_label_1):
		_action_label_1.text = "[center]" + TranslationServer.translate("ui.drop_zone_transform_multi") + "[/center]"
	if is_instance_valid(_action_label_2):
		_action_label_2.text = "[center]" + TranslationServer.translate("ui.drop_zone_remove_multi") + "[/center]"
	if is_instance_valid(_action_instruction_label):
		_action_instruction_label.text = TranslationServer.translate("ui.shrine_instruction")


func show_split_action_drop_zones(main: Control, left_text: String = "", right_text: String = "") -> void:
	var l_text: String = left_text
	if l_text.is_empty():
		l_text = _action_zone_1_text
	if l_text.is_empty():
		l_text = TranslationServer.translate("ui.drop_zone_transform_multi")

	var r_text: String = right_text
	if r_text.is_empty():
		r_text = _action_zone_2_text
	if r_text.is_empty():
		r_text = TranslationServer.translate("ui.drop_zone_remove_multi")

	if is_instance_valid(_action_label_1):
		_action_label_1.text = "[center]" + l_text + "[/center]"
	if is_instance_valid(_action_label_2):
		_action_label_2.text = "[center]" + r_text + "[/center]"

	if not is_instance_valid(_split_action_drop_zone_container) or _split_action_drop_zones_visible:
		return
	_split_action_drop_zones_visible = true
	_split_action_drop_zone_container.visible = true
	var tween: Tween = main.create_tween()
	tween.tween_property(_split_action_drop_zone_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_action_zone_texts(left_text: String, right_text: String, units_only: bool = false) -> void:
	_action_zone_1_text = left_text
	_action_zone_2_text = right_text
	_action_zone_category_filter = ActionZoneCategoryFilter.UNITS_ONLY if units_only else ActionZoneCategoryFilter.ALL


func hide_split_action_drop_zones(main: Control) -> void:
	if not is_instance_valid(_split_action_drop_zone_container) or not _split_action_drop_zones_visible:
		return
	_split_action_drop_zones_visible = false
	var tween: Tween = main.create_tween()
	tween.tween_property(_split_action_drop_zone_container, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_split_action_drop_zone_container):
			_split_action_drop_zone_container.visible = false
	)


func show_action_instruction(main: Control, text: String = "") -> void:
	if is_instance_valid(_action_instruction_label):
		_action_instruction_label.text = text if not text.is_empty() else TranslationServer.translate("ui.shrine_instruction")
	if not is_instance_valid(_action_instruction_overlay) or _action_instruction_visible:
		return
	_action_instruction_visible = true
	_action_instruction_overlay.visible = true
	var tween: Tween = main.create_tween()
	tween.tween_property(_action_instruction_overlay, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_action_instruction(main: Control) -> void:
	if not is_instance_valid(_action_instruction_overlay) or not _action_instruction_visible:
		return
	_action_instruction_visible = false
	var tween: Tween = main.create_tween()
	tween.tween_property(_action_instruction_overlay, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_action_instruction_overlay):
			_action_instruction_overlay.visible = false
	)


func _on_action_zone_2_gui_input(main: Control, event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		if _action_drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("action_drop_zone_2_activated", false, Vector2.ZERO)
		Audio.play_sfx("ui_click")
		main.get_viewport().set_input_as_handled()


func _on_action_zone_1_gui_input(main: Control, event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		if _action_drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("action_drop_zone_1_activated", false, Vector2.ZERO)
		Audio.play_sfx("ui_click")
		main.get_viewport().set_input_as_handled()


func _check_action_drag_drop_on_zones_with_context(main: Control, context: InteractionContext) -> bool:
	if not _split_action_drop_zones_visible or not is_instance_valid(_split_action_drop_zone_container) or context == null:
		return false
	var pointer_pos: Vector2 = _get_pointer_pos(main)
	if is_instance_valid(_action_zone_2) and _action_zone_2.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("action_drop_zone_2_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	if is_instance_valid(_action_zone_1) and _action_zone_1.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("action_drop_zone_1_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	return false


func _build_reward_drop_zones(main: Control) -> void:
	var bottom_area: Control = main.bottom_area
	_reward_drop_zone_container = _create_split_zone_shell("RewardDropZones", bottom_area)
	var hbox: HBoxContainer = _reward_drop_zone_container.get_child(0) as HBoxContainer

	_reward_collect_zone = _create_action_zone_panel(TranslationServer.translate("Drag or click here to add it to your collection"), Color(0.93, 0.98, 0.93, 0.95))
	_reward_collect_zone.name = "CollectZone"
	_reward_collect_label = _reward_collect_zone.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_reward_collect_zone)
	_reward_collect_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_collect_zone.gui_input.connect(func(event: InputEvent) -> void: _on_reward_collect_zone_gui_input(main, event))

	_reward_sell_zone = _create_action_zone_panel(TranslationServer.translate("Drag or click here to sell it"), Color(0.98, 0.93, 0.93, 0.95))
	_reward_sell_zone.name = "SellZone"
	_reward_sell_label = _reward_sell_zone.get_child(0).get_child(0) as RichTextLabel
	hbox.add_child(_reward_sell_zone)
	_reward_sell_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_sell_zone.gui_input.connect(func(event: InputEvent) -> void: _on_reward_sell_zone_gui_input(main, event))


func _on_reward_collect_zone_gui_input(main: Control, event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
		if _drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("reward_collect_zone_activated", false, Vector2.ZERO)
		main.get_viewport().set_input_as_handled()


func _on_reward_sell_zone_gui_input(main: Control, event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_press(event):
		if _drop_zone_drag_context != null:
			return
		SignalBus.emit_signal("reward_sell_zone_activated", false, Vector2.ZERO)
		main.get_viewport().set_input_as_handled()


func show_reward_drop_zones(main: Control) -> void:
	if not is_instance_valid(_reward_drop_zone_container) or _reward_drop_zones_visible:
		return
	_reward_sell_zone.visible = true
	_reward_collect_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_collect_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_get_multi") + "[/center]"
	_reward_sell_label.text = "[center]" + TranslationServer.translate("ui.drop_zone_sell_multi") + "[/center]"
	_reward_drop_zones_visible = true
	_reward_drop_zone_container.visible = true
	var tween: Tween = main.create_tween()
	tween.tween_property(_reward_drop_zone_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_reward_drop_zones(main: Control) -> void:
	if not is_instance_valid(_reward_drop_zone_container) or not _reward_drop_zones_visible:
		return
	_reward_drop_zones_visible = false
	var tween: Tween = main.create_tween()
	tween.tween_property(_reward_drop_zone_container, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_reward_drop_zone_container) and not _reward_drop_zones_visible:
			_reward_drop_zone_container.visible = false
	)


func _check_reward_drag_drop_on_zones_with_context(main: Control, context: InteractionContext) -> bool:
	if not _reward_drop_zones_visible or not is_instance_valid(_reward_drop_zone_container) or context == null:
		return false
	var pointer_pos: Vector2 = _get_pointer_pos(main)
	if is_instance_valid(_reward_collect_zone) and _reward_collect_zone.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("reward_collect_zone_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	if is_instance_valid(_reward_sell_zone) and _reward_sell_zone.visible and _reward_sell_zone.get_global_rect().has_point(pointer_pos):
		GlobalInteractionRouter.set_current_selection(context)
		SignalBus.emit_signal("selection_changed", context.location)
		SignalBus.emit_signal("reward_sell_zone_activated", true, pointer_pos)
		Audio.play_sfx("ui_click")
		return true
	return false


func get_action_zone_1() -> Control:
	return _action_zone_1


func get_action_zone_2() -> Control:
	return _action_zone_2


func get_reward_collect_zone() -> Control:
	return _reward_collect_zone


func get_reward_sell_zone() -> Control:
	return _reward_sell_zone


func _instant_hide_instruction() -> void:
	if _action_instruction_visible and is_instance_valid(_action_instruction_overlay):
		_action_instruction_overlay.visible = false
		_action_instruction_visible = false
		_action_instruction_overlay.modulate.a = 0.0


func _restore_reward_instruction_if_active(main: Control) -> void:
	var content_node: Node = main._current_content_node
	var is_reward_context: bool = is_instance_valid(content_node) and (content_node.name.begins_with("Reward") or content_node.is_in_group("reward_scene"))
	if is_reward_context and not WindowManager.is_run_inventory_window_open():
		show_action_instruction(main, TranslationServer.translate("ui.reward_instruction"))


func _is_valid_category_for_action_zones(loc: LocationIdentifier) -> bool:
	if _action_zone_category_filter != ActionZoneCategoryFilter.UNITS_ONLY:
		return true
	var sel: InteractionContext = GlobalInteractionRouter.get_current_selection()
	var sel_type: StringName = _resolve_entity_category(sel.entity_type if sel else &"", loc)
	return sel_type == &"UNIT"


static func _resolve_entity_category(initial_type: StringName, loc: LocationIdentifier) -> StringName:
	if initial_type != &"":
		return initial_type
	if is_instance_valid(loc):
		var inst: GachaBallInstance = GameManager.get_instance_from_location(loc)
		if is_instance_valid(inst):
			var def: Resource = inst.get_definition()
			if def is GachaBallDefinition:
				return (def as GachaBallDefinition).category
	return &""


static func _get_pointer_pos(main: Control) -> Vector2:
	return GlobalInteractionRouter.get_last_pointer_position() if is_instance_valid(GlobalInteractionRouter) else main.get_viewport().get_mouse_position()


static func _create_split_zone_shell(node_name: String, bottom_area: Control) -> PanelContainer:
	var container := PanelContainer.new()
	container.name = node_name
	container.layout_mode = 1
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.custom_minimum_size = Vector2(0, bottom_area.size.y)
	container.offset_top = -bottom_area.size.y
	container.offset_bottom = 0

	var container_style := StyleBoxFlat.new()
	container_style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", container_style)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(hbox)

	var hud_container: Node = bottom_area.get_parent()
	if is_instance_valid(hud_container):
		hud_container.add_child(container)
		container.z_index = 5

	container.visible = false
	container.modulate.a = 0.0
	return container


static func _create_action_zone_panel(text: String, bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_script(DropZoneScript)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(400, 0)
	label.text = "[center]" + text + "[/center]"
	label.add_theme_font_size_override("normal_font_size", 32)
	label.add_theme_color_override("default_color", Color(0.3, 0.3, 0.28, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.17, 0.22, 0.3))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	return panel

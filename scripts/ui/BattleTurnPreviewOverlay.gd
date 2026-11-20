# res://scripts/ui/BattleTurnPreviewOverlay.gd
class_name BattleTurnPreviewOverlay
extends RefCounted

## Manages the BattleView combat inspection overlays:
## - Floating starting actor order numbers (Order button / R key)
## - Held turn preview board showing projected lineup state (Preview button)

const C = preload("res://scripts/Constants.gd")
const SlotViewScene = preload("res://scenes/SlotView.tscn")
const ORDER_LABEL_GAP: float = 8.0

var order_button_held: bool = false
var _order_labels: Array[Label] = []
var _preview_board: Control = null


func is_preview_active() -> bool:
	return _preview_board != null


func on_focus_lost(battle_view: Control) -> void:
	order_button_held = false
	end_preview(battle_view)


func sync_controls(battle_view: Control) -> void:
	var can_inspect_turn: bool = battle_view.battle_manager.can_hold_turn_preview()
	battle_view.order_button.disabled = not can_inspect_turn
	battle_view.preview_button.disabled = _preview_board == null and not can_inspect_turn
	if battle_view.order_button.disabled:
		order_button_held = false


func refresh_order_labels(battle_view: Control) -> void:
	var order: Array[String] = []
	if not battle_view.order_button.disabled and _preview_board == null and not WindowManager.is_modal_open():
		if order_button_held or Input.is_physical_key_pressed(KEY_R):
			order = battle_view.battle_manager.get_starting_actor_order()

	for index: int in range(order.size()):
		if index >= _order_labels.size():
			_order_labels.append(_create_order_label(battle_view))
		var label: Label = _order_labels[index]
		var unit: GachaBallView = _find_displayed_actor(battle_view, order[index])
		label.visible = unit != null
		if unit != null:
			label.text = str(index + 1)
			var sprite_bounds: Rect2 = unit.get_sprite_global_bounds()
			var top: float = minf(unit.get_global_rect().position.y, sprite_bounds.position.y)
			label.global_position = Vector2(
				sprite_bounds.get_center().x - label.size.x * 0.5,
				top - label.size.y - ORDER_LABEL_GAP,
			)

	for index: int in range(order.size(), _order_labels.size()):
		_order_labels[index].hide()


func begin_preview(battle_view: Control) -> void:
	if _preview_board != null or not battle_view.battle_manager.can_hold_turn_preview():
		return
	var snapshot: Dictionary = battle_view.battle_manager.get_held_turn_preview()
	var units: Dictionary = snapshot["units"]
	var player_effects: Array[StringName] = snapshot["player_slot_effects"]
	var enemy_effects: Array[StringName] = snapshot["enemy_slot_effects"]
	_preview_board = Control.new()
	_preview_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_view.add_child(_preview_board)
	_preview_board.modulate = Color(0.79, 0.91, 1.0)
	_render_preview_lineup(battle_view.player_lineup, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, player_effects, units, false)
	_render_preview_lineup(battle_view.enemy_lineup, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, enemy_effects, units, true)
	battle_view.player_lineup.hide()
	battle_view.enemy_lineup.hide()
	battle_view.end_turn_button.disabled = true


func end_preview(battle_view: Control) -> void:
	if _preview_board == null:
		return
	_preview_board.hide()
	_preview_board.queue_free()
	_preview_board = null
	battle_view.player_lineup.show()
	battle_view.enemy_lineup.show()
	battle_view.end_turn_button.disabled = battle_view.battle_manager.get_current_phase() != BattleManager.Phases.MANAGEMENT


func _render_preview_lineup(live: HBoxContainer, tag: StringName, effects: Array[StringName], units: Dictionary, is_enemy: bool) -> void:
	var occupants: Dictionary[int, Dictionary] = {}
	for data: Dictionary in units.values():
		if data["container_tag"] == tag:
			occupants[data["slot_index"]] = data
	for index: int in range(live.get_child_count()):
		var live_slot: SlotView = live.get_child(index) as SlotView
		var slot: SlotView = SlotViewScene.instantiate() as SlotView
		_preview_board.add_child(slot)
		slot.populate(LocationIdentifier.new(tag, index))
		slot.set_slot_color(tag)
		slot.set_size_scale(2.0)
		slot.size = live_slot.size
		slot.global_position = live_slot.global_position
		slot.set_slot_effect(effects[index])
		slot.set_interaction_context(&"INSPECTION_ONLY")
		slot.set_content(occupants.get(index, {}), false, is_enemy)
		slot._recursively_set_mouse_filter_ignore(slot)


static func _create_order_label(parent: Control) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 35
	label.custom_minimum_size = Vector2(76, 62)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.80))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.15))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	return label


static func _find_displayed_actor(battle_view: Control, uuid: String) -> GachaBallView:
	for lineup: HBoxContainer in [battle_view.player_lineup, battle_view.enemy_lineup]:
		for slot: Node in lineup.get_children():
			for child: Node in slot.get_children():
				var unit: GachaBallView = child as GachaBallView
				if unit != null and not unit.is_queued_for_deletion() and unit.is_visible_in_tree() and unit.get_instance_uuid() == uuid:
					return unit
	return null

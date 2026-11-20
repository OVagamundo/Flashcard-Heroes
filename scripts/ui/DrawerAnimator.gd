# res://scripts/ui/DrawerAnimator.gd
class_name DrawerAnimator
extends RefCounted

## Manages node-bound open/close tween transitions and active transition state
## for persistent drawers (Inventory, BattleInventory, DiscardPile) and popups.
## Tracks transition flags in typed dictionaries instead of Control metadata.

const DISCARD_PILE_HIDDEN_X: float = 1920.0
const DISCARD_PILE_OPEN_X: float = 640.0

var _opening_ids: Dictionary[int, bool] = {}
var _closing_ids: Dictionary[int, bool] = {}
var _active_tweens: Dictionary[int, Tween] = {}


func is_opening(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	return _opening_ids.get(window.get_instance_id(), false)


func is_closing(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	return _closing_ids.get(window.get_instance_id(), false)


func kill_motion_tween(window: Control) -> void:
	if not is_instance_valid(window):
		return
	var win_id: int = window.get_instance_id()
	if not _active_tweens.has(win_id):
		return
	var existing_tween: Tween = _active_tweens[win_id]
	if is_instance_valid(existing_tween):
		existing_tween.kill()
	_active_tweens.erase(win_id)


func clear_window_state(window_id: int) -> void:
	_opening_ids.erase(window_id)
	_closing_ids.erase(window_id)
	if _active_tweens.has(window_id):
		var existing_tween: Tween = _active_tweens[window_id]
		if is_instance_valid(existing_tween):
			existing_tween.kill()
		_active_tweens.erase(window_id)


func is_discard_pile_window(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	return window is DiscardPileWindow or (window.has_meta("window_type") and window.get_meta("window_type") == &"DiscardPile")


func is_inventory_window(window: Control) -> bool:
	if not is_instance_valid(window):
		return false
	if window.has_meta("window_type") and window.get_meta("window_type") == &"Inventory":
		return true
	if "InventoryWindow" in window.name:
		return true
	var script_ref: Script = window.get_script() as Script
	if script_ref != null and script_ref.resource_path.ends_with("InventoryWindow.gd"):
		return true
	return false


func animate_discard_pile_open(window: Control) -> void:
	if not is_instance_valid(window) or is_opening(window):
		return
	var win_id: int = window.get_instance_id()
	_opening_ids[win_id] = true
	_closing_ids[win_id] = false

	window.position.x = DISCARD_PILE_HIDDEN_X
	window.show()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if window is DiscardPileWindow:
		(window as DiscardPileWindow).prepare_for_open()

	kill_motion_tween(window)
	Audio.play_sfx("ui_window_open")

	var tween: Tween = window.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(window, "position:x", DISCARD_PILE_OPEN_X, 0.45) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func() -> void:
		_opening_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(window):
			if window is DiscardPileWindow:
				(window as DiscardPileWindow).call_deferred("on_window_opened")
			window.mouse_filter = Control.MOUSE_FILTER_STOP
	)


func animate_discard_pile_close(window: Control) -> void:
	if not is_instance_valid(window) or is_closing(window):
		return
	var win_id: int = window.get_instance_id()
	_opening_ids[win_id] = false
	_closing_ids[win_id] = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE

	kill_motion_tween(window)

	var tween: Tween = window.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(window, "position:x", DISCARD_PILE_HIDDEN_X, 0.35) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func() -> void:
		_closing_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(window):
			window.hide()
	)


func animate_inventory_window_open(window: Control, persistent_battle_inventory: Control) -> void:
	if not is_instance_valid(window):
		return
	if window == persistent_battle_inventory:
		animate_battle_inventory_open(window)
		return
	if is_opening(window):
		return

	var win_id: int = window.get_instance_id()
	_opening_ids[win_id] = true
	_closing_ids[win_id] = false

	var anim_target: Control = _resolve_inventory_panel(window)
	window.show()

	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in window.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	kill_motion_tween(window)
	Audio.play_sfx("ui_window_open")

	var base_top: float = 340.0
	var base_bottom: float = 880.0
	var start_delta: float = 540.0
	_apply_vertical_offset_delta(start_delta, anim_target, base_top, base_bottom)

	var tween: Tween = window.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_method(
		func(val: float) -> void: _apply_vertical_offset_delta(val, anim_target, base_top, base_bottom),
		start_delta,
		0.0,
		0.45
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func() -> void:
		_opening_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(window):
			window.mouse_filter = Control.MOUSE_FILTER_PASS
			for child in window.get_children():
				if child is PanelContainer:
					(child as PanelContainer).mouse_filter = Control.MOUSE_FILTER_PASS
				elif child is Control:
					(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func animate_inventory_window_close(
	window: Control,
	persistent_inventory: Control,
	persistent_battle_inventory: Control,
	active_inspection_group: Array[Control]
) -> bool:
	if not is_inventory_window(window):
		return false
	if not is_instance_valid(window):
		return true
	if window == persistent_battle_inventory:
		animate_battle_inventory_close(window)
		return true
	if is_closing(window):
		return true

	var win_id: int = window.get_instance_id()
	_opening_ids[win_id] = false
	_closing_ids[win_id] = true

	var anim_target: Control = _resolve_inventory_panel(window)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in window.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	kill_motion_tween(window)

	var base_top: float = 340.0
	var base_bottom: float = 880.0
	var final_delta: float = 540.0

	var tween: Tween = window.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_method(
		func(val: float) -> void: _apply_vertical_offset_delta(val, anim_target, base_top, base_bottom),
		0.0,
		final_delta,
		0.35
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func() -> void:
		_closing_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(window):
			if window == persistent_inventory:
				window.hide()
				var idx: int = active_inspection_group.find(window)
				if idx != -1:
					active_inspection_group.remove_at(idx)
			else:
				window.queue_free()
	)
	return true


func animate_battle_inventory_open(window: Control) -> void:
	if not is_instance_valid(window) or is_opening(window):
		return
	var battle_inv := window as BattleInventoryWindow
	assert(battle_inv != null, "DrawerAnimator.animate_battle_inventory_open requires a BattleInventoryWindow")
	var win_id: int = battle_inv.get_instance_id()
	_opening_ids[win_id] = true
	_closing_ids[win_id] = false

	battle_inv.prepare_for_open()
	kill_motion_tween(battle_inv)
	Audio.play_sfx("ui_window_open")

	var duration: float = battle_inv.get_open_duration()
	var tween: Tween = battle_inv.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_method(
		Callable(battle_inv, "set_open_progress"),
		battle_inv.get_open_progress(),
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.chain().tween_callback(func() -> void:
		_opening_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(battle_inv):
			battle_inv.finish_open()
	)


func animate_battle_inventory_close(window: Control) -> void:
	if not is_instance_valid(window) or is_closing(window):
		return
	var battle_inv := window as BattleInventoryWindow
	assert(battle_inv != null, "DrawerAnimator.animate_battle_inventory_close requires a BattleInventoryWindow")
	var win_id: int = battle_inv.get_instance_id()
	_opening_ids[win_id] = false
	_closing_ids[win_id] = true

	battle_inv.prepare_for_close()
	kill_motion_tween(battle_inv)

	var duration: float = battle_inv.get_close_duration()
	var tween: Tween = battle_inv.create_tween()
	_active_tweens[win_id] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_method(
		Callable(battle_inv, "set_open_progress"),
		battle_inv.get_open_progress(),
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.chain().tween_callback(func() -> void:
		_closing_ids.erase(win_id)
		_active_tweens.erase(win_id)
		if is_instance_valid(battle_inv):
			battle_inv.finish_close()
	)


func animate_window_open(window: Control, persistent_battle_inventory: Control) -> void:
	if not is_instance_valid(window):
		return
	var root_window: Control = window
	if is_inventory_window(root_window):
		animate_inventory_window_open(root_window, persistent_battle_inventory)
		return

	var target: Control = _resolve_popup_animation_target(root_window)
	if not is_instance_valid(target):
		return

	target.pivot_offset = target.size / 2.0
	target.modulate.a = 1.0
	target.show()
	target.scale = Vector2.ONE
	Audio.play_sfx("ui_window_open")

	var tween: Tween = target.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if root_window is TutorialPopup:
		var tutorial_popup := root_window as TutorialPopup
		tween.finished.connect(tutorial_popup.set_interaction_enabled.bind(true))


static func _apply_vertical_offset_delta(delta: float, control: Control, base_top: float, base_bottom: float) -> void:
	if not is_instance_valid(control):
		return
	control.offset_top = base_top + delta
	control.offset_bottom = base_bottom + delta


static func _resolve_inventory_panel(window: Control) -> Control:
	# Avoid naming InventoryWindow directly (it preloads SlotView.tscn which references WindowManager).
	var panel: Control = window.get_node_or_null("%PanelContainer") as Control
	return panel if is_instance_valid(panel) else window


static func _resolve_popup_animation_target(window: Control) -> Control:
	if window is TutorialPopup:
		return (window as TutorialPopup).get_window_to_animate()
	if window is EndBattlePopup:
		return (window as EndBattlePopup).get_window_to_animate()
	if window is RunCompletePopup:
		return (window as RunCompletePopup).get_window_to_animate()
	if window is ResultsPopup:
		return (window as ResultsPopup).get_window_to_animate()
	if window is FlashcardMinigame:
		return (window as FlashcardMinigame).get_window_to_animate()
	if window is DiscardPileWindow:
		return (window as DiscardPileWindow).get_window_to_animate()
	return window

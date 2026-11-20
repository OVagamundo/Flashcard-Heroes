# res://scripts/ui/BattleDrawAnimator.gd
class_name BattleDrawAnimator
extends RefCounted

## Handles BattleView draw flight choreography, initial unit entry stagger,
## capsule-open pop VFX, and battle-scoped tutorial prompts.

const C = preload("res://scripts/Constants.gd")
# Load at draw time so circular preload with BattleView cannot retain an empty PackedScene.
const GACHA_BALL_VIEW_SCENE_PATH: String = "res://scenes/GachaBallView.tscn"


static func resolve_draw_visual_data(battle_manager: BattleManager, drawn_uuid: String, new_unit_snapshot: Dictionary) -> Dictionary:
	if not new_unit_snapshot.is_empty():
		return new_unit_snapshot
	if BattleAnimator.is_snapshot_playback_active():
		return BattleAnimator.get_visual_snapshot_store().get_snapshot_by_uuid(drawn_uuid)
	var instance: GachaBallInstance = battle_manager.get_instance(drawn_uuid)
	if is_instance_valid(instance):
		return VisualDataAdapter.create_visual_data(instance, battle_manager.get_all_instances())
	return {}


static func animate_gacha_draw(battle_view: Control, draw_result: InventoryOperations.DrawResult, new_unit_snapshot: Dictionary) -> void:
	if not draw_result.drawn_uuid.is_empty():
		battle_view._pending_animated_uuids.append(draw_result.drawn_uuid)

	var main_node: Node = GameManager.get_main_node()
	if not is_instance_valid(main_node):
		await _force_refresh_after_anim(battle_view, draw_result, new_unit_snapshot)
		return

	var is_from_discard: bool = draw_result.source_container == &"DiscardPile"
	var returns_to_discard: bool = is_from_discard and draw_result.dest_container == &"DiscardPile"
	var tier: int = 1
	var start_pos: Vector2
	var end_pos: Vector2
	var dest_slot_view: Control = null

	if is_from_discard:
		var discard_machine: Control = main_node.get_discard_machine() as Control
		start_pos = _resolve_machine_center(discard_machine, battle_view.get_viewport_rect().get_center())

		if draw_result.dest_container.ends_with("T2"):
			tier = 2
		elif draw_result.dest_container.ends_with("T3"):
			tier = 3

		var target_machine: Control = discard_machine if returns_to_discard else main_node.get_gacha_machine(tier) as Control
		end_pos = _resolve_machine_center(target_machine, start_pos)

		if is_instance_valid(discard_machine):
			GachaMachineBarPresenter.play_machine_bounce(main_node, discard_machine)
	else:
		if draw_result.source_container.ends_with("T2"):
			tier = 2
		elif draw_result.source_container.ends_with("T3"):
			tier = 3

		var machine_node: Control = main_node.get_node_or_null("%%GachaMachine%d" % tier) as Control
		var knob_node: Control = machine_node.get_node_or_null("KnobButton") as Control if is_instance_valid(machine_node) else null
		start_pos = knob_node.get_global_rect().get_center() if is_instance_valid(knob_node) else battle_view.get_viewport_rect().get_center()

		main_node.animate_machine_inventory_change(tier, -1)

		if draw_result.went_to_discard or draw_result.dest_container == &"DiscardPile":
			end_pos = battle_view.discard_pile_button.get_global_rect().get_center()
		else:
			var target_ui_container: HBoxContainer = battle_view.player_shelf if draw_result.dest_container == &"PlayerShelf" else null
			if is_instance_valid(target_ui_container) and draw_result.dest_slot >= 0 and draw_result.dest_slot < target_ui_container.get_child_count():
				dest_slot_view = target_ui_container.get_child(draw_result.dest_slot) as Control
				end_pos = dest_slot_view.get_global_transform() * GachaBallView.shelf_capsule_center(dest_slot_view.size)
			else:
				end_pos = start_pos

	var ball_scene: PackedScene = load(GACHA_BALL_VIEW_SCENE_PATH) as PackedScene
	var anim_ball: GachaBallView = ball_scene.instantiate() as GachaBallView
	anim_ball.set_size_scale(1.0)
	anim_ball.force_inventory_mode = true

	var effects_layer: CanvasLayer = WindowManager.get_vfx_layer()
	if is_instance_valid(effects_layer):
		effects_layer.add_child(anim_ball)
	else:
		battle_view.add_child(anim_ball)

	anim_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_ball.z_index = 100
	anim_ball.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	anim_ball.custom_minimum_size = Vector2.ONE * C.GACHA_CAPSULE_DIAMETER
	anim_ball.size = anim_ball.custom_minimum_size

	var visual_data: Dictionary = resolve_draw_visual_data(battle_view.battle_manager, draw_result.drawn_uuid, new_unit_snapshot)
	if not visual_data.is_empty():
		anim_ball.populate(null, visual_data)

	anim_ball.pivot_offset = anim_ball.get_capsule_rect().get_center()

	var initial_scale: float = 0.4
	anim_ball.scale = Vector2(initial_scale, initial_scale)
	anim_ball.global_position = start_pos - anim_ball.pivot_offset

	var horiz_dist: float = absf(end_pos.x - start_pos.x)
	var arc_height: float = clampf(horiz_dist * 0.30 + 320.0, 500.0, 780.0) if is_from_discard else 400.0
	var raw_duration: float = clampf(horiz_dist / 5000.0 + 0.22, 0.32, 0.46) if is_from_discard else 0.45
	var landing_scale: float = C.SHELF_CAPSULE_SCALE if dest_slot_view != null else 1.0

	var tween: Tween = ArcTossAnimator.toss_bezier(anim_ball, start_pos, end_pos, {
		"arc_height": arc_height,
		"duration": raw_duration,
		"scale_duration": true,
		"ease_power": 0.60,
		"start_scale": initial_scale,
		"end_scale": landing_scale,
		"scale_curve": &"quad_out",
	})

	await tween.finished
	Audio.play_sfx("coin_land")
	if is_from_discard:
		if returns_to_discard:
			battle_view.animate_discard_pile_arrival(0)
		else:
			main_node.animate_machine_inventory_change(tier, 1)
			battle_view.init_visual_discard_count(maxi(0, battle_view._visual_discard_count - 1))
	elif draw_result.went_to_discard:
		battle_view.animate_discard_pile_arrival()

	anim_ball.queue_free()
	await _force_refresh_after_anim(battle_view, draw_result, new_unit_snapshot)
	SignalBus.gacha_draw_animation_completed.emit(draw_result)


static func _force_refresh_after_anim(battle_view: Control, draw_result: InventoryOperations.DrawResult, new_unit_snapshot: Dictionary) -> void:
	if draw_result != null and not draw_result.drawn_uuid.is_empty():
		battle_view._pending_animated_uuids.erase(draw_result.drawn_uuid)

	if draw_result == null or draw_result.source_container == &"DiscardPile":
		return

	if draw_result.went_to_discard or draw_result.dest_container == &"DiscardPile":
		Audio.play_sfx("coin_land")
		var discard_btn: Control = battle_view.discard_pile_button
		if is_instance_valid(discard_btn):
			var bump_tween: Tween = discard_btn.create_tween()
			discard_btn.pivot_offset = discard_btn.size / 2.0
			bump_tween.tween_property(discard_btn, "scale", Vector2(1.15, 1.15), AnimationConstants.scaled(0.08)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			bump_tween.tween_property(discard_btn, "scale", Vector2.ONE, AnimationConstants.scaled(0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await bump_tween.finished
		return

	var target_ui_container: HBoxContainer = null
	if draw_result.dest_container == &"PlayerShelf":
		target_ui_container = battle_view.player_shelf
	elif draw_result.dest_container == &"PlayerLineup":
		target_ui_container = battle_view.player_lineup

	if not is_instance_valid(target_ui_container) or draw_result.dest_slot < 0 or draw_result.dest_slot >= target_ui_container.get_child_count():
		return

	var slot_view: SlotView = target_ui_container.get_child(draw_result.dest_slot) as SlotView
	var ball_view: GachaBallView = null
	if is_instance_valid(slot_view):
		var visual_data: Dictionary = resolve_draw_visual_data(battle_view.battle_manager, draw_result.drawn_uuid, new_unit_snapshot)
		if not visual_data.is_empty():
			var loc := LocationIdentifier.new(draw_result.dest_container, draw_result.dest_slot)
			slot_view.populate(loc)
			slot_view.set_meta("location_identifier", loc)
			ball_view = slot_view.set_content(visual_data, true, false)
			if is_instance_valid(ball_view):
				ball_view.set_meta("location_identifier", loc)

	if not is_instance_valid(ball_view):
		return

	await battle_view.get_tree().process_frame

	if not TutorialManager.is_completed(&"first_draw"):
		if ActionQueue.is_busy():
			battle_view._waiting_for_first_draw_tutorial = true
		else:
			battle_view.call_deferred("_show_first_draw_tutorial")

	ball_view.play_landing_bounce()
	await AnimationConstants.create_pausable_timer(battle_view.get_tree(), AnimationConstants.scaled(0.35)).timeout


static func animate_initial_unit_entry(battle_view: Control) -> void:
	var all_units: Array[GachaBallView] = []
	for lineup: HBoxContainer in [battle_view.player_lineup, battle_view.enemy_lineup]:
		for slot in lineup.get_children():
			if slot is PanelContainer:
				for child in slot.get_children():
					if child is GachaBallView:
						all_units.append(child as GachaBallView)
						break

	for i: int in range(all_units.size()):
		var ball_view: GachaBallView = all_units[i]
		if not is_instance_valid(ball_view):
			continue
		var sprite_node: Control = ball_view.icon_rect.get_node_or_null("UnitSprite") as Control
		var target_node: Control = sprite_node if is_instance_valid(sprite_node) else ball_view.icon_rect
		if is_instance_valid(target_node):
			target_node.scale = Vector2.ZERO
			target_node.pivot_offset = target_node.size / 2.0
			var delay: float = i * AnimationConstants.scaled(AnimationConstants.ENTRY_STAGGER_DELAY)
			var wait_tween: Tween = battle_view.create_tween()
			wait_tween.tween_interval(delay)
			wait_tween.tween_callback(func() -> void:
				if is_instance_valid(target_node):
					target_node.scale = Vector2.ONE
				if is_instance_valid(ball_view):
					ball_view.play_landing_bounce()
			)

	var total_time: float = maxf(0.0, (all_units.size() - 1) * AnimationConstants.scaled(AnimationConstants.ENTRY_STAGGER_DELAY))
	var finish_tween: Tween = battle_view.create_tween()
	finish_tween.tween_interval(total_time + AnimationConstants.scaled(0.5))
	finish_tween.tween_callback(func() -> void:
		SignalBus.battle_entry_animation_finished.emit()
	)


static func play_lineup_capsule_open(battle_view: Control, source_location: LocationIdentifier, target_location: LocationIdentifier) -> void:
	if source_location.container != C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or ActionQueue.is_headless_mode():
		return
	var location: LocationIdentifier = target_location
	if location.container == C.CONTAINER_EQUIPPED_ITEM:
		var holder: GachaBallInstance = battle_view.battle_manager.get_instance_by_uuid(location.unit_uuid)
		location = holder.get_location()
	assert(battle_view.battle_manager._state.is_lineup_location(location), "Capsules can only open in a Lineup")
	var lineup: HBoxContainer = battle_view.player_lineup if location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP else battle_view.enemy_lineup
	var slot: SlotView = lineup.get_child(location.index) as SlotView
	VFXFactory.spawn_capsule_pop_vfx(slot.get_global_rect().get_center(), battle_view, 1.5, Vector2.ZERO)


static func show_battle_management_tutorial(battle_view: Control) -> void:
	if TutorialManager.is_completed(&"battle_management_intro"):
		return
	battle_view._waiting_for_management_tutorial = false

	var main_node: Node = GameManager.get_main_node()
	if not is_instance_valid(main_node):
		return

	var anchors: Array[String] = []
	for unique_name: String in ["%TokenGroup", "%GachaMachine1", "%GachaMachine2", "%GachaMachine3"]:
		var node: Node = main_node.get_node_or_null(unique_name)
		if is_instance_valid(node):
			anchors.append(str(node.get_path()))

	TutorialManager.show_tutorial(&"battle_management_intro", [
		{
			"text": battle_view.tr("tutorial.battle_management"),
			"center": true,
			"anchor_paths": anchors
		}
	], null)


static func show_first_draw_tutorial(battle_view: Control) -> void:
	if TutorialManager.is_completed(&"first_draw"):
		return
	var shelf_slot_1: Node = battle_view.player_shelf.get_child(0) if battle_view.player_shelf.get_child_count() > 0 else battle_view.player_shelf
	var lineup_slot_2: Node = battle_view.player_lineup.get_child(1) if battle_view.player_lineup.get_child_count() > 1 else battle_view.player_lineup
	assert(battle_view.player_lineup.get_child_count() == C.LINEUP_CAP, "BattleView._show_first_draw_tutorial: player lineup slot count must match LINEUP_CAP")
	assert(battle_view.enemy_lineup.get_child_count() == C.LINEUP_CAP, "BattleView._show_first_draw_tutorial: enemy lineup slot count must match LINEUP_CAP")
	assert(is_instance_valid(battle_view.end_turn_button), "BattleView._show_first_draw_tutorial: Ready button is required")

	var numbered_slot_paths: Array[String] = []
	var battle_order_anchor_paths: Array[String] = []
	for rank: int in range(C.LINEUP_CAP):
		var enemy_slot: Control = battle_view.enemy_lineup.get_child(rank) as Control
		var player_slot: Control = battle_view.player_lineup.get_child(C.LINEUP_CAP - 1 - rank) as Control
		assert(is_instance_valid(enemy_slot), "BattleView._show_first_draw_tutorial: enemy lineup slot is required")
		assert(is_instance_valid(player_slot), "BattleView._show_first_draw_tutorial: player lineup slot is required")
		numbered_slot_paths.append(str(enemy_slot.get_path()))
		numbered_slot_paths.append(str(player_slot.get_path()))
		battle_order_anchor_paths.append(str(enemy_slot.get_path()))
		battle_order_anchor_paths.append(str(player_slot.get_path()))

	battle_order_anchor_paths.append(str(battle_view.end_turn_button.get_path()))

	TutorialManager.show_tutorial(&"first_draw", [
		{
			"text": battle_view.tr("tutorial.first_draw_1"),
			"anchor_side": "TOP_RIGHT",
			"anchor_paths": [lineup_slot_2.get_path(), shelf_slot_1.get_path(), battle_view.discard_pile_button.get_path()]
		},
		{
			"title": battle_view.tr("tutorial.first_draw_combat.title"),
			"text": battle_view.tr("tutorial.first_draw_2"),
			"anchor_side": "BOTTOM_LEFT",
			"panel_width": 680.0,
			"text_font_size": 19,
			"title_font_size": 23,
			"button_width": 210.0,
			"button_height": 64.0,
			"button_font_size": 28,
			"fit_to_button": true,
			"anchor_paths": battle_order_anchor_paths,
			"numbered_anchor_paths": numbered_slot_paths
		}
	])


static func _resolve_machine_center(machine: Control, fallback: Vector2) -> Vector2:
	if not is_instance_valid(machine):
		return fallback
	var knob: Control = machine.get_node_or_null("KnobButton") as Control
	if is_instance_valid(knob):
		return knob.get_global_rect().get_center()
	return machine.get_global_rect().get_center()

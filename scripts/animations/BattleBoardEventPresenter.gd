# res://scripts/animations/BattleBoardEventPresenter.gd
class_name BattleBoardEventPresenter
extends RefCounted

## Handles inline board-level combat event choreographies for BattleAnimator:
## - SUMMON (inventory arc, discard arc, board slot fade-in)
## - DRAW (registering drawn shelf/lineup puppet)
## - Currency & bonus-timer projectiles (GOLD_GAIN/SPEND, TOKEN_GAIN/SPEND, TIMER_BONUS)
## - ITEM_TRANSFER, ITEM_DISCARD, ITEM_EQUIP, incubator MOVE, and player death departure

const C = preload("res://scripts/Constants.gd")
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")


static func animate_draw(animator: Node, event: CombatEvent) -> void:
	var payload: CombatPayload = event.visual_payload
	var draw_result: InventoryOperations.DrawResult = payload.draw_result
	var draw_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	if draw_result == null or draw_view == null:
		return

	await draw_view.animate_gacha_draw(draw_result, payload.new_unit_snapshot)

	if draw_result.went_to_discard or draw_result.drawn_uuid.is_empty():
		return
	var battle_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	if not is_instance_valid(battle_view):
		return
	var slot_view: PanelContainer = BattlePuppetRegistry.get_slot_view(animator, draw_result.dest_container, draw_result.dest_slot)
	if not is_instance_valid(slot_view):
		return
	for child in slot_view.get_children():
		if child is GachaBallView and not child.is_queued_for_deletion():
			var gv: GachaBallView = child as GachaBallView
			animator._visual_registry[draw_result.drawn_uuid] = gv
			if payload != null and not payload.new_unit_snapshot.is_empty():
				gv.set_visual_state(payload.new_unit_snapshot)
			animator._position_snapshot[draw_result.drawn_uuid] = BattlePuppetRegistry.rect_to_pos_dict(gv.get_global_rect())
			break


static func animate_summon(animator: Node, event: CombatEvent) -> void:
	var payload: CombatPayload = event.visual_payload
	var new_unit_uuid: String = payload.new_unit_uuid
	var old_location: LocationIdentifier = payload.old_unit_location
	var spawn_source_uuid: String = payload.spawn_source_uuid
	var unit_tier: int = payload.unit_tier

	var container_tag: StringName = old_location.container if old_location != null else &""
	var index: int = old_location.index if old_location != null else -1
	var is_inventory_summon: bool = String(container_tag).begins_with("BattleInventoryT")

	var battle_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	var main_node: Node = GameManager.get_main_node()

	var arc_completed: bool = false
	if is_inventory_summon and not spawn_source_uuid.is_empty() and is_instance_valid(main_node):
		var machine_node: Control = main_node.get_node_or_null("%%GachaMachine%d" % unit_tier) as Control
		var source_view: GachaBallView = animator._visual_registry.get(spawn_source_uuid) as GachaBallView
		var start_center: Vector2 = _resolve_item_or_unit_center(animator, spawn_source_uuid, source_view)

		if start_center != Vector2.ZERO and is_instance_valid(machine_node):
			if is_instance_valid(source_view):
				source_view.set_visual_equipped_item_icon(null)
			var end_center: Vector2 = machine_node.get_global_rect().get_center()
			await _toss_capsule_arc(start_center, end_center, payload.new_unit_snapshot)
			Audio.play_sfx("coin_land")
			main_node.animate_machine_inventory_change(unit_tier, 1)
			arc_completed = true
	elif container_tag == &"DiscardPile":
		var source_uuid_to_use: String = spawn_source_uuid if not spawn_source_uuid.is_empty() else event.source_uuid
		var start_center: Vector2 = Vector2.ZERO
		if not source_uuid_to_use.is_empty():
			var source_view: Control = animator._visual_registry.get(source_uuid_to_use) as Control
			if is_instance_valid(source_view) and source_view.is_inside_tree():
				start_center = source_view.global_position + (source_view.size / 2.0)
			else:
				var snap: Dictionary = BattlePuppetRegistry.get_snapshot_position(animator, source_uuid_to_use)
				if not snap.is_empty():
					start_center = snap["center"]

		if start_center == Vector2.ZERO and payload.spawn_source_location != null:
			var slot_node: PanelContainer = BattlePuppetRegistry.get_slot_view(animator, payload.spawn_source_location.container, payload.spawn_source_location.index)
			if is_instance_valid(slot_node):
				start_center = slot_node.get_global_rect().get_center()

		if start_center == Vector2.ZERO and is_instance_valid(battle_view) and is_instance_valid(battle_view.player_lineup):
			start_center = battle_view.player_lineup.get_global_rect().get_center()

		if start_center != Vector2.ZERO:
			await animate_gachaball_to_discard(animator, start_center, payload.new_unit_snapshot)
			arc_completed = true

	if is_inventory_summon or container_tag == &"DiscardPile" or not is_instance_valid(battle_view):
		return

	var slot_view: PanelContainer = BattlePuppetRegistry.get_slot_view(animator, container_tag, index)
	if not is_instance_valid(slot_view):
		return

	var new_view: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	var has_existing_unit: bool = false
	var old_unit_uuid: String = payload.old_unit_uuid
	for child in slot_view.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is GachaBallView:
			if not old_unit_uuid.is_empty() and (child as GachaBallView).get_instance_uuid() == old_unit_uuid:
				continue
			has_existing_unit = true
			break

	if has_existing_unit:
		for child in slot_view.get_children():
			if child is GachaBallView:
				(child as GachaBallView).hide()
				child.queue_free()

	slot_view.add_child(new_view)
	var new_snapshot: Dictionary = payload.new_unit_snapshot
	if new_snapshot.is_empty():
		return

	var new_location := LocationIdentifier.new(container_tag, index)
	new_view.populate(new_location, new_snapshot, false)
	new_view.set_is_enemy(container_tag == &"EnemyLineup", new_snapshot.get("def_id", &""))
	if container_tag == &"EnemyLineup":
		new_view.set_interaction_context(&"INSPECTION_ONLY", new_snapshot.get("category", &"UNIT"), 0)
	if not arc_completed:
		new_view.modulate.a = 0.0
	animator._visual_registry[new_unit_uuid] = new_view
	animator._position_snapshot[new_unit_uuid] = BattlePuppetRegistry.rect_to_pos_dict(slot_view.get_global_rect())

	await animator.get_tree().process_frame
	animator._position_snapshot[new_unit_uuid] = BattlePuppetRegistry.rect_to_pos_dict(new_view.get_global_rect())

	if arc_completed:
		new_view.play_landing_bounce()
	else:
		SignalBus.emit_signal("unit_summon_fade", new_unit_uuid)
		Audio.play_sfx("combat_summon")
		await animator.wait_for_animation_completion("summon_fade", new_unit_uuid)


static func animate_currency_event(animator: Node, event_type: CombatEvent.Type, origin_uuid: String, amount: float) -> void:
	var resolve_holder: bool = (event_type == CombatEvent.Type.TOKEN_SPEND or event_type == CombatEvent.Type.TIMER_BONUS)
	var use_full_snapshot_fallback: bool = (event_type == CombatEvent.Type.TIMER_BONUS)
	var pos: Vector2 = _resolve_currency_origin(animator, origin_uuid, resolve_holder, use_full_snapshot_fallback)
	match event_type:
		CombatEvent.Type.GOLD_GAIN:
			await CurrencyAnimator.animate_gold_gain(int(amount), pos)
		CombatEvent.Type.GOLD_SPEND:
			await CurrencyAnimator.animate_gold_spend(int(amount), pos)
		CombatEvent.Type.TOKEN_GAIN:
			await CurrencyAnimator.animate_token_gain(int(amount), pos)
		CombatEvent.Type.TOKEN_SPEND:
			await CurrencyAnimator.animate_token_spend(int(amount), pos)
		CombatEvent.Type.TIMER_BONUS:
			await CurrencyAnimator.animate_bonus_timer_gain(amount, pos)


static func animate_item_transfer(animator: Node, source_uuid: String, target_uuid: String, payload: CombatPayload) -> void:
	var source_view: GachaBallView = animator._visual_registry.get(source_uuid) as GachaBallView
	var target_view: GachaBallView = animator._visual_registry.get(target_uuid) as GachaBallView
	var item_icon_path: String = payload.item_icon_path

	var old_hp: int = payload.old_hp
	var new_hp: int = payload.new_hp
	var old_pwr: int = payload.old_pwr
	var new_pwr: int = payload.new_pwr
	var hp_diff: int = new_hp - old_hp
	var pwr_diff: int = new_pwr - old_pwr

	var start_pos: Vector2 = _resolve_unit_center(animator, source_uuid, source_view)
	var end_pos: Vector2 = _resolve_unit_center(animator, target_uuid, target_view)

	if start_pos == Vector2.ZERO or end_pos == Vector2.ZERO:
		if is_instance_valid(source_view):
			source_view.set_visual_equipped_item_icon(null)
		if is_instance_valid(target_view):
			var fallback_tex: Texture2D = _resolve_payload_item_texture(animator, payload.item_icon, item_icon_path, "")
			target_view.set_visual_equipped_item_icon(fallback_tex)
			if hp_diff != 0:
				target_view.animate_stat_change(new_hp, hp_diff, "hp")
			if pwr_diff != 0:
				target_view.animate_stat_change(new_pwr, pwr_diff, "pwr")
		return

	var item_texture: Texture2D = _resolve_payload_item_texture(animator, payload.item_icon, item_icon_path, "")
	if not is_instance_valid(item_texture):
		return

	if is_instance_valid(source_view):
		source_view.set_visual_equipped_item_icon(null)

	var target_size: float = 96.0
	var tex_size: Vector2 = item_texture.get_size()
	var scale_factor: float = target_size / maxf(maxf(tex_size.x, tex_size.y), 1.0)

	var flying_icon := Sprite2D.new()
	flying_icon.texture = item_texture
	flying_icon.centered = true
	flying_icon.scale = Vector2(scale_factor, scale_factor)
	WindowManager.get_vfx_layer().add_child(flying_icon)

	Audio.play_sfx("unit_toss")
	var tween: Tween = ArcTossAnimator.toss_parabolic(flying_icon, start_pos, end_pos, {
		"arc_height": 250.0,
		"duration": 0.6,
		"scale_duration": true,
	})
	await tween.finished
	flying_icon.queue_free()

	Audio.play_sfx("token_land")
	if is_instance_valid(target_view):
		target_view.set_visual_equipped_item_icon(item_texture)
		target_view.play_landing_bounce()
		if hp_diff != 0:
			target_view.animate_stat_change(new_hp, hp_diff, "hp")
		if pwr_diff != 0:
			target_view.animate_stat_change(new_pwr, pwr_diff, "pwr")

	if not payload.replaced_item_uuid.is_empty():
		var discard_start_pos: Vector2 = _resolve_item_or_unit_center(animator, target_uuid, target_view)
		var replaced_texture: Texture2D = _resolve_payload_item_texture(
			animator, payload.replaced_item_icon, payload.replaced_item_icon_path, payload.replaced_item_uuid
		)
		if discard_start_pos != Vector2.ZERO and is_instance_valid(replaced_texture):
			await animate_gachaball_to_discard(animator, discard_start_pos, {
				"uuid": payload.replaced_item_uuid,
				"category": "ITEM",
				"icon": replaced_texture
			})


static func animate_incubator_move(animator: Node, event: CombatEvent) -> void:
	if ActionQueue.is_headless_mode():
		return
	var payload: CombatPayload = event.visual_payload
	var source_view: GachaBallView = animator._visual_registry.get(event.source_uuid) as GachaBallView
	var destination: SlotView = BattlePuppetRegistry.get_slot_view(animator, payload.container_tag, payload.slot_index) as SlotView
	assert(source_view != null and destination != null, "Incubator animation requires both board slots")

	var entering_shelf: bool = payload.container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
	var shelf_location: LocationIdentifier = destination._location if entering_shelf else payload.old_unit_location
	var capsule_data: Dictionary = payload.new_unit_snapshot if entering_shelf else animator._start_snapshot[event.source_uuid]
	var start_center: Vector2 = source_view.get_global_rect().get_center()
	var end_center: Vector2 = destination.get_global_rect().get_center()
	if entering_shelf:
		hide_item_source_view(animator, payload.item_uuid)
		end_center = destination.get_global_transform() * GachaBallView.shelf_capsule_center(destination.size)
	else:
		start_center = source_view.get_global_transform() * source_view.get_capsule_rect().get_center()

	var capsule: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	WindowManager.get_vfx_layer().add_child(capsule)
	capsule.set_size_scale(2.0)
	capsule.populate(shelf_location, capsule_data, false)
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center_offset: Vector2 = capsule.get_capsule_rect().get_center()
	capsule.pivot_offset = center_offset
	capsule.global_position = start_center - center_offset
	if entering_shelf:
		capsule.modulate.a = 0.0
		source_view.pivot_offset = source_view.size * 0.5
		var close_duration: float = AnimationConstants.scaled(0.15)
		var closing: Tween = capsule.create_tween().set_parallel(true)
		closing.tween_property(source_view, "scale", source_view.scale * 0.72, close_duration)
		closing.tween_property(source_view, "modulate:a", 0.0, close_duration)
		closing.tween_property(capsule, "modulate:a", 1.0, close_duration)
		await closing.finished
	source_view.hide()
	source_view.queue_free()
	var flight: Tween = capsule.create_tween()
	flight.tween_method(func(t: float) -> void:
		capsule.global_position = start_center.lerp(end_center, t) - center_offset - Vector2(0.0, 52.0 * sin(t * PI))
	, 0.0, 1.0, AnimationConstants.scaled(0.38))
	await flight.finished
	capsule.queue_free()

	var moved_view: GachaBallView = destination.set_content(payload.new_unit_snapshot)
	BattlePuppetRegistry.register_dynamic_position(animator, event.source_uuid, moved_view)
	if not entering_shelf:
		VFXFactory.spawn_capsule_pop_vfx(end_center, animator, 1.5, Vector2.ZERO)
	moved_view.play_landing_bounce()


static func animate_item_discard(animator: Node, source_uuid: String, payload: CombatPayload) -> void:
	var source_view: GachaBallView = animator._visual_registry.get(source_uuid) as GachaBallView
	var start_pos: Vector2 = _resolve_item_or_unit_center(animator, source_uuid, source_view)
	if start_pos == Vector2.ZERO:
		return

	var item_texture: Texture2D = _resolve_payload_item_texture(animator, payload.item_icon, payload.item_icon_path, payload.item_uuid)
	if not is_instance_valid(item_texture):
		return

	if is_instance_valid(source_view):
		source_view.set_visual_equipped_item_icon(null)

	await animate_gachaball_to_discard(animator, start_pos, {
		"uuid": payload.item_uuid,
		"category": "ITEM",
		"icon": item_texture
	})


static func animate_gachaball_to_discard(animator: Node, start_pos: Vector2, capsule_snapshot: Dictionary) -> void:
	if start_pos == Vector2.ZERO:
		return
	var battle_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	var discard_btn: Control = battle_view.discard_pile_button if (is_instance_valid(battle_view) and "discard_pile_button" in battle_view) else null
	var end_pos: Vector2 = discard_btn.get_global_rect().get_center() if (is_instance_valid(discard_btn) and discard_btn.is_inside_tree()) else Vector2(1820.0, 950.0)

	await _toss_capsule_arc(start_pos, end_pos, capsule_snapshot)
	Audio.play_sfx("coin_land")
	if is_instance_valid(battle_view):
		battle_view.animate_discard_pile_arrival(1)


static func animate_player_death_departure(animator: Node, dead_uuid: String, death_pos: Vector2, payload: CombatPayload) -> void:
	var is_player: bool = false
	if payload is CombatPayload:
		is_player = payload.is_player or (payload.container_tag == &"PlayerLineup" or payload.container_tag == &"PlayerShelf")
	if not is_player and animator._start_snapshot.has(dead_uuid):
		var snap_data: Variant = animator._start_snapshot.get(dead_uuid, {})
		if snap_data is Dictionary and (snap_data.get("container_tag") == &"PlayerLineup" or snap_data.get("container_tag") == &"PlayerShelf"):
			is_player = true

	if not is_player or death_pos == Vector2.ZERO:
		return

	var unit_snap: Dictionary = {}
	if payload is CombatPayload and not payload.unit_snapshot.is_empty():
		unit_snap = payload.unit_snapshot.duplicate(true)
	elif animator._start_snapshot.has(dead_uuid):
		var st: Dictionary = animator._start_snapshot[dead_uuid]
		unit_snap = {
			"uuid": dead_uuid,
			"category": st.get("category", "UNIT"),
			"icon": st.get("icon", null),
			"tier": st.get("tier", 0),
			"def_id": st.get("def_id", "")
		}
	if not unit_snap.is_empty():
		await animate_gachaball_to_discard(animator, death_pos, unit_snap)

	var equipped_items: Array = payload.equipped_items if (payload is CombatPayload and not payload.equipped_items.is_empty()) else []
	for item_data in equipped_items:
		if item_data is Dictionary:
			var item_snap: Dictionary = {
				"uuid": item_data.get("uuid", ""),
				"category": "ITEM",
				"icon": item_data.get("icon", null),
				"tier": item_data.get("tier", 0),
				"def_id": item_data.get("def_id", "")
			}
			if item_snap["icon"] == null and not String(item_data.get("def_id", "")).is_empty():
				var idef: Resource = Database.get_definition(item_data.get("def_id"))
				if is_instance_valid(idef) and "icon" in idef:
					item_snap["icon"] = idef.icon
			await animate_gachaball_to_discard(animator, death_pos, item_snap)


static func animate_item_equip(animator: Node, target_uuid: String, payload: CombatPayload) -> void:
	if target_uuid.is_empty():
		return
	var target_view: GachaBallView = animator._visual_registry.get(target_uuid) as GachaBallView
	if not is_instance_valid(target_view):
		return

	if not payload.item_uuid.is_empty():
		hide_item_source_view(animator, payload.item_uuid)

	var item_texture: Texture2D = _resolve_payload_item_texture(animator, payload.item_icon, payload.item_icon_path, payload.item_uuid)
	if is_instance_valid(item_texture):
		target_view.set_visual_equipped_item_icon(item_texture)

	Audio.play_sfx("coin_land")
	target_view.play_landing_bounce()
	await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.15)).timeout


static func hide_item_source_view(animator: Node, item_uuid: String) -> void:
	if item_uuid.is_empty():
		return
	var views_to_hide: Array[Node] = []

	if animator._visual_registry.has(item_uuid):
		var reg_view: Node = animator._visual_registry[item_uuid] as Node
		if is_instance_valid(reg_view):
			views_to_hide.append(reg_view)
		animator._visual_registry.erase(item_uuid)

	for node in animator.get_tree().get_nodes_in_group("gachaball_view"):
		if node is GachaBallView and is_instance_valid(node) and not node.is_queued_for_deletion():
			if (node as GachaBallView).get_instance_uuid() == item_uuid and not (node in views_to_hide):
				views_to_hide.append(node)

	for node in animator.get_tree().get_nodes_in_group("physics_gacha_ball"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			if "instance_uuid" in node and node.instance_uuid == item_uuid and not (node in views_to_hide):
				views_to_hide.append(node)

	for view: Node in views_to_hide:
		if is_instance_valid(view):
			if view is CanvasItem:
				(view as CanvasItem).visible = false
				(view as CanvasItem).modulate.a = 0.0
			view.queue_free()


static func _toss_capsule_arc(start_pos: Vector2, end_pos: Vector2, capsule_snapshot: Dictionary) -> void:
	var anim_capsule: GachaBallView = GachaBallViewScene.instantiate() as GachaBallView
	WindowManager.get_vfx_layer().add_child(anim_capsule)
	anim_capsule.anchors_preset = Control.PRESET_TOP_LEFT
	anim_capsule.set_size_scale(1.0)
	anim_capsule.force_inventory_mode = true
	anim_capsule.populate(null, capsule_snapshot)

	var initial_scale: float = 0.3
	anim_capsule.scale = Vector2(initial_scale, initial_scale)
	var center_offset: Vector2 = anim_capsule.get_capsule_rect().get_center()
	anim_capsule.pivot_offset = center_offset
	anim_capsule.global_position = start_pos - center_offset

	var tween: Tween = ArcTossAnimator.toss_parabolic(anim_capsule, start_pos, end_pos, {
		"arc_height": 500.0,
		"duration": 0.7,
		"scale_duration": true,
		"start_scale": initial_scale,
		"end_scale": 1.0,
		"scale_curve": &"ramp_10x",
		"pivot": center_offset,
	})
	await tween.finished
	anim_capsule.queue_free()


static func _resolve_currency_origin(animator: Node, origin_uuid: String, resolve_holder: bool, use_full_snapshot_fallback: bool) -> Vector2:
	var resolved_uuid: String = origin_uuid
	if resolve_holder and not resolved_uuid.is_empty() and not animator._position_snapshot.has(resolved_uuid) and not animator._visual_registry.has(resolved_uuid):
		resolved_uuid = BattlePuppetRegistry.resolve_equipped_holder_uuid(animator, resolved_uuid)

	var pos_data: Dictionary = BattlePuppetRegistry.get_snapshot_position(animator, resolved_uuid) if use_full_snapshot_fallback else animator._position_snapshot.get(resolved_uuid, {})
	if not pos_data.is_empty():
		return pos_data["center"]

	var view: Control = animator._visual_registry.get(resolved_uuid) as Control
	if not is_instance_valid(view) or not view.is_inside_tree():
		view = BattlePuppetRegistry.find_trinket_view(animator, resolved_uuid, &"", false)
	if is_instance_valid(view) and view.is_inside_tree():
		return view.get_global_rect().get_center()

	return animator.get_viewport().get_visible_rect().size / 2.0


static func _resolve_unit_center(animator: Node, uuid: String, view: Control) -> Vector2:
	if is_instance_valid(view) and view.is_inside_tree():
		return view.global_position + (view.size / 2.0)
	var snap: Dictionary = BattlePuppetRegistry.get_snapshot_position(animator, uuid)
	return snap["center"] if not snap.is_empty() else Vector2.ZERO


static func _resolve_item_or_unit_center(animator: Node, uuid: String, view: GachaBallView) -> Vector2:
	if is_instance_valid(view) and view.is_inside_tree():
		if is_instance_valid(view.equipped_item_icon_rect) and view.equipped_item_icon_rect.is_inside_tree():
			return view.equipped_item_icon_rect.get_global_rect().get_center()
		return view.global_position + (view.size / 2.0)
	var snap: Dictionary = BattlePuppetRegistry.get_snapshot_position(animator, uuid)
	return snap["center"] if not snap.is_empty() else Vector2.ZERO


static func _resolve_payload_item_texture(animator: Node, icon: Texture2D, icon_path: String, item_uuid: String) -> Texture2D:
	if is_instance_valid(icon):
		return icon
	if not icon_path.is_empty():
		var loaded: Texture2D = load(icon_path) as Texture2D
		if is_instance_valid(loaded):
			return loaded
	if not item_uuid.is_empty():
		return BattlePuppetRegistry.resolve_item_texture_from_snapshot(animator, item_uuid)
	return null

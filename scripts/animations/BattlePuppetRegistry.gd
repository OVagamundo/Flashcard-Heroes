# res://scripts/animations/BattlePuppetRegistry.gd
class_name BattlePuppetRegistry
extends RefCounted

## Manages VCR puppet registration, board slot lookups, screen-space position
## snapshots, trinket view lookup/activation, and snapshot-first item/holder
## resolution for BattleAnimator.

const C = preload("res://scripts/Constants.gd")


static func rect_to_pos_dict(rect: Rect2) -> Dictionary:
	return {
		"position": rect.position,
		"size": rect.size,
		"center": Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0)
	}


static func register_all_puppets(animator: Node, start_snapshot: Dictionary) -> void:
	animator._visual_registry.clear()
	animator._position_snapshot.clear()

	var battle_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	if not is_instance_valid(battle_view):
		return

	for uuid in start_snapshot:
		var snapshot_data: Variant = start_snapshot[uuid]
		if not (snapshot_data is Dictionary):
			continue
		var snap_dict: Dictionary = snapshot_data as Dictionary
		if snap_dict.get("container_tag") == C.CONTAINER_EQUIPPED_ITEM:
			continue
		if not snap_dict.has("container_tag") or not snap_dict.has("slot_index"):
			continue

		var container_tag: StringName = snap_dict.get("container_tag")
		var index: int = int(snap_dict.get("slot_index", -1))
		if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER:
			var banner_view: EnemyBannerView = battle_view.enemy_banner_view
			assert(banner_view.get_instance_uuid() == uuid, "Banner view does not match the combat snapshot")
			register_dynamic_position(animator, uuid, banner_view)
			continue

		var lineup_container: HBoxContainer = _resolve_container_hbox(animator, battle_view, container_tag)
		var gacha_view: GachaBallView = null
		var slot_view_ref: Control = null
		if is_instance_valid(lineup_container) and index >= 0 and index < lineup_container.get_child_count():
			var slot_view: Node = lineup_container.get_child(index)
			if is_instance_valid(slot_view):
				slot_view_ref = slot_view as Control
				gacha_view = _find_view_in_slot(slot_view, String(uuid))

		if not is_instance_valid(gacha_view):
			for node in animator.get_tree().get_nodes_in_group("gachaball_view"):
				if node is GachaBallView and not node.is_queued_for_deletion():
					if (node as GachaBallView).get_instance_uuid() == uuid:
						gacha_view = node as GachaBallView
						break

		if is_instance_valid(gacha_view):
			animator._visual_registry[uuid] = gacha_view
			animator._position_snapshot[uuid] = rect_to_pos_dict(gacha_view.get_global_rect())
			snap_dict["uuid"] = uuid
			gacha_view.set_visual_state(snap_dict)
		elif is_instance_valid(slot_view_ref):
			animator._position_snapshot[uuid] = rect_to_pos_dict(slot_view_ref.get_global_rect())

	# Scan EffectsLayer and VFXLayer for in-flight views (e.g. Gacha Draws)
	var layers_to_scan: Array[Node] = []
	var effects_layer: Node = animator.get_tree().get_first_node_in_group("effects_layer")
	if is_instance_valid(effects_layer):
		layers_to_scan.append(effects_layer)
	var vfx_layer: CanvasLayer = WindowManager.get_vfx_layer()
	if is_instance_valid(vfx_layer) and not (vfx_layer in layers_to_scan):
		layers_to_scan.append(vfx_layer)
	for layer: Node in layers_to_scan:
		for child in layer.get_children():
			if child is GachaBallView:
				var flying_view: GachaBallView = child as GachaBallView
				var flying_uuid: String = flying_view.get_instance_uuid()
				if not flying_uuid.is_empty():
					animator._visual_registry[flying_uuid] = flying_view
					animator._position_snapshot[flying_uuid] = rect_to_pos_dict(flying_view.get_global_rect())


static func get_slot_view(animator: Node, container_tag: StringName, slot_index: int) -> PanelContainer:
	if slot_index < 0:
		return null
	var battle_view: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	if not is_instance_valid(battle_view):
		return null

	var lineup_container: HBoxContainer = null
	match container_tag:
		&"PlayerLineup":
			lineup_container = battle_view.player_lineup
		&"EnemyLineup":
			lineup_container = battle_view.enemy_lineup
		&"PlayerShelf":
			lineup_container = battle_view.player_shelf
		_:
			return null

	if not is_instance_valid(lineup_container) or slot_index >= lineup_container.get_child_count():
		return null
	return lineup_container.get_child(slot_index) as PanelContainer


static func get_snapshot_position(animator: Node, uuid: String) -> Dictionary:
	if animator._position_snapshot.has(uuid):
		return animator._position_snapshot[uuid]

	var trinket_view: GachaBallView = find_trinket_view(animator, uuid, &"", false)
	if not is_instance_valid(trinket_view):
		trinket_view = find_trinket_view(animator, uuid, &"", true)
	if not is_instance_valid(trinket_view):
		trinket_view = find_trinket_view(animator, "", StringName(uuid), false)
	if not is_instance_valid(trinket_view):
		trinket_view = find_trinket_view(animator, "", StringName(uuid), true)

	if is_instance_valid(trinket_view):
		var snap: Dictionary = rect_to_pos_dict(trinket_view.get_global_rect())
		animator._position_snapshot[uuid] = snap
		return snap

	# Unit fallback 1: Check _start_snapshot slot
	if animator._start_snapshot.has(uuid):
		var snap_dict: Variant = animator._start_snapshot[uuid]
		if snap_dict is Dictionary and snap_dict.has("container_tag") and snap_dict.has("slot_index"):
			var slot_snap: Dictionary = _capture_slot_or_child_rect(animator, snap_dict.get("container_tag"), int(snap_dict.get("slot_index", -1)))
			if not slot_snap.is_empty():
				animator._position_snapshot[uuid] = slot_snap
				return slot_snap

	# Unit fallback 1b: Query VisualSnapshotStore for current VCR frame location
	if animator._snapshot_store.has_uuid(uuid):
		var store_snap: Dictionary = animator._snapshot_store.get_snapshot_by_uuid(uuid)
		if store_snap.has("container_tag") and store_snap.has("slot_index"):
			var store_slot_snap: Dictionary = _capture_slot_or_child_rect(animator, store_snap.get("container_tag"), int(store_snap.get("slot_index", -1)))
			if not store_slot_snap.is_empty():
				animator._position_snapshot[uuid] = store_slot_snap
				return store_slot_snap

	# Unit fallback 2: Query BattleManager for location or origin_uuid
	var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
	if not is_instance_valid(bm):
		bm = animator.get_tree().get_first_node_in_group("battle_manager") as BattleManager
	var inst: GachaBallInstance = null
	if is_instance_valid(bm):
		inst = bm.get_instance(uuid)
		if is_instance_valid(inst):
			if not inst.origin_uuid.is_empty() and animator._position_snapshot.has(inst.origin_uuid):
				var origin_snap: Dictionary = animator._position_snapshot[inst.origin_uuid]
				animator._position_snapshot[uuid] = origin_snap
				return origin_snap
			var loc: LocationIdentifier = inst.get_location()
			if is_instance_valid(loc):
				var loc_snap: Dictionary = _capture_slot_or_child_rect(animator, loc.container, loc.index)
				if not loc_snap.is_empty():
					animator._position_snapshot[uuid] = loc_snap
					return loc_snap

	# Unit fallback 3: Search all gachaball_view nodes in tree
	for node in animator.get_tree().get_nodes_in_group("gachaball_view"):
		if node is GachaBallView and not node.is_queued_for_deletion():
			var gv: GachaBallView = node as GachaBallView
			var v_uuid: String = gv.get_instance_uuid()
			if v_uuid == uuid or (is_instance_valid(inst) and v_uuid == inst.origin_uuid):
				var view_snap: Dictionary = rect_to_pos_dict(gv.get_global_rect())
				animator._position_snapshot[uuid] = view_snap
				return view_snap

	return {}


static func get_live_position(animator: Node, uuid: String) -> Dictionary:
	var view: Control = animator._visual_registry.get(uuid) as Control
	if is_instance_valid(view) and view.is_inside_tree():
		return rect_to_pos_dict(view.get_global_rect())
	return get_snapshot_position(animator, uuid)


static func register_dynamic_position(animator: Node, uuid: String, view: Control) -> void:
	if is_instance_valid(view):
		animator._position_snapshot[uuid] = rect_to_pos_dict(view.get_global_rect())
		animator._visual_registry[uuid] = view


static func play_trinket_activations_for_event(animator: Node, event: CombatEvent) -> void:
	for activation in event.trinket_activations:
		var act_visual_uuid: String = activation.visual_uuid
		play_trinket_activation(animator, act_visual_uuid, activation.definition_id, activation.is_enemy)
		if event.visual_payload != null:
			var event_source_uuid: String = event.visual_payload.source_uuid
			if not event_source_uuid.is_empty() and event_source_uuid != act_visual_uuid:
				var existing_view: Variant = animator._visual_registry.get(event_source_uuid)
				var is_existing_unit: bool = existing_view is GachaBallView and not (existing_view as GachaBallView).is_in_group("trinket_view")
				if not is_existing_unit:
					var snap: Dictionary = get_snapshot_position(animator, act_visual_uuid)
					if not snap.is_empty():
						animator._position_snapshot[event_source_uuid] = snap
						var view_ref: Variant = animator._visual_registry.get(act_visual_uuid)
						if is_instance_valid(view_ref):
							animator._visual_registry[event_source_uuid] = view_ref


static func play_trinket_activation(animator: Node, visual_uuid: String, trinket_definition_id: StringName = &"", is_enemy_trinket: bool = false) -> void:
	if is_enemy_trinket:
		var banner_view: EnemyBannerView = animator.get_tree().get_first_node_in_group("enemy_banner_view") as EnemyBannerView
		if banner_view != null and banner_view.visible and (banner_view.get_instance_uuid() == visual_uuid or banner_view.get_definition_id() == trinket_definition_id):
			register_dynamic_position(animator, banner_view.get_instance_uuid(), banner_view)
			banner_view.play_activation()
			return
	var view: GachaBallView = find_trinket_view(animator, visual_uuid, trinket_definition_id, is_enemy_trinket)
	if is_instance_valid(view):
		if not visual_uuid.is_empty():
			register_dynamic_position(animator, visual_uuid, view)
		view.play_trinket_activation_bounce()


static func find_trinket_view(animator: Node, visual_uuid: String, trinket_definition_id: StringName, is_enemy_trinket: bool) -> GachaBallView:
	var trinket_views: Array[GachaBallView] = _get_trinket_views_from_tree(animator)
	if not visual_uuid.is_empty():
		for view: GachaBallView in trinket_views:
			var v_uuid: String = view.get_instance_uuid()
			if v_uuid == visual_uuid or visual_uuid.begins_with(v_uuid + "_"):
				return view

	if not visual_uuid.is_empty():
		var snap_origin_uuid: String = ""
		var snap_def_id: StringName = &""
		var snap_entry: Dictionary = animator._snapshot_store.get_snapshot_by_uuid(visual_uuid)
		if not snap_entry.is_empty():
			snap_origin_uuid = String(snap_entry.get("origin_uuid", ""))
			snap_def_id = StringName(snap_entry.get("definition_id", &""))
		elif not animator._snapshot_store.is_active():
			var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
			if is_instance_valid(bm):
				var inst: GachaBallInstance = bm.get_instance(visual_uuid)
				if is_instance_valid(inst):
					snap_origin_uuid = inst.origin_uuid
					snap_def_id = inst.definition_id
		if not snap_origin_uuid.is_empty():
			for view: GachaBallView in trinket_views:
				if view.get_instance_uuid() == snap_origin_uuid:
					return view
		if trinket_definition_id == &"" and snap_def_id != &"":
			trinket_definition_id = snap_def_id

	if trinket_definition_id != &"":
		for view: GachaBallView in trinket_views:
			var view_def_id: StringName = view.get_definition_id()
			var view_is_enemy: bool = is_instance_valid(view._location) and view._location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
			if view_def_id == trinket_definition_id and view_is_enemy == is_enemy_trinket:
				return view
	return null


static func resolve_equipped_holder_uuid(animator: Node, uuid: String) -> String:
	if uuid.is_empty():
		return uuid
	var snap_entry: Dictionary = animator._snapshot_store.get_snapshot_by_uuid(uuid)
	if not snap_entry.is_empty():
		var holder: String = String(snap_entry.get("equipped_on_uuid", ""))
		return holder if not holder.is_empty() else uuid
	if animator._snapshot_store.is_active():
		return uuid
	var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
	if is_instance_valid(bm):
		var inst: GachaBallInstance = bm.get_instance_by_uuid(uuid)
		if is_instance_valid(inst) and not inst.equipped_on_uuid.is_empty():
			return inst.equipped_on_uuid
	return uuid


static func resolve_item_texture_from_snapshot(animator: Node, item_uuid: String) -> Texture2D:
	if item_uuid.is_empty():
		return null
	var snap_entry: Dictionary = animator._snapshot_store.get_snapshot_by_uuid(item_uuid)
	if not snap_entry.is_empty():
		var snap_icon: Variant = snap_entry.get("icon", null)
		if snap_icon is Texture2D:
			return snap_icon as Texture2D
		var def_id: StringName = StringName(snap_entry.get("definition_id", &""))
		if def_id != &"":
			var def: Resource = Database.get_definition(def_id)
			if def is GachaBallDefinition and is_instance_valid((def as GachaBallDefinition).icon):
				return (def as GachaBallDefinition).icon
		return null
	if animator._snapshot_store.is_active():
		return null
	var bm: BattleManager = GameManager.get_battle_manager() as BattleManager
	if is_instance_valid(bm):
		var item_inst: GachaBallInstance = bm.get_instance(item_uuid)
		if is_instance_valid(item_inst):
			var idef: Resource = item_inst.get_definition()
			if idef is GachaBallDefinition and is_instance_valid((idef as GachaBallDefinition).icon):
				return (idef as GachaBallDefinition).icon
	return null


static func _resolve_container_hbox(animator: Node, battle_view: BattleView, container_tag: StringName) -> HBoxContainer:
	match container_tag:
		&"PlayerLineup":
			return battle_view.player_lineup
		&"EnemyLineup":
			return battle_view.enemy_lineup
		&"PlayerShelf":
			return battle_view.player_shelf
		&"EnemyTrinkets":
			return battle_view.enemy_trinket_bar
		&"PlayerTrinkets":
			var main_node: Node = animator.get_tree().get_first_node_in_group("main")
			if is_instance_valid(main_node) and "player_trinket_bar" in main_node:
				return main_node.player_trinket_bar
	return null


static func _find_view_in_slot(slot_view: Node, uuid: String) -> GachaBallView:
	var fallback_view: GachaBallView = null
	for child in slot_view.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is GachaBallView:
			var candidate: GachaBallView = child as GachaBallView
			if not is_instance_valid(fallback_view):
				fallback_view = candidate
			if candidate.get_instance_uuid() == uuid:
				return candidate
	return fallback_view


static func _capture_slot_or_child_rect(animator: Node, container_tag: StringName, slot_index: int) -> Dictionary:
	var slot_node: PanelContainer = get_slot_view(animator, container_tag, slot_index)
	if not is_instance_valid(slot_node):
		return {}
	var target_rect: Rect2 = slot_node.get_global_rect()
	for child in slot_node.get_children():
		if child is GachaBallView and not child.is_queued_for_deletion():
			target_rect = (child as GachaBallView).get_global_rect()
			break
	return rect_to_pos_dict(target_rect)


static func _get_trinket_views_from_tree(animator: Node) -> Array[GachaBallView]:
	var result: Array[GachaBallView] = []
	for node in animator.get_tree().get_nodes_in_group("trinket_view"):
		if node is GachaBallView and is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree() and (node as GachaBallView).visible:
			result.append(node as GachaBallView)
	return result

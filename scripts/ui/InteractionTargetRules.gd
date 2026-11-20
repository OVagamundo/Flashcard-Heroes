# res://scripts/ui/InteractionTargetRules.gd
class_name InteractionTargetRules
extends RefCounted

## Pure interaction-target rules, container functional-group mapping,
## and instance-id view lookup helpers for GlobalInteractionRouter.

const C = preload("res://scripts/Constants.gd")


static func get_container_functional_group(container_name: StringName) -> StringName:
	if container_name in [&"PlayerLineup", &"PlayerShelf"]:
		return &"BattleBoard"
	if container_name.begins_with("RunInventoryT") or container_name.begins_with("BattleInventoryT"):
		return &"InventoryGrid"
	if container_name in [&"Rewards", &"Shop"]:
		return &"SelectionOnly"
	if container_name == C.CONTAINER_EQUIPPED_ITEM:
		return &"EquippedGrid"
	if container_name in [&"DiscardPile", &"PlayerTrinkets", &"EnemyTrinkets", &"EnemyBanner", &"EnemyLineup", &"EnemyShelf"]:
		return &"InspectionOnly"
	return &"Unknown"


static func is_inventory_tier_change(selection: InteractionContext, new_context: InteractionContext) -> bool:
	if selection == null or new_context == null or selection.location == null or new_context.location == null:
		return false
	var selection_container: StringName = selection.location.container
	var new_container: StringName = new_context.location.container
	if selection_container.begins_with("RunInventoryT") and new_container.begins_with("RunInventoryT"):
		return selection_container != new_container
	if selection_container.begins_with("BattleInventoryT") and new_container.begins_with("BattleInventoryT"):
		return selection_container != new_container
	return false


static func is_valid_action_target(selection: InteractionContext, target: InteractionContext) -> bool:
	if selection == null or target == null or selection.location == null or target.location == null:
		return false
	var selection_group: StringName = get_container_functional_group(selection.location.container)
	var target_group: StringName = get_container_functional_group(target.location.container)

	if selection_group == target_group:
		return true
	if selection_group == &"InventoryGrid" and target_group == &"EquippedGrid":
		return true
	if selection_group == &"InventoryGrid" and target_group == &"BattleBoard":
		return true
	if selection.location.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and target.location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return selection.entity_type == C.CATEGORY_CONSUMABLE
	if selection_group == &"InventoryGrid" and target_group == &"InspectionOnly":
		return selection.entity_type == &"CONSUMABLE"
	return false


static func is_valid_move_target(selection: InteractionContext, target: InteractionContext) -> bool:
	if selection == null or target == null or selection.location == null or target.location == null:
		return false
	var selection_group: StringName = get_container_functional_group(selection.location.container)
	var target_group: StringName = get_container_functional_group(target.location.container)

	if selection_group == target_group:
		return true
	if selection_group == &"InventoryGrid" and target_group == &"EquippedGrid":
		return true
	return false


static func is_unit_inspection_window_id(window_id: int) -> bool:
	if window_id <= 0:
		return false
	var node: Object = instance_from_id(window_id)
	if not is_instance_valid(node) or not (node is Control):
		return false
	var ctrl: Control = node as Control
	if ctrl.name.findn("UnitInspection") != -1:
		return true
	var script_res: Script = ctrl.get_script() as Script
	return is_instance_valid(script_res) and script_res.resource_path.findn("UnitInspection") != -1


static func find_view_by_instance_id(instance_id: int, tree_root: Node) -> Control:
	if instance_id <= 0:
		return null
	var obj: Object = instance_from_id(instance_id)
	if not is_instance_valid(obj):
		return null
	if obj is Control:
		return obj as Control
	if obj is Node:
		var n: Node = obj as Node
		while is_instance_valid(n) and not (n is Control) and n != tree_root:
			n = n.get_parent()
		if n is Control:
			return n as Control
	return null

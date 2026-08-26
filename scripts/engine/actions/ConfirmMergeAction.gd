extends GameAction
class_name ConfirmMergeAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier
var recipe_id: StringName

func _init(p_source_loc: LocationIdentifier, p_target_loc: LocationIdentifier, p_recipe_id: StringName) -> void:
	source_loc = p_source_loc
	target_loc = p_target_loc
	recipe_id = p_recipe_id

func is_valid() -> bool:
	if source_loc == null or target_loc == null: return false
	
	var source_instance = GameManager.get_instance_from_location(source_loc)
	var target_instance = GameManager.get_instance_from_location(target_loc)
	if source_instance == null or target_instance == null: return false
	
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return false
	
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, data_owner.get_all_instances())
	if recipe == null or recipe.id != recipe_id: return false
	
	if MergeManager.is_merge_encounter_active() and is_instance_valid(GameManager.run_state):
		if GameManager.run_state.gold < GameManager.run_state.merge_encounter_cost:
			return false
			
	return true

func execute() -> void:
	if InventoryManager.has_method("perform_merge"):
		InventoryManager.perform_merge(source_loc, target_loc, recipe_id)
		
	if not yields_for_visuals():
		finish_visuals()

func yields_for_visuals() -> bool:
	# Merge triggers a merge_animation_requested signal which is long-running
	# ActionQueue expects blocking actions to call finish_visuals when they are done.
	# Currently merge animation logic calls inventory_action_completed, not finish_visuals on the action.
	# In a fully migrated system, the animation system would hold a ref to the action and call finish_visuals.
	# For now, to match existing flow while moving mutation to ActionQueue, we return false
	# because ActionQueue is mostly concerned with blocking inputs until the queue is empty, and
	# the merge animation lock prevents interaction anyway.
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "ConfirmMergeAction",
		"source_loc": source_loc.to_dict() if is_instance_valid(source_loc) and source_loc.has_method("to_dict") else {},
		"target_loc": target_loc.to_dict() if is_instance_valid(target_loc) and target_loc.has_method("to_dict") else {},
		"recipe_id": recipe_id
	}

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return GameManager.get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

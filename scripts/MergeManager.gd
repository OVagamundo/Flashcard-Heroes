# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to handle all merge logic calculations.

func calculate_merge_result(instance_a: GachaBallInstance, instance_b: GachaBallInstance, inventory_context: Dictionary) -> Dictionary:
	if not instance_a or not instance_b:
		printerr("MergeManager: Attempted merge with a null instance.")
		return {}
		
	var recipe: MergeRecipe = find_recipe(instance_a.definition_id, instance_b.definition_id)
	if not recipe:
		return {}

	# --- Merge is valid, proceed with calculation ---
	var result_definition: GachaBallDefinition = Database.get_definition(recipe.result_id)
	if not result_definition:
		printerr("MergeManager: Result ID from recipe not found in Database: ", recipe.result_id)
		return {}
		
	# 1. Create the new result GachaBallInstance.
	var merged_instance := GachaBallInstance.new()
	merged_instance.initialize(result_definition)
	
	# 2. Gather all equipped item INSTANCES from parents into a temporary list.
	var all_parent_items: Array[GachaBallInstance] = []
	all_parent_items.append_array(_get_equipped_item_instances(instance_a, inventory_context))
	all_parent_items.append_array(_get_equipped_item_instances(instance_b, inventory_context))

	# 3. Equip the gathered items onto the new unit by copying their UUIDs.
	for i in range(min(all_parent_items.size(), merged_instance.equipped_item_uuids.size())):
		var item_to_equip: GachaBallInstance = all_parent_items[i]
		merged_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid
		
	# 4. Create the list of all instances that need to be removed from inventories.
	var parents_to_remove: Array[GachaBallInstance] = [instance_a, instance_b]

	print("Merge calculated. Created: %s. Parents to remove: %s" % [merged_instance.definition_id, parents_to_remove.size()])
	return {"merged_instance": merged_instance, "parents_to_remove": parents_to_remove}


func find_recipe(id_a: StringName, id_b: StringName) -> MergeRecipe:
	for recipe_key in Database.recipes:
		var recipe: MergeRecipe = Database.recipes[recipe_key]
		
		if recipe.is_self_merge:
			if id_a == recipe.ingredient_a_id and id_a == id_b:
				return recipe
		else: # Check for A+B or B+A
			if (id_a == recipe.ingredient_a_id and id_b == recipe.ingredient_b_id) or \
			   (id_a == recipe.ingredient_b_id and id_b == recipe.ingredient_a_id):
				return recipe
				
	return null


func _get_equipped_item_instances(unit_instance: GachaBallInstance, inventory_context: Dictionary) -> Array[GachaBallInstance]:
	var equipped_items: Array[GachaBallInstance] = []
	if not is_instance_valid(unit_instance) or unit_instance.equipped_item_uuids.is_empty():
		return equipped_items

	# Determine the context (run vs. battle)
	var run_instances = inventory_context.get("run_instances")
	var is_battle_context = inventory_context.has("battle_inventory")

	for item_uuid in unit_instance.equipped_item_uuids:
		if item_uuid.is_empty():
			continue

		var item_instance: GachaBallInstance = null
		if run_instances:
			# In run context, we can look up directly from the master instance list.
			item_instance = run_instances.get(item_uuid)
		elif is_battle_context:
			# In battle context, we need to search the battle manager's data.
			var bm = get_tree().get_first_node_in_group("battle_manager")
			if is_instance_valid(bm):
				item_instance = bm.get_instance_from_uuid(item_uuid)

		if is_instance_valid(item_instance):
			equipped_items.push_back(item_instance)

	return equipped_items

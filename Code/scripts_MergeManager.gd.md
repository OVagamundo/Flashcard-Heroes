<!-- Original: scripts/MergeManager.gd -->

```gdscript
# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to handle all merge logic calculations.

func calculate_merge_result(instance_a: GachaBallInstance, instance_b: GachaBallInstance, all_instances_db: Dictionary) -> Dictionary:
	if not instance_a or not instance_b:
		printerr("MergeManager: Attempted merge with a null instance.")
		return {}
		
	var recipe: MergeRecipe = find_recipe(instance_a.definition_id, instance_b.definition_id)
	if not recipe:
		return {}

	var result_definition: GachaBallDefinition = Database.get_definition(recipe.result_id)
	if not result_definition:
		printerr("MergeManager: Result ID from recipe not found in Database: ", recipe.result_id)
		return {}
		
	var merged_instance := GachaBallInstance.new()
	merged_instance.initialize(result_definition)
	
	# Gather all equipped item INSTANCES from parents by passing the correct database.
	var all_parent_items: Array[GachaBallInstance] = []
	all_parent_items.append_array(_get_equipped_item_instances(instance_a, all_instances_db))
	all_parent_items.append_array(_get_equipped_item_instances(instance_b, all_instances_db))

	# Equip the gathered items onto the new unit by copying their UUIDs.
	for i in range(min(all_parent_items.size(), merged_instance.equipped_item_uuids.size())):
		var item_to_equip: GachaBallInstance = all_parent_items[i]
		merged_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid
		
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

# The function now accepts the master instance database directly, removing the ambiguous context dictionary.
func _get_equipped_item_instances(unit_instance: GachaBallInstance, all_instances_db: Dictionary) -> Array[GachaBallInstance]:
	var equipped_items: Array[GachaBallInstance] = []
	if not is_instance_valid(unit_instance) or unit_instance.equipped_item_uuids.is_empty():
		return equipped_items

	for item_uuid in unit_instance.equipped_item_uuids:
		if not item_uuid.is_empty():
			# This is now a direct, unambiguous lookup.
			var item_instance: GachaBallInstance = all_instances_db.get(item_uuid)
			if is_instance_valid(item_instance):
				equipped_items.push_back(item_instance)

	return equipped_items

```
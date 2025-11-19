# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to handle all merge logic calculations.

func calculate_merge_result(instance_a: GachaBallInstance, instance_b: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, all_instances_db: Dictionary) -> Dictionary:
	if not instance_a or not instance_b:
		return {}
		
	var recipe: MergeRecipe = find_recipe(instance_a, instance_b, source_loc, target_loc, all_instances_db)
	if not recipe:
		return {}

	var result_definition: GachaBallDefinition = Database.get_definition(recipe.result_id)
	if not result_definition:
		return {}
		
	var merged_instance := GachaBallInstance.new()
	merged_instance.initialize(result_definition)
	
	# Update stats to be the sum of the parents' current stats
	var total_hp = instance_a.current_hp + instance_b.current_hp
	var total_pwr = instance_a.current_pwr + instance_b.current_pwr
	
	merged_instance.current_hp = total_hp
	merged_instance.current_pwr = total_pwr
	
	# Gather all equipped item INSTANCES from parents by passing the correct database.
	var all_parent_items: Array[GachaBallInstance] = []
	all_parent_items.append_array(_get_equipped_item_instances(instance_a, all_instances_db))
	all_parent_items.append_array(_get_equipped_item_instances(instance_b, all_instances_db))

	# Subtract bonuses from all parent items to avoid double-dipping when they are re-equipped.
	# We want the new unit to inherit (Base + Buffs/Damage), and then let the items add their bonuses back.
	for item in all_parent_items:
		var item_def = item.get_definition()
		if is_instance_valid(item_def):
			total_hp -= item_def.bonus_hp
			total_pwr -= item_def.bonus_pwr

	merged_instance.current_hp = total_hp
	merged_instance.current_pwr = total_pwr

	merged_instance.current_hp = total_hp
	merged_instance.current_pwr = total_pwr

	# Return the items so the caller can equip them properly using the data owner's API.
	# We do NOT equip them here to avoid state conflicts (e.g. "slot occupied" logic in equip_item).
	var items_to_equip: Array[GachaBallInstance] = all_parent_items
		
	var parents_to_remove: Array[GachaBallInstance] = [instance_a, instance_b]

	return {"merged_instance": merged_instance, "parents_to_remove": parents_to_remove, "items_to_equip": items_to_equip}


func find_recipe(instance_a: GachaBallInstance, instance_b: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, _all_instances_db: Dictionary) -> MergeRecipe:
	# --- CONTEXT-AWARE VALIDATION ---
	# TDD 4.3.III.3: Merging is not allowed between different interaction contexts.
	# Use GIR functional groups (e.g., PlayerBench and PlayerLineup are both "BattleBoard").
	var src_group: StringName = GlobalInteractionRouter.get_context_group(source_loc.container)
	var tgt_group: StringName = GlobalInteractionRouter.get_context_group(target_loc.container)
	if src_group != tgt_group:
		# Exception: allow merges that target an equipped item slot (handled by InventoryManager as needed).
		if not (target_loc.container == C.CONTAINER_EQUIPPED_ITEM and source_loc.container != C.CONTAINER_EQUIPPED_ITEM):
			return null

	# Get definitions for both instances
	var def_a = instance_a.get_definition()
	var def_b = instance_b.get_definition()
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		return null

	# Merging across different tiers is not allowed. Skip if either definition lacks tier.
	if not (def_a is GachaBallDefinition) or not (def_b is GachaBallDefinition):
		return null
	if def_a.tier != def_b.tier:
		return null

	for recipe_key in Database.recipes:
		var recipe: MergeRecipe = Database.recipes[recipe_key]
		
		# For a valid merge, the categories of the ingredients must match.
		if def_a.category != def_b.category:
			continue

		if recipe.is_self_merge:
			if instance_a.definition_id == recipe.ingredient_a_id and instance_a.definition_id == instance_b.definition_id:
				return recipe
		else: # Check for A+B or B+A
			if (instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_b_id) or \
			   (instance_a.definition_id == recipe.ingredient_b_id and instance_b.definition_id == recipe.ingredient_a_id):
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

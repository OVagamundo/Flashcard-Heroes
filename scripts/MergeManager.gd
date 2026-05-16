# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to handle all merge logic calculations.

const C = preload("res://scripts/Constants.gd")

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
	
	# Determine if this is a "Level Up" (Self-Merge with same result) or a "Tier Evolution"
	var is_level_up: bool = recipe.is_self_merge and recipe.result_id == instance_a.definition_id
	
	# Initial combined stats (excluding items, handled below)
	var total_hp: int = instance_a.current_hp + instance_b.current_hp
	var total_pwr: int = instance_a.current_pwr + instance_b.current_pwr
	
	# Subtract bonuses from all parent items to avoid double-dipping.
	# We want the inherent stats (Base + Inherent Extra), and then items will be re-applied.
	var source_items: Array[GachaBallInstance] = _get_equipped_item_instances(instance_a, all_instances_db)
	var target_items: Array[GachaBallInstance] = _get_equipped_item_instances(instance_b, all_instances_db)
	var all_parent_items: Array[GachaBallInstance] = []
	all_parent_items.append_array(source_items)
	all_parent_items.append_array(target_items)

	for item in all_parent_items:
		var item_def = item.get_definition()
		if is_instance_valid(item_def):
			total_hp -= item_def.bonus_hp
			total_pwr -= item_def.bonus_pwr

	# Apply New Stat Logic
	var final_hp: int
	var final_pwr: int
	
	if is_level_up:
		# LEVELING LOGIC: Keeps base stats + Sum(Extra Stats) + 1
		# Inherent_Extra = Total_Inherent - ParentA_Base - ParentA_LevelBonus - ParentB_Base - ParentB_LevelBonus
		var base_a = instance_a.get_definition_base_hp()
		var level_bonus_a = int(instance_a.get_attribute(&"level")) - 1
		var base_b = instance_b.get_definition_base_hp()
		var level_bonus_b = int(instance_b.get_attribute(&"level")) - 1
		
		# Formula: Result = Result_Base + (Extras_A + Extras_B) + (Result_Level - 1)
		# Which simplifies to: total_hp - Parent_Base - Parent_LevelBonus + 1
		final_hp = total_hp - base_a - level_bonus_a + 1
		
		var pwr_base_a = instance_a.get_definition_base_pwr()
		final_pwr = total_pwr - pwr_base_a - level_bonus_a + 1
	else:
		# TIER EVOLUTION LOGIC: Additive (A + B)
		final_hp = total_hp
		final_pwr = total_pwr

	merged_instance.current_hp = final_hp
	merged_instance.current_pwr = final_pwr
	
	# Store surplus stats (above the new definition's base) as a merge inheritance component.
	var surplus_hp: int = final_hp - result_definition.base_hp
	var surplus_pwr: int = final_pwr - result_definition.base_pwr
	merged_instance.add_or_update_stat_component(
		&"merge_inheritance",
		&"MERGE_INHERITANCE",
		String(recipe.id),
		surplus_hp,
		surplus_pwr,
		false
	)

	# Target item has priority. If target is empty, inherit source item.
	var items_to_equip: Array[GachaBallInstance] = []
	var items_to_discard: Array[GachaBallInstance] = []
	var target_item: GachaBallInstance = target_items[0] if not target_items.is_empty() else null
	var source_item: GachaBallInstance = source_items[0] if not source_items.is_empty() else null
	if is_instance_valid(target_item):
		items_to_equip.append(target_item)
		if is_instance_valid(source_item):
			items_to_discard.append(source_item)
	elif is_instance_valid(source_item):
		items_to_equip.append(source_item)
		
	var parents_to_remove: Array[GachaBallInstance] = [instance_a, instance_b]

	return {
		"merged_instance": merged_instance,
		"parents_to_remove": parents_to_remove,
		"items_to_equip": items_to_equip,
		"items_to_discard": items_to_discard
	}


func find_recipe(instance_a: GachaBallInstance, instance_b: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, _all_instances_db: Dictionary) -> MergeRecipe:
	# --- CONTEXT-AWARE VALIDATION ---
	var src_group: StringName = GlobalInteractionRouter.get_context_group(source_loc.container)
	var tgt_group: StringName = GlobalInteractionRouter.get_context_group(target_loc.container)
	if src_group != tgt_group:
		if not (target_loc.container == C.CONTAINER_EQUIPPED_ITEM and source_loc.container != C.CONTAINER_EQUIPPED_ITEM):
			return null

	# Merging is only allowed in battle or during a Merge Encounter surprise event.
	var is_battle = GameManager.is_in_battle
	var is_merge_encounter = is_merge_encounter_active()
	
	if not is_battle and not is_merge_encounter:
		return null

	var def_a = instance_a.get_definition()
	var def_b = instance_b.get_definition()
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		return null

	for recipe_key in Database.recipes:
		var recipe: MergeRecipe = Database.recipes[recipe_key]
		
		if def_a.category != def_b.category:
			continue

		if recipe.is_self_merge:
			if instance_a.definition_id == recipe.ingredient_a_id and instance_a.definition_id == instance_b.definition_id:
				# Merge Encounter bypasses unlock check
				if is_merge_encounter_active():
					return recipe
					
				if not _is_recipe_unlocked(recipe.id):
					continue
				return recipe
		else: # Check for A+B or B+A
			if (instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_b_id) or \
			   (instance_a.definition_id == recipe.ingredient_b_id and instance_b.definition_id == recipe.ingredient_a_id):
				# Merge Encounter bypasses unlock check
				if is_merge_encounter_active():
					return recipe
					
				if not _is_recipe_unlocked(recipe.id):
					continue
				return recipe
				
	return null

func _is_recipe_unlocked(recipe_id: StringName) -> bool:
	var run_state = GameManager.run_state
	if not is_instance_valid(run_state):
		return false
	return run_state.is_recipe_unlocked(recipe_id)

func is_merge_encounter_active() -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree: return false
	return tree.get_nodes_in_group("merge_encounter_controller").size() > 0

func _get_equipped_item_instances(unit_instance: GachaBallInstance, all_instances_db: Dictionary) -> Array[GachaBallInstance]:
	var equipped_items: Array[GachaBallInstance] = []
	if not is_instance_valid(unit_instance) or unit_instance.equipped_item_uuids.is_empty():
		return equipped_items

	for item_uuid in unit_instance.equipped_item_uuids:
		if not item_uuid.is_empty():
			var item_instance: GachaBallInstance = all_instances_db.get(item_uuid)
			if is_instance_valid(item_instance):
				equipped_items.push_back(item_instance)

	return equipped_items

## Performs an evolution by merging the instance with a 'phantom' copy of itself.
func evolve_unit_instance(instance: GachaBallInstance, all_instances_db: Dictionary) -> Dictionary:
	var recipe = Database.get_self_merge_recipe(instance.definition_id)
	if not recipe:
		return {}
		
	# Create a temporary secondary instance to act as the second parent
	var template_instance := GachaBallInstance.new()
	template_instance.initialize(instance.get_definition())
	
	# Perform the merge. We use the instance's own location as a placeholder.
	return calculate_merge_result(instance, template_instance, instance.get_location(), instance.get_location(), all_instances_db)

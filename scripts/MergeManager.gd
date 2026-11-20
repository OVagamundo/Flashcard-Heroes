# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to handle all merge logic calculations.

const C = preload("res://scripts/Constants.gd")

func calculate_merge_result(instance_a: GachaBallInstance, instance_b: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, all_instances_db: Dictionary, recipe_id: StringName = &"") -> Dictionary:
	if not instance_a or not instance_b:
		return {}
		
	var recipe: MergeRecipe = null
	if not recipe_id.is_empty():
		recipe = Database.recipes.get(recipe_id)
	if not is_instance_valid(recipe):
		recipe = find_recipe(instance_a, instance_b, source_loc, target_loc, all_instances_db)
	if not recipe:
		return {}

	var result_definition: GachaBallDefinition = Database.get_definition(recipe.result_id)
	if not result_definition:
		return {}
		
	var merged_instance := GachaBallInstance.new()
	merged_instance.initialize(result_definition)
	
	# Determine if this is a "Level Up" (Self-Merge with same result) or a "Tier Evolution"
	var is_level_up: bool = recipe.is_self_merge and recipe.result_id == instance_a.definition_id
	
	# Determine items to transfer (items will be re-equipped and their stats re-applied later)
	var source_items: Array[GachaBallInstance] = _get_equipped_item_instances(instance_a, all_instances_db)
	var target_items: Array[GachaBallInstance] = _get_equipped_item_instances(instance_b, all_instances_db)
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

	# Calculate combined stats combining base stats and ALL valid accumulated stackable stats
	# (Dojo training, prior merge surplus, prismatic rarity, permanent buffs, and in-combat ability buffs).
	# Unique and conditional buffs (items, Rusty Ring, Royal/Veteran Insignia, dynamic scaling) are excluded.
	var total_hp: int = instance_a.get_definition_base_hp() + _get_mergeable_stackable_modifier(instance_a, &"hp", all_instances_db) + \
						instance_b.get_definition_base_hp() + _get_mergeable_stackable_modifier(instance_b, &"hp", all_instances_db)
	var total_pwr: int = instance_a.get_definition_base_pwr() + _get_mergeable_stackable_modifier(instance_a, &"pwr", all_instances_db) + \
						 instance_b.get_definition_base_pwr() + _get_mergeable_stackable_modifier(instance_b, &"pwr", all_instances_db)

	# Apply New Stat Logic
	var final_hp: int
	var final_pwr: int
	
	if is_level_up:
		merged_instance.level = instance_a.level + 1
		# LEVELING LOGIC: Keeps base stats + Sum(Extra Stats) + 1
		# Inherent_Extra = Total_Inherent - ParentA_Base - ParentA_LevelBonus - ParentB_Base - ParentB_LevelBonus
		var base_a = instance_a.get_definition_base_hp()
		var level_bonus_a = int(instance_a.get_attribute(&"level")) - 1
		
		# Formula: Result = Result_Base + (Extras_A + Extras_B) + (Result_Level - 1)
		# Which simplifies to: total_hp - Parent_Base - Parent_LevelBonus + 1
		final_hp = total_hp - base_a - level_bonus_a + 1
		
		var pwr_base_a = instance_a.get_definition_base_pwr()
		final_pwr = total_pwr - pwr_base_a - level_bonus_a + 1
	else:
		merged_instance.level = 1
		# TIER EVOLUTION LOGIC: Additive (A + B)
		final_hp = total_hp
		final_pwr = total_pwr

	merged_instance.current_hp = final_hp
	merged_instance.current_pwr = final_pwr
	
	# Merge status effects: sum up stacks of each status effect (Armor, Burn, Spikes, Static, etc.).
	# Continuous auras live strictly in `active_auras` and never pollute `status_effects`.
	for status_id in instance_a.status_effects:
		var amount = instance_a.status_effects[status_id]
		if amount > 0:
			merged_instance.status_effects[status_id] = merged_instance.status_effects.get(status_id, 0) + amount
	for status_id in instance_b.status_effects:
		var amount = instance_b.status_effects[status_id]
		if amount > 0:
			merged_instance.status_effects[status_id] = merged_instance.status_effects.get(status_id, 0) + amount
			
	# Merge dynamic tags (ensuring uniqueness).
	for tag in instance_a.dynamic_tags:
		if not merged_instance.dynamic_tags.has(tag):
			merged_instance.dynamic_tags.append(tag)
	for tag in instance_b.dynamic_tags:
		if not merged_instance.dynamic_tags.has(tag):
			merged_instance.dynamic_tags.append(tag)
	
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

	# Continuous aura continuity for Level-Up merges (delegated generically to AuraEvaluator).
	# Tier evolutions always re-evaluate all continuous auras cleanly as a new unit.
	if is_level_up:
		AuraEvaluator.prepare_level_up_auras(instance_a, instance_b, merged_instance, all_instances_db, not items_to_equip.is_empty())



	# Direct Additive Soul Inheritance:
	# All merges (both Level-Up and Tier-Up) add up all elemental souls from both parents.
	var parent_a_souls = instance_a.get_trait_soul_counts(all_instances_db)
	var parent_b_souls = instance_b.get_trait_soul_counts(all_instances_db)
	var result_base_souls = {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	if "tags" in result_definition:
		var effective_result_tags: Array[StringName] = result_definition.tags
		if is_instance_valid(GameManager.run_state) and GameManager.run_state.dynamic_tag_overrides.has(result_definition.id):
			effective_result_tags = GameManager.run_state.get_effective_unit_tags(result_definition.id, result_definition.tags)
		for tag in effective_result_tags:
			if tag == &"SOUL_FIRE": result_base_souls["FIRE"] += 1
			elif tag == &"SOUL_EARTH": result_base_souls["EARTH"] += 1
			elif tag == &"SOUL_WATER": result_base_souls["WATER"] += 1
			elif tag == &"SOUL_AIR": result_base_souls["AIR"] += 1

	var inherited_tags_to_add: Array = []
	var inherited_tags_to_remove: Array = []
	for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
		var total_parent_souls: int = parent_a_souls[soul_type] + parent_b_souls[soul_type]
		var base_souls: int = result_base_souls[soul_type]
		var tag_name = StringName("SOUL_" + soul_type)
		if total_parent_souls > base_souls:
			for i in range(total_parent_souls - base_souls):
				inherited_tags_to_add.append(tag_name)
		elif total_parent_souls < base_souls:
			for i in range(base_souls - total_parent_souls):
				inherited_tags_to_remove.append(tag_name)
				
	if not inherited_tags_to_add.is_empty() or not inherited_tags_to_remove.is_empty():
		merged_instance.add_or_update_tag_component(
			&"merge_inheritance_souls",
			&"MERGE_INHERITANCE",
			String(recipe.id),
			{},
			inherited_tags_to_add,
			inherited_tags_to_remove
		)

	var parents_to_remove: Array[GachaBallInstance] = [instance_a, instance_b]

	return {
		"merged_instance": merged_instance,
		"parents_to_remove": parents_to_remove,
		"items_to_equip": items_to_equip,
		"items_to_discard": items_to_discard
	}

## Calculates and returns a preview GachaBallInstance representing the outcome of a merge.
## Does NOT mutate any game state, data owner, or parent instances.
func get_preview_merge_instance(source_instance: GachaBallInstance, target_instance: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, all_instances_db: Dictionary, recipe_id: StringName = &"") -> GachaBallInstance:
	var merge_result := calculate_merge_result(source_instance, target_instance, source_loc, target_loc, all_instances_db, recipe_id)
	if merge_result.is_empty():
		return null
	var preview_instance: GachaBallInstance = merge_result.get("merged_instance")
	if not is_instance_valid(preview_instance):
		return null
	var result_def = preview_instance.get_definition()
	if not is_instance_valid(result_def):
		return null
	
	if result_def.category == &"UNIT":
		var items_to_equip: Array = merge_result.get("items_to_equip", [])
		var max_slots: int = preview_instance.equipped_item_uuids.size()
		for i in range(mini(items_to_equip.size(), max_slots)):
			var it: GachaBallInstance = items_to_equip[i]
			if is_instance_valid(it):
				preview_instance.equipped_item_uuids[i] = it.ball_uuid
				preview_instance.equip_item_bonus(it, {"silent": true})
	
	return preview_instance

func find_recipe(instance_a: GachaBallInstance, instance_b: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, _all_instances_db: Dictionary) -> MergeRecipe:
	if GameManager.is_in_battle:
		var battle_manager: BattleManager = GameManager.get_battle_manager() as BattleManager
		if not battle_manager._state.is_lineup_location(target_loc):
			return null
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

	# Dynamic Evolutionary Level-Up check (Unit self-merges)
	if def_a.category == &"UNIT" and instance_a.definition_id == instance_b.definition_id:
		if instance_a.level == instance_b.level and instance_a.level < 3:
			var virtual_recipe = MergeRecipe.new()
			virtual_recipe.id = StringName("level_up_" + String(instance_a.definition_id))
			virtual_recipe.ingredient_a_id = instance_a.definition_id
			virtual_recipe.ingredient_b_id = instance_b.definition_id
			virtual_recipe.result_id = instance_a.definition_id
			virtual_recipe.is_self_merge = true
			virtual_recipe.merge_type = &"UNIT"
			return virtual_recipe
		else:
			return null # Same unit ID but cannot merge/level up

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

## Returns the merge type between two instances (&"LEVEL_UP", &"RECIPE_TIER_UP", or &"").
## Returns &"" if no valid unlocked merge exists.
func get_merge_type_between(instance_a: GachaBallInstance, instance_b: GachaBallInstance) -> StringName:
	if not is_instance_valid(instance_a) or not is_instance_valid(instance_b):
		return &""
	if instance_a.ball_uuid == instance_b.ball_uuid:
		return &""

	var is_battle = GameManager.is_in_battle if is_instance_valid(GameManager) else false
	var is_merge_encounter = is_merge_encounter_active()
	if not is_battle and not is_merge_encounter:
		return &""

	var def_a = instance_a.get_definition()
	var def_b = instance_b.get_definition()
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		return &""

	if def_a.category != def_b.category:
		return &""

	# Unit Merges
	if def_a.category == &"UNIT":
		# Level Up: same definition ID, same level, level < 3
		if instance_a.definition_id == instance_b.definition_id:
			if instance_a.level == instance_b.level and instance_a.level < 3:
				return &"LEVEL_UP"
			else:
				return &""

		# Recipe Tier Up
		for recipe_key in Database.recipes:
			var recipe: MergeRecipe = Database.recipes[recipe_key]
			if not is_instance_valid(recipe) or recipe.merge_type != &"UNIT":
				continue
			if (instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_b_id) or \
			   (instance_a.definition_id == recipe.ingredient_b_id and instance_b.definition_id == recipe.ingredient_a_id):
				if is_merge_encounter or _is_recipe_unlocked(recipe.id):
					return &"RECIPE_TIER_UP"
		return &""

	# Item Merges
	if def_a.category == &"ITEM":
		for recipe_key in Database.recipes:
			var recipe: MergeRecipe = Database.recipes[recipe_key]
			if not is_instance_valid(recipe) or recipe.merge_type != &"ITEM":
				continue
			if recipe.is_self_merge:
				if instance_a.definition_id == recipe.ingredient_a_id and instance_a.definition_id == instance_b.definition_id:
					if is_merge_encounter or _is_recipe_unlocked(recipe.id):
						return &"RECIPE_TIER_UP"
			else:
				if (instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_b_id) or \
				   (instance_a.definition_id == recipe.ingredient_b_id and instance_b.definition_id == recipe.ingredient_a_id):
					if is_merge_encounter or _is_recipe_unlocked(recipe.id):
						return &"RECIPE_TIER_UP"
		return &""

	return &""


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

## Calculates all valid accumulated stackable stats (Dojo training, prior merge surplus,
## prismatic rarity, permanent buffs, and in-combat discrete ability/consumable buffs).
## Continuous auras (`source_type == &"AURA"`) are excluded automatically.
func _get_mergeable_stackable_modifier(instance: GachaBallInstance, stat: StringName, _all_instances_db: Dictionary) -> int:
	var total := 0
	
	# 1. Persistent components on the instance (Dojo training, previous merge surplus, prismatic rarity, permanent buffs)
	for component in instance.components:
		if not component is StatComponent:
			continue
		if component.source_type == &"AURA":
			continue
		total += int(component.modifiers.get(String(stat), 0))
		
	# 2. In-combat stat gains from abilities and consumables.
	# Continuous auras are tagged with `source_type == &"AURA"` and never inherited here.
	for component in instance.battle_components:
		if not component is StatComponent:
			continue
		if component.source_type == &"AURA":
			continue
		if component.source_type == &"CONSUMABLE" or component.category == &"CONSUMABLE":
			total += maxi(0, int(component.modifiers.get(String(stat), 0)))
			continue
		# HEAL is a separate action type from BUFF, but its completed positive HP
		# gain is still part of the recipient's accumulated stats for merge purposes.
		if component.source_type == &"BATTLE_BUFF" or component.id == &"battle_heal":
			total += maxi(0, int(component.modifiers.get(String(stat), 0)))

	return total

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

<!-- Original: scripts/MergeManager.gd -->

```gdscript
# res://scripts/MergeManager.gd
extends Node

## A dedicated, global manager to handle all merge logic.

## Attempts to merge two GachaBallInstances within a tiered inventory dictionary.
## Returns the new merged instance on success, or null on failure.
func attempt_merge(instance_a: GachaBallInstance, instance_b: GachaBallInstance, inventory_dict: Dictionary) -> GachaBallInstance:
    if not instance_a or not instance_b:
        printerr("MergeManager: Attempted merge with a null instance.")
        return null
        
    var recipe: MergeRecipe = find_recipe(instance_a.definition_id, instance_b.definition_id)
    if not recipe:
        return null # No valid recipe found.
        
    var def_a = Database.units.get(instance_a.definition_id, Database.items.get(instance_a.definition_id))
    var def_b = Database.units.get(instance_b.definition_id, Database.items.get(instance_b.definition_id))
    
    if not def_a or not def_b:
        printerr("MergeManager: Could not find definitions for ingredients.")
        return null
        
    # --- Merge is valid, proceed ---
    
    # 1. Create the new result GachaBallInstance.
    var result_definition: GachaBallDefinition = Database.units.get(recipe.result_id, Database.items.get(recipe.result_id))
    if not result_definition:
        printerr("MergeManager: Result ID from recipe not found in Database: ", recipe.result_id)
        return null
        
    var merged_instance := GachaBallInstance.new()
    merged_instance.initialize(result_definition)
    
    # 2. Gather all items from parents into a temporary list.
    var all_parent_items: Array[GachaBallInstance] = []
    all_parent_items.append_array(_get_equipped_items_from_inventory(instance_a, inventory_dict))
    all_parent_items.append_array(_get_equipped_items_from_inventory(instance_b, inventory_dict))

    # 3. Remove parent instances and their items from the source inventory dictionary.
    inventory_dict[def_a.tier].erase(instance_a)
    inventory_dict[def_b.tier].erase(instance_b)
    for item in all_parent_items:
        var item_def = Database.items.get(item.definition_id)
        if item_def and inventory_dict.has(item_def.tier):
            inventory_dict[item_def.tier].erase(item)

    # 4. Add the new result instance to the correct tier in the inventory.
    inventory_dict[result_definition.tier].append(merged_instance)
    
    # 5. Equip the gathered items onto the new unit.
    for i in range(min(all_parent_items.size(), merged_instance.equipped_item_uuids.size())):
        var item_to_equip: GachaBallInstance = all_parent_items[i]
        merged_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid
        
        # Add the item back into its correct tier, now linked to the new unit.
        var item_def = Database.items.get(item_to_equip.definition_id)
        if item_def and inventory_dict.has(item_def.tier):
            inventory_dict[item_def.tier].append(item_to_equip)
            
    print("Merge successful. Created: ", merged_instance.definition_id)
    return merged_instance

## Helper to find equipped items of a unit within a specific tiered inventory.
func _get_equipped_items_from_inventory(unit_instance: GachaBallInstance, inventory_dict: Dictionary) -> Array[GachaBallInstance]:
    var equipped_items: Array[GachaBallInstance] = []
    if unit_instance.equipped_item_uuids.is_empty():
        return equipped_items
        
    for item_uuid in unit_instance.equipped_item_uuids:
        if item_uuid.is_empty(): continue
        # We must search all tiers of the item inventory to find the item.
        for tier in inventory_dict:
            # Ensure tier key exists and is an array before iterating
            if not inventory_dict.has(tier) or not inventory_dict[tier] is Array: continue
            var tier_inventory = inventory_dict[tier]
            for entity in tier_inventory:
                if entity is GachaBallInstance and entity.ball_uuid == item_uuid:
                    equipped_items.push_back(entity)
                    break # Found the item, move to next UUID
    return equipped_items

## Finds a matching recipe for two GachaBall definition IDs.
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

```
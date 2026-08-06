class_name WeightedPoolDirector
extends RefCounted

# Step 1-4: Fetch, Filter, Modify, and Roll
func draw_item(raw_pool: Array, current_state, rng: SeededRNG = null) -> Resource:
    if rng == null:
        rng = RNGManager.shop_rng
    var valid_entities: Array = []
    
    # Filter Hard Constraints
    for entity in raw_pool:
        if not entity is WeightableEntity:
            continue
        if entity.meets_prerequisites(current_state):
            valid_entities.append(entity)
            
    if valid_entities.is_empty():
        return null
        
    var total_weight: float = 0.0
    var weighted_list: Array[Dictionary] = []
    
    # Calculate Final Weights
    for entity in valid_entities:
        var final_weight: float = float(entity.base_weight) * entity.get_dynamic_weight_multiplier(current_state)
        if final_weight > 0.0:
            weighted_list.append({"entity": entity, "weight": final_weight})
            total_weight += final_weight
            
    if total_weight <= 0.0:
        return null
        
    # Roll
    var random_roll: float = rng.randf() * total_weight
    var current_sum: float = 0.0
    
    for item in weighted_list:
        current_sum += item["weight"]
        if random_roll <= current_sum:
            return item["entity"]
            
    return weighted_list.back()["entity"]

func draw_unique_items(raw_pool: Array, current_state, count: int, rng: SeededRNG = null) -> Array:
    if rng == null:
        rng = RNGManager.shop_rng
    var drawn_items: Array = []
    var pool_copy: Array = raw_pool.duplicate()
    
    for i in range(count):
        var item = draw_item(pool_copy, current_state, rng)
        if item != null:
            drawn_items.append(item)
            pool_copy.erase(item)
            
    return drawn_items


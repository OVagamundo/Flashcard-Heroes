class_name WeightedPoolDirector
extends RefCounted

const C = preload("res://scripts/Constants.gd")
const OFFER_AFFINITY_PER_MATCH: float = 0.15
const CREST_DECAY_START_COUNT: int = 2
const CREST_WEIGHT_PER_STEP: float = 0.35

static func normalize_trait_tag(tag: StringName) -> String:
    return String(tag).to_upper().trim_prefix("SOUL_")

static func get_crest_trait_id(trinket: TrinketDefinition) -> String:
    var trait_id: String = normalize_trait_tag(trinket.linked_trait_id)
    if C.TRAIT_DEFINITIONS.has(trait_id) and C.TRAIT_DEFINITIONS[trait_id].trinket_id == trinket.id:
        return trait_id
    return ""

func get_offer_weight_multiplier(entity: WeightableEntity, state: DirectorRunState) -> float:
    if state.current_purpose not in [DirectorRunState.Purpose.SHOP, DirectorRunState.Purpose.REWARD]:
        return 1.0

    var tags: Array[StringName] = state.unit_tag_overrides.get(entity.id, entity.tags)
    var crest_multiplier: float = 1.0
    if entity is TrinketDefinition and not entity.linked_trait_id.is_empty():
        tags = [entity.linked_trait_id]
        if not get_crest_trait_id(entity).is_empty():
            var decay_steps: int = maxi(0, state.owned_crest_traits.size() - CREST_DECAY_START_COUNT + 1)
            crest_multiplier = pow(CREST_WEIGHT_PER_STEP, decay_steps)
    var trait_matches: int = _get_trait_matches(entity.set_id, state)
    for tag: StringName in tags:
        trait_matches = maxi(trait_matches, _get_trait_matches(tag, state))

    var unit_matches: int = state.machine_unit_counts.get(entity.id, 0)
    var affinity_multiplier: float = 1.0 + OFFER_AFFINITY_PER_MATCH * (trait_matches + unit_matches)
    return affinity_multiplier * crest_multiplier

func _get_trait_matches(tag: StringName, state: DirectorRunState) -> int:
    var trait_id: String = normalize_trait_tag(tag)
    var machine_matches: int = state.machine_trait_counts.get(trait_id, 0)
    return machine_matches + int(state.owned_crest_traits.has(trait_id))

func _resolve_rng(current_state, p_rng: SeededRNG = null) -> SeededRNG:
    if p_rng != null:
        return p_rng
    if current_state and "current_purpose" in current_state:
        if current_state.current_purpose == DirectorRunState.Purpose.REWARD:
            return RNGManager.reward_rng
        elif current_state.current_purpose == DirectorRunState.Purpose.SHOP:
            return RNGManager.shop_rng
    return RNGManager.shop_rng

# Step 1-4: Fetch, Filter, Modify, and Roll
func draw_item(raw_pool: Array, current_state, rng: SeededRNG = null) -> Resource:
    var effective_rng := _resolve_rng(current_state, rng)
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
        final_weight *= get_offer_weight_multiplier(entity, current_state)
        if final_weight > 0.0:
            weighted_list.append({"entity": entity, "weight": final_weight})
            total_weight += final_weight
            
    if total_weight <= 0.0:
        return null
        
    # Roll
    var random_roll: float = effective_rng.randf() * total_weight
    var current_sum: float = 0.0
    
    for item in weighted_list:
        current_sum += item["weight"]
        if random_roll <= current_sum:
            return item["entity"]
            
    return weighted_list.back()["entity"]

func draw_unique_items(raw_pool: Array, current_state, count: int, rng: SeededRNG = null) -> Array:
    var effective_rng := _resolve_rng(current_state, rng)
    var drawn_items: Array = []
    var pool_copy: Array = raw_pool.duplicate()
    
    for i in range(count):
        var item = draw_item(pool_copy, current_state, effective_rng)
        if item != null:
            drawn_items.append(item)
            pool_copy.erase(item)
            
    return drawn_items


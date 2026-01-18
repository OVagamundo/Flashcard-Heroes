# res://scripts/EffectBossSummon.gd
@tool
extends EffectDefinition

## Effect that summons units to fill empty enemy team slots using a budget system.
## Used by boss units at end of turn to call reinforcements.
## 
## Note: This effect queries container state during end_of_turn, which is a stable game state.
## Container queries are valid here because we're not in a transitional death state.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	# The source is the boss unit - if this trigger fired, it exists
	# No need to validate source instance - the trigger system already did that
	# 1. Get budget from parameters
	var budget: int = parameters.get("budget", 5)
	
	# 2. Count empty enemy lineup slots
	# Note: Container queries at end_of_turn are valid (stable game state)
	var enemy_container = battle_manager.get_container(&"EnemyLineup")
	if not is_instance_valid(enemy_container):
		return EffectResult.empty()
	
	var max_slots: int = 5
	var filled_slots: int = 0
	for i in range(max_slots):
		if not enemy_container.get_uuid(i).is_empty():
			filled_slots += 1
	var empty_slots: int = max_slots - filled_slots
	
	if empty_slots <= 0:
		return EffectResult.empty()
	
	# 3. Generate summons within budget
	var summon_data: Array = _generate_summons(budget, empty_slots)
	
	if summon_data.is_empty():
		return EffectResult.empty()
	
	# 4. Return EffectResult with summon instructions
	var result := EffectResult.new()
	result.summon_units_request = summon_data
	result.summon_team = "ENEMY"
	return result

func _generate_summons(budget: int, max_units: int) -> Array:
	# Get available units and items (exclude heroes and bosses)
	var available_units: Array = []
	var available_items: Array = []
	
	for d in Database.units.values():
		# Skip hero units
		if d.id == &"hero" or d.id == &"enemy_hero":
			continue
		if d.is_hero:
			continue
		# Skip boss units
		if String(d.id).begins_with("boss_"):
			continue
		available_units.append(d)
	
	for d in Database.items.values():
		available_items.append(d)
	
	if available_units.is_empty():
		return []
	
	# Sort by cost ascending for budget optimization
	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	available_items.sort_custom(func(a, b): return a.cost < b.cost)
	
	var summons: Array = [] # Array of {unit_id: StringName, items: Array[StringName]}
	var spent: int = 0
	
	# Phase 1: Mandatory unit spend (at least 50% on units)
	var min_unit_spend: int = int(floor(budget * 0.5))
	while spent < min_unit_spend and summons.size() < max_units:
		var affordable = available_units.filter(func(u): return u.cost <= (budget - spent))
		if affordable.is_empty():
			break
		var chosen = affordable.pick_random()
		summons.append({"unit_id": chosen.id, "items": [], "item_slots": chosen.item_slot_count})
		spent += chosen.cost
	
	# Phase 2: Flexible spending on units or items
	while spent < budget:
		var remaining = budget - spent
		
		# Build weighted options: units (weight 3) vs items (weight 2)
		var options: Array = []
		
		# Add unit options if we haven't maxed out
		if summons.size() < max_units:
			for u in available_units:
				if u.cost <= remaining:
					options.append({"type": "unit", "def": u, "weight": 3})
		
		# Add item options if we have units with free item slots
		var total_free_slots: int = 0
		for s in summons:
			total_free_slots += s.item_slots - s.items.size()
		
		if total_free_slots > 0:
			for item in available_items:
				if item.cost <= remaining:
					options.append({"type": "item", "def": item, "weight": 2})
		
		if options.is_empty():
			break
		
		# Weighted random selection
		var total_weight = 0
		for opt in options:
			total_weight += opt.weight
		var roll = randi() % total_weight
		var cumulative = 0
		var selected = options[0]
		for opt in options:
			cumulative += opt.weight
			if roll < cumulative:
				selected = opt
				break
		
		if selected.type == "unit":
			summons.append({"unit_id": selected.def.id, "items": [], "item_slots": selected.def.item_slot_count})
		else: # item
			# Find a unit with free slots and assign the item
			for s in summons:
				if s.items.size() < s.item_slots:
					s.items.append(selected.def.id)
					break
		spent += selected.def.cost
	
	# Clean up the item_slots key before returning (not needed by effect handlers)
	for s in summons:
		s.erase("item_slots")
	
	return summons

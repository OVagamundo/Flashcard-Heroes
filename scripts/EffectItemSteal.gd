@tool
class_name EffectItemSteal
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Execute the stealing effect.
## Returns EffectResult on success, or null if no item could be stolen.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	if targets.is_empty():
		return EffectResult.empty()
	var target_uuid = targets[0]
	var target_unit = battle_manager.get_instance(target_uuid)
	
	if not is_instance_valid(target_unit):
		return EffectResult.empty()
	# 1. Find Stealable Items
	var stealable_items: Array[GachaBallInstance] = []
	for item_uuid in target_unit.equipped_item_uuids:
		if item_uuid == "": continue
		
		var item = battle_manager.get_instance(item_uuid)
		if is_instance_valid(item):
			stealable_items.append(item)
	
	# Condition: Target must have at least one item
	if stealable_items.is_empty():
		return EffectResult.empty()
	# 2. Select Random Item
	var stolen_item = stealable_items.pick_random()
	var stolen_def = stolen_item.get_definition()
	var item_name = stolen_def.display_name_key if stolen_def else "Unknown Item" # Ideally localized later
	
	# 3. Determine Destination (Player Inventory)
	# Determine tier for destination container
	var tier = 1
	if is_instance_valid(stolen_def) and "tier" in stolen_def:
		tier = stolen_def.tier
	
	var dest_container_tag = "BattleInventoryT%d" % tier
	
	# Simulation Mode: Just report what WOULD happen (but successful)
	# For consumables, InventoryManager often runs with is_simulation=true to check validity first,
	# but for pure logic that affects inventory, we might need to actually move it if not strict simulation.
	# However, InventoryManager._use_consumable runs with is_simulation=true and expects events.
	# BUT `bm_move_instance` is a state mutation. 
	# 
	# CRITICAL ARCHITECTURE CHECK:
	# InventoryManager._use_consumable runs in "simulation" mode to gather visual events, 
	# but relies on the effect to perform logic? 
	# No, looking at InventoryManager.gd:208:
	# "Execute effect in Execution Mode (is_simulation=false)" -> Wait, comment says false but context sets true?
	# Line 190: var context = {"is_simulation": true, "silent": is_battle}
	#
	# If I strictly follow simulation rules, I shouldn't move the item.
	# BUT InventoryManager consumes the potion based on result.
	# AND it controls visual playback.
	#
	# If I don't move the item in `execute`, who does?
	# InventoryManager `_use_consumable` DOES NOT have logic to move stolen items from an event.
	# It only plays animations.
	#
	# Therefore, this effect MUST enter "Execution Mode" to move the item, OR return a specialized response 
	# that InventoryManager isn't currently built to handle (e.g. "steal_request").
	#
	# Given the constraints and the goal (make it work without refactoring core),
	# I should perform the move if `battle_manager` allows it, or use `bm_move_instance` which is safe.
	#
	# Re-reading InventoryManager.gd:
	# It calls `effect.execute`.
	# If `res != null`, it eventually calls `owner.remove_instance(consumable)`.
	#
	# So I must perform the move HERE.
	# `is_simulation` flag in context is technically true, which is slightly contradictory for this usage,
	# but standard for getting the EffectResult visual payload.
	# I will perform the move regardless of is_simulation flag because "Stealing" IS the effect.
	
	# Execute Move
	# We need to find a valid slot in the destination
	var dest_container = battle_manager.get_container(dest_container_tag)
	var dest_index = -1
	
	if is_instance_valid(dest_container):
		dest_index = dest_container.find_first_empty_slot()
	
	if dest_index == -1:
		# Inventory full - fail? Or move to discard?
		# Let's try to move to discard if inventory is full
		# BUT standard behavior is usually "fail if no room".
		# Let's return null if no room.
		return EffectResult.empty()
	var source_loc = stolen_item.get_location()
	var dest_loc = LocationIdentifier.new(dest_container_tag, dest_index)
	
	# Perform atomic move
	var success = battle_manager.bm_move_instance(source_loc, dest_loc)
	
	if not success:
		return EffectResult.empty()
	# 4. Construct Result
	var result := EffectResult.new()
	
	# Log Message
	# _source_name and _target_name are now underscored to silence warnings
	var _source_name = "Potion of Plunder"
	var _target_name = "Target"
	
	# Try to get localized names if possible, but for now hardcode for safety
	var log_text = "Stole %s!" % [item_name] # Simplified log
	
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	result.state_applied = true
	
	return result

# res://scripts/EffectItemSteal.gd
@tool
class_name EffectItemSteal
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Execute the item-stripping effect (Potion of Plunder).
## Removes a random equipped item from the target unit and sends it directly to the Battle Discard Pile.
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
		if item_uuid.is_empty(): continue
		var item = battle_manager.get_instance(item_uuid)
		if is_instance_valid(item):
			stealable_items.append(item)
	
	# Condition: Target must have at least one item
	if stealable_items.is_empty():
		return EffectResult.empty()

	# 2. Select Random Item
	var stolen_item: GachaBallInstance = RNGManager.combat_rng.pick_random(stealable_items)
	var stolen_def = stolen_item.get_definition()
	var item_name = tr(stolen_def.display_name_key) if stolen_def and not stolen_def.display_name_key.is_empty() else "Item"
	
	# Determine matching Gacha Machine tier container
	var item_tier = stolen_def.tier if stolen_def and "tier" in stolen_def else 1
	item_tier = clampi(item_tier, 1, 3)
	var target_tag = StringName("BattleInventoryT%d" % item_tier)
	var target_container = battle_manager.get_container(target_tag)
	if not is_instance_valid(target_container):
		return EffectResult.empty()
		
	var target_slot = target_container.find_first_empty_slot()
	if target_slot == -1:
		return EffectResult.empty()

	# 3. Capture Pre-Unequip Stats
	var pre_stats: Dictionary = battle_manager._capture_all_unit_stats()

	# 4. Move from equipped slot to target Gacha Machine inventory container
	var source_loc = stolen_item.get_location()
	var target_loc = LocationIdentifier.new(target_tag, target_slot)
	var move_res = InventoryOperations.move_instance(battle_manager._state, source_loc, target_loc)
	if not move_res.success:
		return EffectResult.empty()

	# 5. Construct Result with Gacha Machine Arc Animation and Stat Change Events
	var result := EffectResult.new()
	result.state_applied = true

	# Emit SUMMON event targeting BattleInventoryT{tier} for parabolic arc to Gacha Machine
	var item_snapshot := {
		"uuid": stolen_item.ball_uuid,
		"category": "ITEM",
		"icon": stolen_def.icon if stolen_def and "icon" in stolen_def else null,
		"definition_id": stolen_item.definition_id,
		"tier": item_tier
	}
	var summon_payload := CombatPayload.new()
	summon_payload.new_unit_uuid = stolen_item.ball_uuid
	summon_payload.old_unit_location = target_loc
	summon_payload.new_unit_snapshot = item_snapshot
	summon_payload.spawn_source_uuid = target_unit.ball_uuid
	summon_payload.unit_tier = item_tier
	
	var summon_event := CombatEvent.new(CombatEvent.Type.SUMMON, {
		"source_uuid": target_unit.ball_uuid,
		"target_uuids": [stolen_item.ball_uuid],
		"visual_payload": summon_payload
	})
	result.add_event(summon_event)

	# Generate and append unequip stat reduction events
	var stat_data = battle_manager._generate_inventory_stat_events(pre_stats)
	for ev in stat_data.events:
		result.add_event(ev)

	# Log message
	var target_name = BattleHelpers.get_instance_display_name(target_unit)
	var log_text = "Plundered %s from %s to the Tier %d Gacha Machine!" % [item_name, target_name, item_tier]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	return result

# res://scripts/EffectTransferItemBehind.gd
@tool
extends EffectDefinition

## Transfers the equipped item of the dying unit to the ally behind it.
## Used by the Standard Bearer's Standard's Legacy ability.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var target_uuid: String = targets[0]
	var target = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target):
		return EffectResult.empty() if is_simulation else null
		
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty() if is_simulation else null
	
	var equipped_items: Array = context.get("equipped_items", [])
	if equipped_items.is_empty():
		return EffectResult.empty() if is_simulation else null
		
	var item_to_transfer = equipped_items[0]
	var item_uuid: String = item_to_transfer.get("uuid", "")
	if item_uuid.is_empty():
		return EffectResult.empty() if is_simulation else null
		
	var item = battle_manager.get_instance_by_uuid(item_uuid)
	if not is_instance_valid(item):
		return EffectResult.empty() if is_simulation else null

	if is_simulation:
		# Measure stats before transfer so we can capture the exact chronological state
		var old_pwr: int = target.current_pwr
		var old_hp: int = target.current_hp
		
		# Perform the actual equipment transfer silently in the simulated game state
		battle_manager.bm_equip_item(item_uuid, target_uuid, 0, true)
		
		# Measure stats after transfer
		var new_pwr: int = target.current_pwr
		var new_hp: int = target.current_hp
		
		var result := EffectResult.new()
		result.state_applied = true
		
		# Add a nice combat log message event
		var item_def = item.get_definition()
		var item_name = tr(item_def.display_name_key) if item_def else "Item"
		var target_name = BattleHelpers.get_instance_display_name(target)
		var source_name = BattleHelpers.get_instance_display_name(source)
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"visual_payload": {
				"message": tr("ui.transfer_item_msg") % [source_name, item_name, target_name]
			}
		}))
		
		var item_icon_path: String = ""
		if is_instance_valid(item_def) and is_instance_valid(item_def.icon):
			item_icon_path = item_def.icon.resource_path
			
		result.add_event(CombatEvent.new(CombatEvent.Type.ITEM_TRANSFER, {
			"source_uuid": source_uuid,
			"target_uuids": [target_uuid],
			"visual_payload": {
				"item_uuid": item_uuid,
				"item_icon_path": item_icon_path,
				"old_pwr": old_pwr,
				"new_pwr": new_pwr,
				"old_hp": old_hp,
				"new_hp": new_hp
			}
		}))
		
		return result
		
	return null

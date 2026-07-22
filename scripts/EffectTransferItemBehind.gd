# res://scripts/EffectTransferItemBehind.gd
@tool
extends EffectDefinition

## Transfers the equipped item of the dying unit to the ally behind it.
## Used by the Standard Bearer's Standard's Legacy ability.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty()
	
	var target_uuid: String = targets[0]
	var target = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target):
		return EffectResult.empty()
		
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty()
	
	var equipped_items: Array = context.get("equipped_items", [])
	if equipped_items.is_empty():
		return EffectResult.empty()
		
	var item_to_transfer = equipped_items[0]
	var item_uuid: String = item_to_transfer.get("uuid", "")
	if item_uuid.is_empty():
		return EffectResult.empty()
		
	var item = battle_manager.get_instance_by_uuid(item_uuid)
	if not is_instance_valid(item):
		return EffectResult.empty()

	if is_simulation:
		var result := EffectResult.new()
		result.state_applied = true
		var pass_count = self.parameters.get("pass_count", 1)
		
		# Find units behind
		var units_behind: Array[GachaBallInstance] = []
		
		var current_location: LocationIdentifier = context.get("dying_location")
		var is_player_team: bool = context.get("dying_team", "PLAYER") == "PLAYER"
		
		var current_container_tag = current_location.container
		var current_index = current_location.index
		
		if current_index != -1 and not current_container_tag.is_empty():
			for i in range(pass_count):
				var container = battle_manager.get_container(current_container_tag)
				if not is_instance_valid(container):
					break
					
				var behind_index: int
				if is_player_team:
					behind_index = current_index - 1
				else:
					behind_index = current_index + 1
					
				if behind_index < 0 or behind_index >= container.get_size():
					break
					
				var behind_uuid = container.get_uuid(behind_index)
				if behind_uuid.is_empty():
					break
					
				var ally_behind = battle_manager.get_instance_by_uuid(behind_uuid)
				if is_instance_valid(ally_behind) and ally_behind.current_hp > 0:
					units_behind.append(ally_behind)
					current_index = behind_index
				else:
					break
				
		var item_def = item.get_definition()
		var item_icon_path: String = ""
		if is_instance_valid(item_def) and is_instance_valid(item_def.icon):
			item_icon_path = item_def.icon.resource_path
		
		# Now iterate and equip
		for i in range(units_behind.size()):
			var tgt = units_behind[i]
			var tgt_uuid = tgt.ball_uuid
			
			var old_pwr: int = tgt.current_pwr
			var old_hp: int = tgt.current_hp
			
			if i == 0:
				# First unit gets the ACTUAL item transferred
				battle_manager.bm_equip_item(item_uuid, tgt_uuid, 0, true)
			else:
				# Subsequent units get a COPY of the item
				var new_item = GachaBallInstance.new()
				new_item.initialize(item_def)
				battle_manager._state.bm_add_instance(new_item, "", -1)
				battle_manager.bm_equip_item(new_item.ball_uuid, tgt_uuid, 0, true)
			
			var new_pwr: int = tgt.current_pwr
			var new_hp: int = tgt.current_hp
			
			var target_name = BattleHelpers.get_instance_display_name(tgt)
			var source_name = BattleHelpers.get_instance_display_name(source)
			var item_name = tr(item_def.display_name_key) if item_def else "Item"
			
			var message_payload := CombatPayload.new()
			message_payload.message = tr("ui.transfer_item_msg") % [source_name, item_name, target_name]
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"visual_payload": message_payload
			}))
			
			var transfer_payload := CombatPayload.new()
			transfer_payload.item_uuid = item_uuid if i == 0 else ""
			transfer_payload.item_icon_path = item_icon_path
			transfer_payload.old_pwr = old_pwr
			transfer_payload.new_pwr = new_pwr
			transfer_payload.old_hp = old_hp
			transfer_payload.new_hp = new_hp
			result.add_event(CombatEvent.new(CombatEvent.Type.ITEM_TRANSFER, {
				"source_uuid": source_uuid,
				"target_uuids": [tgt_uuid],
				"visual_payload": transfer_payload
			}))
		
		return result
		
	return EffectResult.empty()
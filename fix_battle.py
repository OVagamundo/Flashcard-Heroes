import re

with open('scripts/battle/BattleState.gd', 'r') as f:
    content = f.read()

# I will use a reliable regex replacement to restore the function.
original_func = '''func bm_remove_instance(uuid: String) -> Dictionary:
	var result := {"success": false, "unit_changed_uuid": ""}
	
	assert(not uuid.is_empty(), "bm_remove_instance: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_remove_instance: instance not found for uuid " + uuid)
	var loc := instance.get_location()
	
	# Only attempt to clear from containers if the location is valid
	if is_instance_valid(loc):
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent := get_instance(loc.unit_uuid)
			if not is_instance_valid(parent):
				return result
			if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
				return result
			# Remove bonuses from the parent before clearing the mapping
			parent.unequip_item_bonus(instance)
			parent.equipped_item_uuids[loc.index] = ""
			instance.equipped_on_uuid = ""
			instance.equipped_slot_index = -1
			update_instance_location(instance.ball_uuid, &"", -1)
			result.unit_changed_uuid = parent.ball_uuid
		else:
			# If this is a player unit with equipped items, unequip and move them to inventory
			if instance.equipped_item_uuids.size() > 0:
				if is_player_unit(instance):
					var inv := get_container(BATTLE_CONTAINER_TAGS.PLAYER_BENCH)
					for i in range(instance.equipped_item_uuids.size()):
						var it_uuid := instance.equipped_item_uuids[i]
						if it_uuid.is_empty():
							continue
						var it := get_instance(it_uuid)
						if not is_instance_valid(it):
							continue
						instance.equipped_item_uuids[i] = ""
						it.equipped_on_uuid = ""
						it.equipped_slot_index = -1
						if is_instance_valid(inv):
							var empty := inv.find_first_empty_slot()
							if empty != -1:
								inv.set_uuid(empty, it.ball_uuid)
								update_instance_location(it.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_BENCH, empty)
								result.unit_changed_uuid = instance.ball_uuid
							else:
								push_warning("Inventory full while unequipping item %s" % it.ball_uuid)
				else:
					pass
			
			var c = get_container(loc.container)
			if is_instance_valid(c):
				c.set_uuid(loc.index, "")
				
	# Finally remove it, even if it had no valid container location
	_battle_instances.erase(uuid)
	result.success = true
	return result'''

content = re.sub(r'func bm_remove_instance\(uuid: String\) -> Dictionary:.*?return result', original_func, content, flags=re.DOTALL)

with open('scripts/battle/BattleState.gd', 'w') as f:
    f.write(content)

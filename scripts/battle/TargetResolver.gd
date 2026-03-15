# res://scripts/battle/TargetResolver.gd
class_name TargetResolver
extends RefCounted

## TargetResolver handles target resolution and condition checking for abilities.
## All methods are static and take battle_manager for instance lookups.

const C = preload("res://scripts/Constants.gd")
const BM = preload("res://scripts/BattleManager.gd")

# Use BattleManager.BATTLE_CONTAINER_TAGS for container tag constants

# ============================================================================
# TARGET RESOLUTION
# ============================================================================

## Resolve targets for an ability based on target_type.
## @param source_uuid: String - The UUID of the source instance
## @param target_type: StringName - The type of target to resolve
## @param context: Dictionary - The context of the event
## @param battle_manager: Node - Reference to BattleManager for lookups
## @return Array[String] - Array of target UUIDs
static func resolve_target(source_uuid: String, target_type: StringName, context: Dictionary, battle_manager: Node) -> Array[String]:
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	var is_player_team := false
	
	# Determine team
	if context.has("team"):
		is_player_team = (String(context.get("team")) == "PLAYER")
	elif is_instance_valid(source_instance):
		var src_def = source_instance.get_definition()
		if is_instance_valid(src_def):
			if src_def.category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
				var holder = battle_manager.get_instance_by_uuid(source_instance.equipped_on_uuid)
				if is_instance_valid(holder):
					is_player_team = battle_manager._is_player_unit(holder)
			elif src_def.category == &"TRINKET":
				is_player_team = (source_instance.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
			else:
				is_player_team = battle_manager._is_player_unit(source_instance)
	else:
		return []

	match target_type:
		C.TARGET_SELF:
			return [source_uuid]
		C.TARGET_HOLDER:
			if source_instance.get_definition().category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
				return [source_instance.equipped_on_uuid]
			return [source_uuid]
		C.TARGET_ATTACK_TARGET:
			var target_uuid: String = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
				if is_instance_valid(target_instance) and target_instance.current_hp > 0:
					return [target_uuid]
			return []
		C.TARGET_TRIGGERING_ENTITY:
			var triggering_uuid: String = context.get("triggering_uuid", "")
			if not triggering_uuid.is_empty():
				var triggering_instance = battle_manager.get_instance_by_uuid(triggering_uuid)
				if is_instance_valid(triggering_instance) and triggering_instance.current_hp > 0:
					return [triggering_uuid]
			return []
		C.TARGET_ATTACKER:
			var attacker_uuid: String = context.get("attacker_uuid", "")
			if not attacker_uuid.is_empty():
				var attacker_instance = battle_manager.get_instance_by_uuid(attacker_uuid)
				if is_instance_valid(attacker_instance) and attacker_instance.current_hp > 0:
					return [attacker_uuid]
			return []
		C.TARGET_FRONTMOST_ENEMY:
			var target = battle_manager._get_frontmost_target(is_player_team)
			if is_instance_valid(target):
				return [target.ball_uuid]
			return []
		&"FRONTMOST_ALLY":
			var ally_lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var living_allies = battle_manager.get_instances_in_container(ally_lineup_tag).filter(func(unit): return unit.current_hp > 0)
			if living_allies.is_empty():
				return []
			var best_unit: GachaBallInstance = living_allies[0]
			var best_index: int = battle_manager.get_location_for_uuid(best_unit.ball_uuid).index
			for u in living_allies:
				var idx: int = battle_manager.get_location_for_uuid(u.ball_uuid).index
				if is_player_team:
					if idx > best_index:
						best_unit = u
						best_index = idx
				else:
					if idx < best_index:
						best_unit = u
						best_index = idx
			return [best_unit.ball_uuid]
		C.TARGET_RANDOM_ENEMY:
			var enemies = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).filter(func(u): return u.current_hp > 0)
			if not enemies.is_empty():
				var random_enemy = enemies[randi() % enemies.size()]
				return [random_enemy.ball_uuid]
			return []
		C.TARGET_RANDOM_ALLY:
			var allies = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			if not allies.is_empty():
				var random_ally = allies[randi() % allies.size()]
				return [random_ally.ball_uuid]
			return []
		C.TARGET_ALLY_BEHIND:
			var ally_behind = battle_manager._get_ally_behind(source_instance)
			if is_instance_valid(ally_behind):
				return [ally_behind.ball_uuid]
			return []
		C.TARGET_ALLY_SLOT_AHEAD:
			# Return the victim if they are in the slot directly in front of source
			# This enforces "directly in front" = exactly source_index + 1 (for player)
			# or source_index - 1 (for enemy), with NO empty slots in between
			var victim_uuid = context.get("victim_uuid", "")
			if victim_uuid.is_empty():
				return []
			if not is_instance_valid(source_instance):
				return []
			var source_loc = battle_manager.get_location_for_uuid(source_uuid)
			var victim_loc = battle_manager.get_location_for_uuid(victim_uuid)
			if not is_instance_valid(source_loc) or not is_instance_valid(victim_loc):
				return []
			# Must be in the same container (same lineup)
			if source_loc.container != victim_loc.container:
				return []
			# For player: ahead = higher index (slot index + 1)
			# For enemy: ahead = lower index (slot index - 1)
			if is_player_team:
				if victim_loc.index == source_loc.index + 1:
					return [victim_uuid]
			else:
				if victim_loc.index == source_loc.index - 1:
					return [victim_uuid]
			return []
		C.TARGET_ADJACENT_ALLIES:
			var adjacent = battle_manager._get_adjacent_allies(source_instance)
			var uuids: Array[String] = []
			for ally in adjacent:
				uuids.append(ally.ball_uuid)
			return uuids
		C.TARGET_ALL_ALLIES:
			var allies = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			var uuids: Array[String] = []
			for ally in allies:
				uuids.append(ally.ball_uuid)
			return uuids
		C.TARGET_ALLIES_IN_FRONT:
			# Units with higher slot index (closer to front for player, further for enemy)
			if not is_instance_valid(source_instance):
				return []
			var source_loc = battle_manager.get_location_for_uuid(source_uuid)
			if not is_instance_valid(source_loc):
				return []
			var allies = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			var uuids: Array[String] = []
			for ally in allies:
				if ally.ball_uuid == source_uuid:
					continue # Exclude self
				var ally_loc = battle_manager.get_location_for_uuid(ally.ball_uuid)
				if is_instance_valid(ally_loc) and ally_loc.container == source_loc.container:
					# For player: front = higher index. For enemy: front = lower index
					if is_player_team:
						if ally_loc.index > source_loc.index:
							uuids.append(ally.ball_uuid)
					else:
						if ally_loc.index < source_loc.index:
							uuids.append(ally.ball_uuid)
			return uuids
		C.TARGET_ALLIES_BEHIND:
			# Units with lower slot index (further from front for player, closer for enemy)
			if not is_instance_valid(source_instance):
				return []
			var source_loc = battle_manager.get_location_for_uuid(source_uuid)
			if not is_instance_valid(source_loc):
				return []
			var allies = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			var uuids: Array[String] = []
			for ally in allies:
				if ally.ball_uuid == source_uuid:
					continue # Exclude self
				var ally_loc = battle_manager.get_location_for_uuid(ally.ball_uuid)
				if is_instance_valid(ally_loc) and ally_loc.container == source_loc.container:
					# For player: behind = lower index. For enemy: behind = higher index
					if is_player_team:
						if ally_loc.index < source_loc.index:
							uuids.append(ally.ball_uuid)
					else:
						if ally_loc.index > source_loc.index:
							uuids.append(ally.ball_uuid)
			return uuids
		C.TARGET_HIGHEST_HP_ENEMY:
			var enemies = battle_manager.get_instances_in_container(
				C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			).filter(func(u): return u.current_hp > 0)
			if enemies.is_empty():
				return []
			var highest = enemies[0]
			for enemy in enemies:
				if enemy.current_hp > highest.current_hp:
					highest = enemy
			return [highest.ball_uuid]
		&"MIRROR_SLOT_ENEMY":
			if not is_instance_valid(source_instance): return []
			var source_loc = battle_manager.get_location_for_uuid(source_uuid)
			if not is_instance_valid(source_loc): return []
			
			var enemy_container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			var enemy_container = battle_manager.get_container(enemy_container_tag)
			
			# Calculate Spatially Mirrored Index (Front<->Front, Back<->Back)
			# Player (0..4) vs Enemy (4..0 visually, but 0..4 in memory)
			# "True Mirror" means Index i targets Index (Size-1-i)
			# Example: Player Back (0) targets Enemy Back (4)
			var container_size = enemy_container.get_size()
			var mirror_index = (container_size - 1) - source_loc.index
			var target_uuid = enemy_container.get_uuid(mirror_index)
			
			# Primary Target: Mirror Slot
			if not target_uuid.is_empty():
				var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
				if is_instance_valid(target_instance) and target_instance.current_hp > 0:
					return [target_uuid]
			
			# Fallback: Last Unit in Lineup (Backmost)
			# "Duelist Flavor": If the mirror opponent isn't there, the assassin seeks the
			# next high-value target (Backline) rather than just hitting the tank in front.
			# Player attacking Enemy (Front=0, Back=4): "Last" is Highest Index (4)
			# Enemy attacking Player (Back=0, Front=4): "Last" is Lowest Index (0)
			var all_enemies = battle_manager.get_instances_in_container(enemy_container_tag).filter(func(u): return u.current_hp > 0)
			if all_enemies.is_empty():
				return []
				
			# Sort by index
			all_enemies.sort_custom(func(a, b):
				var loc_a = battle_manager.get_location_for_uuid(a.ball_uuid)
				var loc_b = battle_manager.get_location_for_uuid(b.ball_uuid)
				return loc_a.index < loc_b.index
			)
			
			if is_player_team:
				# Player targets Enemy Back (Highest Index)
				return [all_enemies[-1].ball_uuid]
			else:
				# Enemy targets Player Back (Lowest Index)
				return [all_enemies[0].ball_uuid]
		_:
			return []

# ============================================================================
# CONDITION CHECKING
# ============================================================================

## Check if a condition is met for an ability.
## @param condition_def: ConditionDefinition - The condition to check
## @param source_uuid: String - The UUID of the source instance
## @param context: Dictionary - The context of the event
## @param battle_manager: Node - Reference to BattleManager for lookups
## @return bool - True if condition is met
static func check_condition(condition_def: ConditionDefinition, source_uuid: String, context: Dictionary, battle_manager: Node) -> bool:
	if not is_instance_valid(condition_def):
		return true # No condition means always true
	
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return false
	
	var result := false
	match condition_def.condition_type:
		C.COND_TEAM_SIZE_LESS_THAN_ENEMY:
			var is_source_player = battle_manager._is_player_unit(source_instance)
			var ally_count = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).size()
			var enemy_count = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_source_player else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).size()
			result = ally_count < enemy_count
		C.COND_SLOT_AHEAD_IS_EMPTY:
			var slot_ahead = battle_manager._get_slot_ahead(source_instance)
			result = slot_ahead == null
		C.COND_TARGET_HP_GREATER_THAN_SELF_HP:
			var target_uuid: String = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
				if is_instance_valid(target_instance):
					var self_hp = source_instance.current_hp
					# If source is an ITEM, use the holder's HP for comparison
					if source_instance.get_definition().category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
						var holder = battle_manager.get_instance_by_uuid(source_instance.equipped_on_uuid)
						if is_instance_valid(holder):
							self_hp = holder.current_hp
					result = target_instance.current_hp > self_hp
		C.COND_DAMAGE_WAS_NON_LETHAL:
			var damaged_unit_uuid = context.get("victim_uuid", context.get("source_uuid", ""))
			var damaged_unit = battle_manager.get_instance_by_uuid(damaged_unit_uuid) if not damaged_unit_uuid.is_empty() else source_instance
			result = damaged_unit.current_hp > 0 if is_instance_valid(damaged_unit) else false
		C.COND_DAMAGE_WAS_RECEIVED:
			result = true
		C.COND_IS_TURN_INITIATED_ATTACK:
			result = context.get("is_turn_initiated", false)
		C.COND_COMPOSITE:
			result = true
			if "conditions" in condition_def:
				for sub_condition in condition_def.conditions:
					if not check_condition(sub_condition, source_uuid, context, battle_manager):
						result = false
						break
		C.COND_TRIGGER_CAUSE_MATCH:
			var trigger_cause = context.get("trigger_cause", "")
			var allowed_causes = condition_def.parameters.get("allowed_causes", [])
			if allowed_causes.is_empty():
				result = true
			else:
				result = trigger_cause in allowed_causes
		_:
			result = false
	
	return !result if condition_def.invert_result else result

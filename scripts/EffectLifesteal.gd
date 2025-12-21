# res://scripts/EffectLifesteal.gd
@tool
extends EffectDefinition

## Heals the item holder for a percentage of damage dealt.
## Damage dealt is approximated using the holder's current PWR.
## Used by Lifesteal Ring (T3 Item C) on_attack trigger.
##
## Parameters:
##   percentage: float - Percentage of damage to heal (default 0.2 = 20%)
##   min_heal: int - Minimum heal amount (default 1)

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get parameters
	var percentage: float = float(parameters.get("percentage", 0.2))
	var min_heal: int = int(parameters.get("min_heal", 1))
	
	# Zero-Instance-Query Compliant: Get holder UUID from context
	# For items, BattleManager pre-populates source_holder_uuid
	var holder_uuid: String = context.get("source_holder_uuid", "")
	if holder_uuid.is_empty():
		push_warning("[EffectLifesteal] source_holder_uuid missing from context")
		return EffectResult.empty() if is_simulation else null
	
	# We still need to query holder to check if they're alive and apply healing
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return EffectResult.empty() if is_simulation else null
	
	# Zero-Instance-Query Compliant: Get PWR from context
	# For items, BattleManager pre-populates source_pwr with the holder's PWR
	var damage_dealt: int = context.get("damage_dealt", 0)
	if damage_dealt <= 0:
		damage_dealt = context.get("source_pwr", 0)
		if damage_dealt == 0:
			push_warning("[EffectLifesteal] source_pwr missing from context, heal will use min_heal")
	var heal_amount: int = max(min_heal, int(floor(damage_dealt * percentage)))
	
	if is_simulation:
		# NEW: Return EffectResult with HEAL event
		var result := EffectResult.new()
		
		# Capture old HP for animation
		var old_hp: int = holder.current_hp
		var holder_def = holder.get_definition()
		var max_hp: int = holder_def.base_hp if is_instance_valid(holder_def) else 0
		
		# Apply heal to model
		var new_hp = battle_manager.apply_stat_delta(holder, "hp", heal_amount)
		
		# Get display name for log
		var holder_name: String = BattleHelpers.get_instance_display_name(holder)
		
		# Create log message event
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s heals for %d HP (Lifesteal)" % [holder_name, heal_amount]
		}))
		
		# Create HEAL event
		result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
			"source_uuid": _source_uuid,
			"target_uuids": [holder_uuid],
			"ability_id": context.get("ability_id", &"lifesteal"),
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": holder_uuid,
			"visual_payload": {
				"source_uuid": holder_uuid,
				"amount": heal_amount,
				"stat": "hp",
				"skip_bump": true,
				"targets_old_hp": [old_hp],
				"targets_new_hp": [new_hp],
				"targets_max_hp": [max_hp]
			}
		}))
		
		result.mark_healed(holder_uuid)
		result.state_applied = true # We already called apply_stat_delta
		return result
	else:
		# Apply heal immediately (execution mode - legacy)
		var new_hp = holder.current_hp + heal_amount
		holder.set_current_hp(new_hp)
		return heal_amount

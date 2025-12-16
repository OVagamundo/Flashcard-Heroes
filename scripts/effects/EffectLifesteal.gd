# res://scripts/effects/EffectLifesteal.gd
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
		return null
	
	# We still need to query holder to check if they're alive and apply healing
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return null
	
	# Zero-Instance-Query Compliant: Get PWR from context
	# For items, BattleManager pre-populates source_pwr with the holder's PWR
	var damage_dealt: int = context.get("damage_dealt", 0)
	if damage_dealt <= 0:
		damage_dealt = context.get("source_pwr", 0)
		if damage_dealt == 0:
			push_warning("[EffectLifesteal] source_pwr missing from context, heal will use min_heal")
	var heal_amount: int = max(min_heal, int(floor(damage_dealt * percentage)))
	
	if is_simulation:
		# Return structured data for HEAL event
		# Use same format as EffectModifyStat for HP
		return {
			"stat": "hp",
			"amount": heal_amount,
			"targets": [holder_uuid],
			"animation_source_uuid": holder_uuid
		}
	else:
		# Apply heal immediately (execution mode)
		var new_hp = holder.current_hp + heal_amount
		holder.set_current_hp(new_hp)
		return heal_amount

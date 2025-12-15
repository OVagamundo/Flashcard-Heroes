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

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get parameters
	var percentage: float = float(parameters.get("percentage", 0.2))
	var min_heal: int = int(parameters.get("min_heal", 1))
	
	# Get the source item instance
	var source_item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_item):
		return null
	
	# Get the item holder (the unit wearing the item)
	var holder_uuid: String = source_item.equipped_on_uuid
	if holder_uuid.is_empty():
		return null
	
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return null
	
	# Get actual damage dealt from context (if available from on_damage_dealt trigger)
	# Falls back to holder's PWR for legacy compatibility
	var damage_dealt: int = context.get("damage_dealt", 0)
	if damage_dealt <= 0:
		damage_dealt = holder.current_pwr
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

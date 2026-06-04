# res://scripts/effects/EffectTrinityCharm.gd
@tool
extends EffectDefinition

## Effect for Trinity Charm: Tracks drawn tiers in a turn/encounter. 
## If all 3 tiers are drawn, grants 1 token. Resets on turn end or battle start.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var trinket: GachaBallInstance = battle_manager.get_instance_by_uuid(_source_uuid)
	if not is_instance_valid(trinket):
		return EffectResult.empty()

	var trigger: StringName = context.get("trigger_type", &"")
	var is_simulation: bool = context.get("is_simulation", false)

	if trigger == &"on_draw":
		var tier: int = context.get("tier", 0)
		if tier >= 1 and tier <= 3:
			# Track the tier being drawn
			var key = StringName("trinity_t%d_drawn" % tier)
			trinket.add_status_effect(key, 1)

			var t1 = trinket.status_effects.get(&"trinity_t1_drawn", 0) > 0
			var t2 = trinket.status_effects.get(&"trinity_t2_drawn", 0) > 0
			var t3 = trinket.status_effects.get(&"trinity_t3_drawn", 0) > 0

			if t1 and t2 and t3:
				if trinket.status_effects.get(&"trinity_rewarded_this_cycle", 0) == 0:
					trinket.add_status_effect(&"trinity_rewarded_this_cycle", 1)
					
					if is_simulation:
						battle_manager._state.add_gacha_tokens(1)
						var result := EffectResult.new()
						result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
							"text": "Trinity Charm: Gained 1 token!"
						}))
						result.add_event(CombatEvent.new(CombatEvent.Type.TOKEN_GAIN, {
							"source_uuid": _source_uuid,
							"target_uuids": [_source_uuid],
							"ability_holder_uuid": _source_uuid,
							"ability_id": "ability_trinket_trinity_charm_draw",
							"amount": 1,
							"visual_payload": {
								"amount": 1,
								"origin_uuid": _source_uuid
							}
						}))
						result.state_applied = true
						return result
					else:
						battle_manager.add_gacha_token(1)
						return 1

	elif trigger == &"on_turn_end" or trigger == &"on_battle_start":
		# Reset all tracking
		trinket.status_effects.erase(&"trinity_t1_drawn")
		trinket.status_effects.erase(&"trinity_t2_drawn")
		trinket.status_effects.erase(&"trinity_t3_drawn")
		trinket.status_effects.erase(&"trinity_rewarded_this_cycle")
		
		# Return a valid result so simulation succeeds but does nothing visual
		if is_simulation:
			var result := EffectResult.new()
			result.state_applied = true
			return result
		return true

	return EffectResult.empty()

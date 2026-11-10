# res://scripts/battle/commands/PreKnockoutAttackCommand.gd
class_name PreKnockoutAttackCommand
extends CombatCommand

## Handles EffectResult.pre_knockout_attack_request — suicide attacks like Death's Bargain.
## Applies damage to target, suppresses standard KNOCKOUT event for the attacker,
## and creates a special PRE_KNOCKOUT_ATTACK event.

const C = preload("res://scripts/Constants.gd")

var pre_knockout_attack_request: EffectResult.PreKnockoutAttackRequest

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_pre_knockout_attack_request: EffectResult.PreKnockoutAttackRequest) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	pre_knockout_attack_request = p_pre_knockout_attack_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var damage_amount: int = pre_knockout_attack_request.damage
	var target_uuid: String = pre_knockout_attack_request.target_uuid
	var attacker_uuid: String = pre_knockout_attack_request.source_uuid
	
	var src_inst = battle_manager.get_instance_by_uuid(attacker_uuid)
	var tgt_inst = battle_manager.get_instance_by_uuid(target_uuid)
	
	if not is_instance_valid(src_inst) or not is_instance_valid(tgt_inst):
		return
	
	# Guardian Intercept
	var is_player_source = battle_manager._is_player_unit(src_inst)
	var damage_type = C.DamageType.KAMIKAZE
	var intercept_res = BattleHelpers.resolve_guardian_intercept(
		tgt_inst, damage_amount, damage_type, is_player_source, battle_manager
	)
	if intercept_res.intercepted:
		tgt_inst = intercept_res.interceptor
		target_uuid = tgt_inst.ball_uuid
		CombatCommand.append_unified_events(out_events, intercept_res.events)
	
	var old_hp = tgt_inst.current_hp
	var old_armor = tgt_inst.get_status_effect_amount(&"armor")
	
	# Actually apply the damage
	var dmg_res = battle_manager.apply_damage(tgt_inst, damage_amount, damage_type, "")
	
	var new_hp = tgt_inst.current_hp
	var new_armor = tgt_inst.get_status_effect_amount(&"armor")
	var armor_consumed = dmg_res.get("armor_consumed", 0) if not dmg_res.is_empty() else 0
	
	# Death's Bargain already registered source death in its definition,
	# but we need to ensure the standard KNOCKOUT event is suppressed
	# because the PRE_KNOCKOUT_ATTACK animation includes the unit disappearing.
	death_tracking[attacker_uuid] = true
	
	var payload := CombatPayload.damage(attacker_uuid, damage_amount, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
	payload.attack_type = "kamikaze"
	
	out_events.append(CombatEvent.new(CombatEvent.Type.PRE_KNOCKOUT_ATTACK, {
		"source_uuid": request.source_uuid,
		"target_uuids": [target_uuid],
		"visual_payload": payload
	}))
	
	# Trigger on_hurt (self and ally reactions only; no targeted retaliation against deceased attacker)
	var kamikaze_hurt_scope = combat_sim.begin_reaction_scope()
	battle_manager.trigger_on_hurt(target_uuid, damage_amount, "", C.CAUSE_PRE_KNOCKOUT_ATTACK, &"", false)
	
	var kamikaze_hurt_inline_evts = combat_sim.drain_reaction_scope(kamikaze_hurt_scope, battle_manager)
	CombatCommand.append_unified_events(out_events, kamikaze_hurt_inline_evts)
	
	if new_hp <= 0:
		# Process target death if lethal
		battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)

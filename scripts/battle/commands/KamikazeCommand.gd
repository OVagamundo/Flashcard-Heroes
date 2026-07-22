# res://scripts/battle/commands/KamikazeCommand.gd
class_name KamikazeCommand
extends CombatCommand

## Handles EffectResult.kamikaze_request — suicide attacks like Death's Bargain.
## Applies damage to target, suppresses standard DEATH event for the attacker,
## and creates a special KAMIKAZE_ATTACK event.

const C = preload("res://scripts/Constants.gd")

var kamikaze_request: EffectResult.KamikazeRequest

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node, p_kamikaze_request: EffectResult.KamikazeRequest) -> void:
	super._init(p_request, p_combat_sim, p_bm)
	kamikaze_request = p_kamikaze_request

func execute(out_events: Array[CombatEvent], death_tracking: Dictionary) -> void:
	var damage_amount: int = kamikaze_request.damage
	var target_uuid: String = kamikaze_request.target_uuid
	
	var src_inst = battle_manager.get_instance_by_uuid(request.source_uuid)
	var tgt_inst = battle_manager.get_instance_by_uuid(target_uuid)
	
	if not is_instance_valid(src_inst) or not is_instance_valid(tgt_inst):
		return
	
	var old_hp = tgt_inst.current_hp
	var old_armor = tgt_inst.get_status_effect_amount(&"armor")
	
	# Actually apply the damage
	var damage_type = C.DamageType.MAGIC
	var dmg_res = battle_manager.apply_damage(tgt_inst, damage_amount, damage_type, request.source_uuid)
	
	var new_hp = tgt_inst.current_hp
	var new_armor = tgt_inst.get_status_effect_amount(&"armor")
	var armor_consumed = dmg_res.get("armor_consumed", 0) if not dmg_res.is_empty() else 0
	
	# Death's Bargain already registered source death in its definition,
	# but we need to ensure the standard DEATH event is suppressed
	# because the KAMIKAZE_ATTACK animation includes the unit disappearing.
	death_tracking[request.source_uuid] = true
	
	var payload := CombatPayload.damage(request.source_uuid, damage_amount, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
	payload.attack_type = "kamikaze"
	
	# Add spikes data if any
	if not dmg_res.is_empty() and dmg_res.has("spikes_data"):
		var raw_spikes = dmg_res["spikes_data"]
		var spikes_data := CombatSpikesData.new()
		spikes_data.attacker_uuid = String(raw_spikes.get("attacker_uuid", ""))
		spikes_data.defender_uuid = String(raw_spikes.get("defender_uuid", ""))
		spikes_data.spikes_damage = int(raw_spikes.get("spikes_damage", 0))
		spikes_data.attacker_old_hp = int(raw_spikes.get("attacker_old_hp", 0))
		spikes_data.attacker_new_hp = int(raw_spikes.get("attacker_new_hp", 0))
		spikes_data.attacker_max_hp = int(raw_spikes.get("attacker_max_hp", 0))
		spikes_data.old_spikes = int(raw_spikes.get("old_spikes", 0))
		spikes_data.new_spikes = int(raw_spikes.get("new_spikes", 0))
		spikes_data.armor_consumed = int(raw_spikes.get("armor_consumed", 0))
		spikes_data.new_armor = int(raw_spikes.get("new_armor", 0))
		payload.spikes_data_list = [spikes_data] as Array[CombatSpikesData]
	
	out_events.append(CombatEvent.new(CombatEvent.Type.KAMIKAZE_ATTACK, {
		"source_uuid": request.source_uuid,
		"target_uuids": [target_uuid],
		"visual_payload": payload
	}))
	
	# Trigger on_hurt and on_kill
	var kamikaze_hurt_start = combat_sim._pending_reactions.size()
	battle_manager.trigger_on_hurt(target_uuid, damage_amount, request.source_uuid, C.CAUSE_ABILITY)
	
	combat_sim.drain_reactions_inline(kamikaze_hurt_start, battle_manager)
	var kamikaze_hurt_inline_evts = combat_sim.collect_and_clear_inline_events()
	out_events.append_array(kamikaze_hurt_inline_evts)
	
	if new_hp <= 0:
		battle_manager.trigger_on_kill(request.source_uuid, target_uuid)
	
	battle_manager._check_for_deaths_with_counter_delay(true, out_events, death_tracking)

# res://scripts/battle/commands/CombatCommand.gd
class_name CombatCommand
extends RefCounted

## Abstract base for all combat commands.
## Each command encapsulates one "resolution action" derived from an EffectResult.
## Commands are responsible for:
##   - Generating CombatEvents (VCR serialization)
##   - Queue draining (causality / reaction ordering)
##   - Death checks at the correct logical step

var request: EffectRequest
var combat_sim: CombatSimulator
var battle_manager: Node

func _init(p_request: EffectRequest, p_combat_sim: CombatSimulator, p_bm: Node) -> void:
	request = p_request
	combat_sim = p_combat_sim
	battle_manager = p_bm

## Execute the command. Appends events to out_events.
## @param out_events: Array to append generated CombatEvents to
## @param death_tracking: Dictionary for death deduplication
func execute(_out_events: Array[CombatEvent], _death_tracking: Dictionary) -> void:
	pass # Override in subclasses

## Appends events to out_events, unifying consecutive multi-stat events from the same source.
## This ensures the simulation emits fully-formed multi-stat payloads directly into CombatPayload,
## so presentation/BattleAnimator never has to perform presentation-side event surgery.
static func append_unified_events(out_events: Array[CombatEvent], new_events: Array[CombatEvent]) -> void:
	for ev in new_events:
		if ev == null:
			continue
		
		if ev.type in [CombatEvent.Type.BUFF, CombatEvent.Type.DEBUFF, CombatEvent.Type.HEAL, CombatEvent.Type.STATUS_EFFECT]:
			var merged := false
			# Look backwards in out_events for a matching preceding stat event
			# Skip pure log messages that do not carry trinket activations
			for idx in range(out_events.size() - 1, -1, -1):
				var prev_ev = out_events[idx]
				if prev_ev.type == CombatEvent.Type.LOG_MESSAGE and not prev_ev.trinket_activations.is_empty():
					break
				elif prev_ev.type in [CombatEvent.Type.BUFF, CombatEvent.Type.DEBUFF, CombatEvent.Type.HEAL, CombatEvent.Type.STATUS_EFFECT]:
					if prev_ev.can_merge_with(ev):
						prev_ev.merge_with(ev)
						merged = true
					break
				elif prev_ev.type == CombatEvent.Type.LOG_MESSAGE:
					continue
				else:
					# Other event types (DAMAGE, DEATH, SUMMON, etc.) act as presentation barriers
					break
			
			if not merged:
				out_events.append(ev)
		else:
			out_events.append(ev)


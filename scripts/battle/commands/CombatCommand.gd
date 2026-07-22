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

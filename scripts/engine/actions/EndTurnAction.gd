# res://scripts/engine/actions/EndTurnAction.gd
class_name EndTurnAction
extends GameAction

func _init() -> void:
	super._init(&"EndTurnAction")

func validate() -> bool:
	var bm = GameManager.get_battle_manager()
	if not is_instance_valid(bm):
		return false
	if bm.get_current_phase() != BattleManager.Phases.MANAGEMENT:
		return false
	if bm.has_method("is_animations_playing") and bm.is_animations_playing():
		return false
	return true

func execute() -> void:
	SignalBus.emit_signal("end_turn_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

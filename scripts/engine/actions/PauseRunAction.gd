# res://scripts/engine/actions/PauseRunAction.gd
class_name PauseRunAction
extends GameAction

var is_paused: bool = true

func _init(p_is_paused: bool = true) -> void:
	super._init(&"PauseRunAction")
	is_paused = p_is_paused

func is_meta_action() -> bool:
	return true

func validate() -> bool:
	return true

func execute() -> void:
	if is_paused:
		ActionQueue.pause_timer()
	else:
		ActionQueue.start_timer()

	var tree := Engine.get_main_loop() as SceneTree
	var bv := (tree.get_first_node_in_group("battle_view") as BattleView) if is_instance_valid(tree) else null
	if not is_instance_valid(bv) and is_instance_valid(tree) and is_instance_valid(tree.root):
		bv = tree.root.find_child("Battle", true, false) as BattleView

	if is_instance_valid(bv) and not ActionQueue.is_headless_mode():
		if is_paused:
			bv.execute_pause()
		else:
			bv.execute_speed(AnimationConstants.speed_factor)
	else:
		if is_paused:
			BattleAnimator.pause_combat()
		else:
			BattleAnimator.play_continuous(AnimationConstants.speed_factor)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["is_paused"] = is_paused
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	is_paused = bool(data.get("is_paused", true))

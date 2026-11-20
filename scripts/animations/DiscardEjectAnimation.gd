extends BattleAnimation

const CAPSULE_VIEW: String = "res://scenes/GachaBallView.tscn"

func execute(animator: Node, _targets: Array[String], payload: CombatPayload) -> void:
	var battle: BattleView = animator.get_tree().get_first_node_in_group("battle_view") as BattleView
	if battle == null or battle.discard_pile_button == null:
		return
	var source: Vector2 = battle.discard_pile_button.get_global_rect().get_center()
	var capsule_scene: PackedScene = load(CAPSULE_VIEW)
	var capsule: GachaBallView = capsule_scene.instantiate() as GachaBallView
	var definition: GachaBallDefinition = Database.get_definition(payload.new_unit_snapshot["definition_id"]) as GachaBallDefinition
	assert(definition != null, "Discard ejection requires the original capsule definition")
	var snapshot: Dictionary = payload.new_unit_snapshot.duplicate()
	snapshot["icon"] = definition.icon
	snapshot["category"] = definition.category
	capsule.force_inventory_mode = true
	var layer: CanvasLayer = WindowManager.get_vfx_layer()
	if not layer.is_node_ready():
		await layer.ready
	layer.add_child(capsule)
	capsule.populate(null, snapshot, false)
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.pivot_offset = capsule.get_capsule_rect().get_center()
	var start: Vector2 = source - capsule.pivot_offset
	capsule.global_position = start
	capsule.scale = Vector2.ONE * 0.62
	var animation: Tween = capsule.create_tween().set_parallel()
	var duration: float = AnimationConstants.scaled(0.42)
	animation.tween_method(func(progress: float) -> void:
		capsule.global_position = start + Vector2(210.0 * progress, 290.0 * progress * progress - 160.0 * progress)
	, 0.0, 1.0, duration)
	animation.tween_property(capsule, "rotation", 1.2, duration)
	animation.tween_property(capsule, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	await animation.finished
	capsule.queue_free()

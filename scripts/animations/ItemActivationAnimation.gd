class_name ItemActivationAnimation
extends BattleAnimation

const ItemPopupScene = preload("res://scenes/vfx/ItemPopup.tscn")

func execute(animator: Node, _targets: Array[String], payload: CombatPayload) -> void:
	var source_uuid = payload.source_uuid
	var item_name = payload.item_name
	# var icon_path = String(payload.get("icon_path", "")) 
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# DECOUPLING FIX: Use position snapshot instead of visual_registry
	var src_snap = animator.get_snapshot_position(source_uuid)
	if src_snap.is_empty():
		return
		
	var spawn_pos = Vector2(src_snap.position.x + src_snap.size.x / 2, src_snap.position.y)
	
	var popup = ItemPopupScene.instantiate()
	var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
	if is_instance_valid(battle_view):
		popup.position = spawn_pos
		battle_view.add_child(popup)
		popup.setup(item_name) # Add icon texture if available
		popup.play()
		
		await popup.animation_finished
	else:
		popup.queue_free()

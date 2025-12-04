class_name ItemActivationAnimation
extends BattleAnimation

const ItemPopupScene = preload("res://scenes/vfx/ItemPopup.tscn")

func execute(animator: Node, _targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var item_name = String(payload.get("item_name", "Item"))
	# var icon_path = String(payload.get("icon_path", "")) 
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	var visual_registry = animator._visual_registry
	if not visual_registry.has(source_uuid):
		return
		
	var source_view = visual_registry[source_uuid]
	if not is_instance_valid(source_view):
		return
		
	var rect = source_view.get_global_rect()
	var spawn_pos = Vector2(rect.position.x + rect.size.x / 2, rect.position.y)
	
	var popup = ItemPopupScene.instantiate()
	var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
	if is_instance_valid(battle_view):
		battle_view.add_child(popup)
		popup.position = spawn_pos
		popup.setup(item_name) # Add icon texture if available
		popup.play()
		
		await popup.animation_finished
	else:
		popup.queue_free()

# scripts/vfx/VFXFactory.gd
extends Node

## VFXFactory - Centralized VFX scene preloading and instantiation.
## Registered as autoload singleton to ensure scenes are loaded once.
## Provides factory methods for creating VFX nodes with proper layer placement.

# Preloaded VFX scenes
const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")
const FloatingDamageNumberScene = preload("res://scenes/vfx/FloatingDamageNumber.tscn")
const ItemPopupScene = preload("res://scenes/vfx/ItemPopup.tscn")

# -----------------------------------------------------------------------------
# FACTORY METHODS
# -----------------------------------------------------------------------------

## Create a stat projectile (damage/heal/buff)
func create_projectile() -> Node:
	return StatProjectileScene.instantiate()

## Create a floating damage number
func create_damage_number() -> Node:
	return FloatingDamageNumberScene.instantiate()

## Create an item activation popup
func create_item_popup() -> Node:
	return ItemPopupScene.instantiate()

# -----------------------------------------------------------------------------
# HELPER METHODS
# -----------------------------------------------------------------------------

## Get the effects layer for rendering VFX above the battle view
func get_effects_layer() -> Node:
	return get_tree().get_first_node_in_group("effects_layer")

## Calculate viewport offset for correct VFX positioning
## Returns Vector2.ZERO if no offset needed
func get_viewport_offset() -> Vector2:
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	if is_instance_valid(battle_view):
		var viewport = battle_view.get_viewport()
		if viewport and viewport.get_parent() is Control:
			return viewport.get_parent().global_position
	return Vector2.ZERO

## Spawn a projectile on the effects layer with proper positioning
## Returns the projectile node (caller must call setup() and launch())
func spawn_projectile_on_layer(amount: int, stat: String, start_pos: Vector2, end_pos: Vector2, is_self_cast: bool) -> Node:
	var projectile = create_projectile()
	var effects_layer = get_effects_layer()
	
	if is_instance_valid(effects_layer):
		var offset = get_viewport_offset()
		effects_layer.add_child(projectile)
		projectile.setup(amount, stat, start_pos + offset, end_pos + offset, is_self_cast)
		return projectile
	else:
		# Fallback to battle view
		var battle_view = get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(projectile)
			projectile.setup(amount, stat, start_pos, end_pos, is_self_cast)
			return projectile
		else:
			projectile.queue_free()
			return null

## Spawn a floating damage number on the effects layer with proper positioning
func spawn_damage_number_on_layer(amount: int, spawn_pos: Vector2, is_armor: bool = false) -> void:
	var damage_number = create_damage_number()
	var effects_layer = get_effects_layer()
	
	if is_instance_valid(effects_layer):
		var offset = get_viewport_offset()
		effects_layer.add_child(damage_number)
		if is_armor:
			damage_number.setup_armor(amount, spawn_pos + offset)
		else:
			damage_number.setup(amount, spawn_pos + offset)
		damage_number.play()
	else:
		# Fallback to battle view
		var battle_view = get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(damage_number)
			if is_armor:
				damage_number.setup_armor(amount, spawn_pos)
			else:
				damage_number.setup(amount, spawn_pos)
			damage_number.play()
		else:
			damage_number.queue_free()

## Launch a projectile from source to target using animator position snapshots.
## Handles position resolution, self-cast detection, and projectile spawning.
## Returns the projectile node for awaiting impact, or null if positions invalid.
func launch_projectile_between(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String) -> Node:
	# Get target position from animator snapshot
	var tgt_snap = animator.get_snapshot_position(target_uuid)
	if tgt_snap.is_empty():
		return null
	
	# Get source position (optional - may be self-cast)
	var start_pos = Vector2.ZERO
	var is_source_valid = false
	var src_snap = animator.get_snapshot_position(source_uuid)
	if not src_snap.is_empty():
		start_pos = Vector2(src_snap.position.x + src_snap.size.x / 2, src_snap.position.y)
		is_source_valid = true
	
	# Calculate end position
	var end_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y)
	
	# Detect self-cast (no valid source or source == target)
	var is_self_cast = (not is_source_valid) or (source_uuid == target_uuid)
	var launch_pos = end_pos if is_self_cast else start_pos
	
	# Spawn and launch projectile
	var projectile = spawn_projectile_on_layer(amount, stat, launch_pos, end_pos, is_self_cast)
	if projectile:
		projectile.launch()
	return projectile

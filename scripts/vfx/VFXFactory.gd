# scripts/vfx/VFXFactory.gd
extends Node

## VFXFactory - Centralized VFX scene preloading and instantiation.
## Registered as autoload singleton to ensure scenes are loaded once.
## Provides factory methods for creating VFX nodes with proper layer placement.

# Preloaded VFX scenes
const CannonballProjectileScene = preload("res://scenes/vfx/CannonballProjectile.tscn")
const BuffNumberProjectileScene = preload("res://scenes/vfx/BuffNumberProjectile.tscn")
const FloatingDamageNumberScene = preload("res://scenes/vfx/FloatingDamageNumber.tscn")
const ItemPopupScene = preload("res://scenes/vfx/ItemPopup.tscn")

# -----------------------------------------------------------------------------
# FACTORY METHODS
# -----------------------------------------------------------------------------

## Create a stat projectile (damage/heal/buff)
func create_projectile(is_attack_projectile: bool = false) -> Node:
	if is_attack_projectile:
		return CannonballProjectileScene.instantiate()
	return BuffNumberProjectileScene.instantiate()

## Create a floating damage number
func create_damage_number() -> Node:
	return FloatingDamageNumberScene.instantiate()

## Create an item activation popup
func create_item_popup() -> Node:
	return ItemPopupScene.instantiate()

# -----------------------------------------------------------------------------
# HELPER METHODS
# -----------------------------------------------------------------------------

## Get the effects layer for rendering VFX above all content and UI
func get_effects_layer() -> Node:
	if WindowManager.has_method("get_vfx_layer"):
		return WindowManager.get_vfx_layer()
	var vfx_layer = get_tree().get_first_node_in_group("vfx_layer")
	if is_instance_valid(vfx_layer): return vfx_layer
	return get_tree().get_first_node_in_group("effects_layer")

## Calculate viewport offset for correct VFX positioning
## Returns Vector2.ZERO if no offset needed (e.g. layer is in same viewport as content)
func get_viewport_offset() -> Vector2:
	var effects_layer = get_effects_layer()
	if not is_instance_valid(effects_layer):
		return Vector2.ZERO
		
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree():
		var battle_viewport = battle_view.get_viewport()
		var effects_viewport = effects_layer.get_viewport()
		
		# If they are in different viewports (e.g. EffectsLayer is on root, Battle is in SubViewport)
		# we need to compensate for the SubViewportContainer's position.
		if battle_viewport != effects_viewport:
			if battle_viewport and battle_viewport.get_parent() is Control:
				return battle_viewport.get_parent().global_position
				
	return Vector2.ZERO

## Spawn a projectile on the effects layer with proper positioning
## Returns the projectile node (caller must call setup() and launch())
func spawn_projectile_on_layer(amount: int, stat: String, start_pos: Vector2, end_pos: Vector2, is_self_cast: bool, is_attack_projectile: bool = false) -> Node:
	var projectile = create_projectile(is_attack_projectile)
	var effects_layer = get_effects_layer()
	
	if is_instance_valid(effects_layer):
		var offset = get_viewport_offset()
		projectile.position = start_pos + offset
		
		# Ensure it's on top of all other items in the same layer
		if projectile is CanvasItem:
			projectile.z_index = 100 
			
		effects_layer.add_child(projectile)
		projectile.setup(amount, stat, start_pos + offset, end_pos + offset, is_self_cast)
		return projectile
	else:
		push_warning("[VFXFactory] No global effects layer found, falling back to battle view")
		# Fallback to battle view
		var battle_view = get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			projectile.position = start_pos
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
		damage_number.position = spawn_pos + offset
		
		# Ensure it's on top of all other items in the same layer
		if damage_number is CanvasItem:
			damage_number.z_index = 100
			
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
			damage_number.position = spawn_pos
			battle_view.add_child(damage_number)
			if is_armor:
				damage_number.setup_armor(amount, spawn_pos)
			else:
				damage_number.setup(amount, spawn_pos)
			damage_number.play()
		else:
			damage_number.queue_free()

## Spawn a floating status effect number (Burn, Spikes, Armor) on the effects layer
func spawn_status_effect_number_on_layer(amount: int, type: String, spawn_pos: Vector2) -> void:
	var vfx = create_damage_number() # Reusing the same scene
	var effects_layer = get_effects_layer()
	
	if is_instance_valid(effects_layer):
		var offset = get_viewport_offset()
		vfx.position = spawn_pos + offset
		if vfx is CanvasItem:
			vfx.z_index = 100
		effects_layer.add_child(vfx)
		vfx.setup_status_effect(amount, type, spawn_pos + offset)
		vfx.play()
	else:
		push_warning("[VFXFactory] No global effects layer found for status number")
		# Fallback to battle view
		var battle_view = get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			vfx.position = spawn_pos
			battle_view.add_child(vfx)
			vfx.setup_status_effect(amount, type, spawn_pos)
			vfx.play()
		else:
			vfx.queue_free()

## Spawn a floating stat number (size 32) on the effects layer
func spawn_stat_number_on_layer(amount: int, spawn_pos: Vector2, color: Color = Color.WHITE) -> void:
	var vfx = create_damage_number()
	var effects_layer = get_effects_layer()
	
	if is_instance_valid(effects_layer):
		var offset = get_viewport_offset()
		vfx.position = spawn_pos + offset
		if vfx is CanvasItem:
			vfx.z_index = 100
		effects_layer.add_child(vfx)
		vfx.setup_stat(amount, spawn_pos + offset, color)
		vfx.play()
	else:
		push_warning("[VFXFactory] No global effects layer found for stat number")
		var battle_view = get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			vfx.position = spawn_pos
			battle_view.add_child(vfx)
			vfx.setup_stat(amount, spawn_pos, color)
			vfx.play()
		else:
			vfx.queue_free()

## Launch a projectile from source to target using animator position snapshots.
## Handles position resolution, self-cast detection, and projectile spawning.
## Returns the projectile node for awaiting impact, or null if positions invalid.
func launch_projectile_between(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, is_attack_projectile: bool = false, custom_duration: float = 0.0) -> Node:
	# Get target position from animator live view (fallback to snapshot)
	var tgt_snap = animator.get_live_position(target_uuid) if animator.has_method("get_live_position") else animator.get_snapshot_position(target_uuid)
	if tgt_snap.is_empty():
		return null
	
	# Get source position (optional - may be self-cast)
	var start_pos = Vector2.ZERO
	var is_source_valid = false
	if not source_uuid.is_empty():
		var src_snap = animator.get_live_position(source_uuid) if animator.has_method("get_live_position") else animator.get_snapshot_position(source_uuid)
		# No defensive code! If a source was specified, its visual must exist.
		assert(not src_snap.is_empty(), "CRITICAL: Missing valid source view in snapshot for uuid: " + source_uuid)
		start_pos = Vector2(src_snap.position.x + src_snap.size.x / 2, src_snap.position.y)
		is_source_valid = true
	
	# Calculate end position
	var end_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y)
	
	# Detect self-cast (no source or source == target)
	var is_self_cast = (not is_source_valid) or (source_uuid == target_uuid)
	var launch_pos = end_pos if is_self_cast else start_pos
	
	# Spawn and launch projectile with uniform duration
	var projectile = spawn_projectile_on_layer(amount, stat, launch_pos, end_pos, is_self_cast, is_attack_projectile)
	if projectile:
		var duration = custom_duration if custom_duration > 0.0 else AnimationConstants.scaled(0.6)
		projectile.launch(duration)
	return projectile

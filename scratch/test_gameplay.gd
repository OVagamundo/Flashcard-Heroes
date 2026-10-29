extends Node

func _ready():
	print("--- Running Shadow & Platform Position Tests in Scene ---")
	
	# Verify Constants
	assert(C.SLOT_SIZE_2X == 188, "SLOT_SIZE_2X must be 188")
	assert(C.SLOT_UNIT_OFFSET_Y == 5, "SLOT_UNIT_OFFSET_Y must be 5")
	assert(C.SHADOW_WIDTH_2X == 128, "SHADOW_WIDTH_2X must be 128")
	assert(C.SHADOW_HEIGHT_2X == 10, "SHADOW_HEIGHT_2X must be 10")
	assert(C.SHADOW_OFFSET_Y == 128, "SHADOW_OFFSET_Y must be 128")
	assert(C.SHADOW_ALPHA == 0.5, "SHADOW_ALPHA must be 0.5")
	
	# Platform surface middle is 55px from bottom: 188 - 55 = 133
	var expected_ground_y = 188 - 55
	assert(C.SLOT_UNIT_OFFSET_Y + C.UNIT_SPRITE_SIZE == expected_ground_y, "Unit base must sit at 133px (55px from bottom)")
	assert(C.SHADOW_OFFSET_Y + C.SHADOW_HEIGHT_2X / 2 == expected_ground_y, "Shadow vertical center must sit at 133px")
	
	print("Constants verification passed!")
	
	# Instantiate SlotView (which uses ArtStyleManager, SignalBus, etc.)
	var slot_scene = load("res://scenes/SlotView.tscn")
	var slot = slot_scene.instantiate()
	add_child(slot)
	slot.custom_minimum_size = Vector2(188, 188)
	slot.size = Vector2(188, 188)
	slot.global_position = Vector2(100, 342) # Typical lineup slot Y
	slot.set_size_scale(2.0)
	
	var loc = LocationIdentifier.new()
	loc.container = &"PlayerLineup"
	loc.index = 0
	slot.populate(loc)
	
	var test_icon = load("res://assets/Realistic/sprites/units/hero01.png")
	var visual_data = {
		"category": "UNIT",
		"definition_id": "test_unit",
		"icon": test_icon,
		"hp": 10,
		"pwr": 5
	}
	var view = slot.set_content(visual_data, true, false)
	assert(view != null, "GachaBallView instantiated")
	
	var icon_rect = view.icon_rect
	assert(icon_rect != null, "Icon rect exists")
	
	var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
	assert(unit_sprite != null, "UnitSprite exists")
	assert(unit_sprite.position == Vector2(30, 5), "UnitSprite position must be (30, 5), was: %s" % str(unit_sprite.position))
	assert(unit_sprite.size == Vector2(128, 128), "UnitSprite size must be (128, 128), was: %s" % str(unit_sprite.size))
	
	var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
	assert(shadow_sprite != null, "ShadowSprite exists")
	assert(shadow_sprite.position == Vector2(30, 128), "ShadowSprite position must be (30, 128), was: %s" % str(shadow_sprite.position))
	assert(shadow_sprite.size == Vector2(128, 10), "ShadowSprite size must be (128, 10), was: %s" % str(shadow_sprite.size))
	assert(is_equal_approx(shadow_sprite.modulate.a, 0.5), "ShadowSprite alpha must be 0.5, was: %f" % shadow_sprite.modulate.a)
	assert(shadow_sprite.get_index() < unit_sprite.get_index(), "ShadowSprite must be behind UnitSprite in z-order")
	
	print("Unit sprite and shadow positioning and z-order passed!")
	
	# Test item on PlayerBench
	var item_loc = LocationIdentifier.new()
	item_loc.container = &"PlayerBench"
	item_loc.index = 0
	slot.populate(item_loc)
	
	var item_icon = load("res://assets/Realistic/sprites/items/InterestLedger.png")
	var item_visual_data = {
		"category": "ITEM",
		"definition_id": "test_item",
		"icon": item_icon
	}
	var item_view = slot.set_content(item_visual_data, true, false)
	assert(item_view != null, "Item GachaBallView instantiated")
	
	var item_icon_rect = item_view.icon_rect
	var item_sprite = item_icon_rect.get_node_or_null("UnitSprite")
	var item_shadow = item_icon_rect.get_node_or_null("ShadowSprite")
	assert(item_sprite != null, "Item UnitSprite exists")
	assert(item_shadow != null, "Item ShadowSprite exists")
	assert(item_sprite.position == Vector2(30, 5), "Item sprite position must be (30, 5)")
	assert(item_shadow.position == Vector2(30, 128), "Item shadow position must be (30, 128)")
	assert(item_shadow.get_index() < item_sprite.get_index(), "Item shadow behind item sprite in z-order")
	
	print("Item on bench sprite and shadow passed!")
	
	# Test tracking behavior via UnitAnimationController
	var anim_ctrl = view.get_node_or_null("AnimationController")
	assert(anim_ctrl != null, "AnimationController exists")
	
	# Simulate unit at rest
	anim_ctrl._update_shadow(shadow_sprite)
	assert(shadow_sprite.position.y == 128, "At rest, shadow.position.y must be 128")
	assert(shadow_sprite.scale.x == 1.0, "At rest, shadow.scale.x must be 1.0")
	assert(is_equal_approx(shadow_sprite.modulate.a, 0.5), "At rest, shadow.modulate.a must be 0.5")
	
	# Simulate unit jumping 60px into the air
	view.global_position.y -= 60
	anim_ctrl._update_shadow(shadow_sprite)
	assert(shadow_sprite.position.y == 128 + 60, "When 60px in air, shadow.position.y must stay on ground (128+60=188), was %f" % shadow_sprite.position.y)
	assert(shadow_sprite.scale.x < 1.0, "When in air, shadow.scale.x must shrink, got: %f" % shadow_sprite.scale.x)
	assert(shadow_sprite.modulate.a < 0.5, "When in air, shadow.modulate.a must fade, got: %f" % shadow_sprite.modulate.a)
	
	print("Shadow height tracking, grounded position, shrinking, and fading passed!")
	
	print("--- All Tests Passed Successfully! ---")
	get_tree().quit(0)

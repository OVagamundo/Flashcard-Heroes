# res://scripts/CurrencyAnimator.gd
class_name CurrencyAnimator
extends RefCounted

## Centralized, unified presentation service for all currency animations (Gold and Tokens).
##
## Guarantees consistent visual and audio behaviors across all game contexts:
## - SPENDING: Decrements and pops the HUD counter immediately as coins/tokens launch from it.
## - GAINING: Increments and pops the HUD counter only as each coin/token arrives and is absorbed.
## - Callbacks allow individual scenes to preserve contextual reactions (e.g. Machine bounce).

const GoldCoinVFXScene = preload("res://scripts/vfx/GoldCoinVFX.gd")
const TokenSpendVFXScene = preload("res://scenes/vfx/TokenSpendVFX.tscn")
const TokenPopVFXScene = preload("res://scenes/vfx/TokenPopVFX.tscn")

# ==============================================================================
# HUD POSITION HELPERS
# ==============================================================================

static func get_hud_gold_center() -> Vector2:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	if not is_instance_valid(main_node):
		return Vector2.ZERO
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group):
		return Vector2.ZERO
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	var target = gold_icon if is_instance_valid(gold_icon) else gold_group
	return target.get_global_rect().get_center()

static func get_hud_token_center() -> Vector2:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	if not is_instance_valid(main_node):
		return Vector2.ZERO
	var token_group = main_node.get_node_or_null("%TokenGroup")
	if not is_instance_valid(token_group):
		return Vector2.ZERO
	var token_icon = token_group.get_node_or_null("TokenIcon")
	var target = token_icon if is_instance_valid(token_icon) else token_group
	return target.get_global_rect().get_center()

# ==============================================================================
# GOLD ANIMATIONS
# ==============================================================================

## Animate spending gold from HUD counter to a target location in the scene.
## Decrements and pops the HUD gold counter immediately upon launch.
static func animate_gold_spend(
	amount: int,
	target_pos: Vector2,
	on_complete: Callable = Callable()
) -> void:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	var start_pos = get_hud_gold_center()
	
	assert(is_instance_valid(main_node), "animate_gold_spend: active_main_node is null")
	assert(start_pos != Vector2.ZERO, "animate_gold_spend: HUD gold center is ZERO")
	
	main_node.begin_gold_animation()
	
	# Visually deduct gold from HUD counter at the exact moment coins start flying
	main_node.modify_visual_gold(-amount, true)
	
	var coins_to_spawn = mini(amount, 5)
	var stagger_delay = 0.08
	var vfx_layer = WindowManager.get_vfx_layer()
	
	var last_coin = null
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		last_coin = coin_vfx
		vfx_layer.add_child(coin_vfx)
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
		)
		var offset = Vector2(
			RNGManager.cosmetic_rng.randf_range(-15, 15),
			RNGManager.cosmetic_rng.randf_range(-8, 8)
		)
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
	
	if is_instance_valid(last_coin):
		await last_coin.coin_landed
	
	if on_complete.is_valid():
		on_complete.call()
	
	main_node.end_gold_animation()

## Animate earning/receiving gold flying into the HUD counter.
## Only increments and pops the HUD gold counter as each coin lands and is absorbed.
static func animate_gold_gain(
	amount: int,
	start_pos: Vector2,
	on_complete: Callable = Callable()
) -> void:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	var target_pos = get_hud_gold_center()
	
	assert(is_instance_valid(main_node), "animate_gold_gain: active_main_node is null")
	assert(target_pos != Vector2.ZERO, "animate_gold_gain: HUD gold center is ZERO")
	
	main_node.begin_gold_animation()
	
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	var coins_to_spawn = mini(amount, 5)
	var stagger_delay = 0.08
	var coins_landed = 0
	var vfx_layer = WindowManager.get_vfx_layer()
	var last_coin = null
	
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScene.new()
		last_coin = coin_vfx
		vfx_layer.add_child(coin_vfx)
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			coins_landed += 1
			Audio.play_sfx("coin_land")
			if is_instance_valid(gold_group):
				var tween = gold_group.create_tween()
				gold_group.pivot_offset = gold_group.size / 2.0
				tween.tween_property(gold_group, "scale", Vector2(1.2, 1.2), 0.05)
				tween.tween_property(gold_group, "scale", Vector2(1.0, 1.0), 0.1)
			var prev_chunk = int(round(float(amount) * (float(coins_landed - 1) / float(coins_to_spawn))))
			var curr_chunk = int(round(float(amount) * (float(coins_landed) / float(coins_to_spawn))))
			main_node.modify_visual_gold(curr_chunk - prev_chunk, false)
		)
		var offset = Vector2(
			RNGManager.cosmetic_rng.randf_range(-15, 15),
			RNGManager.cosmetic_rng.randf_range(-8, 8)
		)
		coin_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
	
	if is_instance_valid(last_coin):
		await last_coin.coin_landed
	
	if on_complete.is_valid():
		on_complete.call()
	
	main_node.end_gold_animation()

# ==============================================================================
# TOKEN ANIMATIONS
# ==============================================================================

## Animate spending tokens from HUD counter to a target location in the scene.
## Decrements and pops the HUD token counter immediately upon launch.
static func animate_token_spend(
	amount: int,
	target_pos: Vector2,
	on_token_landed: Callable = Callable(),
	on_complete: Callable = Callable()
) -> void:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	var start_pos = get_hud_token_center()
	
	assert(is_instance_valid(main_node), "animate_token_spend: active_main_node is null")
	assert(start_pos != Vector2.ZERO, "animate_token_spend: HUD token center is ZERO")
	
	main_node.begin_token_animation()
	
	# Visually deduct tokens from HUD counter at the exact moment tokens start flying
	main_node.modify_visual_tokens(-amount, true)
	
	var tokens_to_spawn = amount
	var stagger_delay = AnimationConstants.scaled(0.12)
	var vfx_layer = WindowManager.get_vfx_layer()
	var last_vfx = null
	
	for i in range(tokens_to_spawn):
		var token_vfx = TokenSpendVFXScene.instantiate()
		last_vfx = token_vfx
		vfx_layer.add_child(token_vfx)
		
		token_vfx.coin_landed.connect(func(land_pos: Vector2):
			Audio.play_sfx("token_land")
			if on_token_landed.is_valid():
				on_token_landed.call(land_pos)
		)
		
		Audio.play_sfx("token_spend", 1.0 + (i * 0.05))
		var offset = Vector2(
			RNGManager.cosmetic_rng.randf_range(-20, 20),
			RNGManager.cosmetic_rng.randf_range(-10, 10)
		)
		token_vfx.play(start_pos + offset, target_pos, i * stagger_delay)
	
	if is_instance_valid(last_vfx):
		await last_vfx.coin_landed
	
	if on_complete.is_valid():
		on_complete.call()
	
	main_node.end_token_animation()

## Animate earning/receiving tokens flying into the HUD counter.
## Only increments and pops the HUD token counter as each token lands and is absorbed.
static func animate_token_gain(
	amount: int,
	start_pos: Vector2,
	on_complete: Callable = Callable(),
	streak: int = 0
) -> void:
	var main_node = GameManager._active_main_node if is_instance_valid(GameManager) else null
	var target_pos = get_hud_token_center()
	
	assert(is_instance_valid(main_node), "animate_token_gain: active_main_node is null")
	assert(target_pos != Vector2.ZERO, "animate_token_gain: HUD token center is ZERO")
	
	main_node.begin_token_animation()
	
	var token_group = main_node.get_node_or_null("%TokenGroup")
	var vfx_layer = WindowManager.get_vfx_layer()
	var tokens_to_spawn = mini(amount, 5)
	var stagger_delay = 0.1
	var tokens_landed = 0
	var last_vfx: TokenPopVFX = null
	
	for i in range(tokens_to_spawn):
		var token_vfx = TokenPopVFXScene.instantiate()
		last_vfx = token_vfx
		vfx_layer.add_child(token_vfx)
		token_vfx.global_position = start_pos
		
		token_vfx.animation_finished.connect(func():
			tokens_landed += 1
			Audio.play_sfx("token_land")
			if is_instance_valid(token_group):
				var tween = token_group.create_tween()
				token_group.pivot_offset = token_group.size / 2.0
				tween.tween_property(token_group, "scale", Vector2(1.2, 1.2), 0.05)
				tween.tween_property(token_group, "scale", Vector2(1.0, 1.0), 0.1)
			var prev_chunk = int(round(float(amount) * (float(tokens_landed - 1) / float(tokens_to_spawn))))
			var curr_chunk = int(round(float(amount) * (float(tokens_landed) / float(tokens_to_spawn))))
			main_node.modify_visual_tokens(curr_chunk - prev_chunk, false)
		)
		
		token_vfx.play(target_pos, streak)
		if i < tokens_to_spawn - 1:
			var tree_temp = Engine.get_main_loop() as SceneTree
			if is_instance_valid(tree_temp):
				await AnimationConstants.create_pausable_timer(tree_temp, stagger_delay).timeout
	
	if is_instance_valid(last_vfx):
		await last_vfx.animation_finished
	
	if on_complete.is_valid():
		on_complete.call()
	
	main_node.end_token_animation()

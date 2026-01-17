class_name AnimationRegistry
extends RefCounted

static var _animations: Dictionary = {}

static func register(id: String, animation: BattleAnimation) -> void:
	_animations[id] = animation

static func get_animation(id: String) -> BattleAnimation:
	if _animations.has(id):
		return _animations[id]
	return null

# Helper to auto-load standard animations (could be called by BattleAnimator._ready)
static func load_standard_animations() -> void:
	# We will register concrete animations here as we create them
	var projectile_anim_script = load("res://scripts/animations/ProjectileAnimation.gd")
	register("projectile", projectile_anim_script.new())
	
	var damage_anim_script = load("res://scripts/animations/DamageAnimation.gd")
	register("damage", damage_anim_script.new())
	
	var heal_anim_script = load("res://scripts/animations/HealAnimation.gd")
	register("heal", heal_anim_script.new())
	
	var buff_anim_script = load("res://scripts/animations/BuffAnimation.gd")
	register("buff", buff_anim_script.new())
	
	var item_anim_script = load("res://scripts/animations/ItemActivationAnimation.gd")
	register("item_activation", item_anim_script.new())
	
	var death_anim_script = load("res://scripts/animations/DeathAnimation.gd")
	register("death", death_anim_script.new())
	
	var summon_anim_script = load("res://scripts/animations/SummonAnimation.gd")
	register("summon", summon_anim_script.new())
	
	var guardian_anim_script = load("res://scripts/animations/GuardianInterceptAnimation.gd")
	register("guardian_intercept", guardian_anim_script.new())
	
	var lethal_save_anim_script = load("res://scripts/animations/LethalSaveAnimation.gd")
	register("lethal_save", lethal_save_anim_script.new())
	
	var status_effect_anim_script = load("res://scripts/animations/StatusEffectAnimation.gd")
	register("status_effect", status_effect_anim_script.new())
	
	var kamikaze_anim_script = load("res://scripts/animations/KamikazeAnimation.gd")
	register("kamikaze", kamikaze_anim_script.new())
	
	if OS.is_debug_build():
		print("[AnimationRegistry] Loaded animations: ", _animations.keys())

class_name AnimationRegistry
extends RefCounted

static var _animations: Dictionary = {}

static func register(id: String, animation: BattleAnimation) -> void:
	_animations[id] = animation

static func get_animation(id: String) -> BattleAnimation:
	if _animations.has(id):
		return _animations[id]
	return null

# Helper to auto-load standard animations (called by BattleAnimator._ready)
static func load_standard_animations() -> void:
	var damage_anim_script: GDScript = load("res://scripts/animations/DamageAnimation.gd")
	register("damage", damage_anim_script.new())

	var heal_anim_script: GDScript = load("res://scripts/animations/HealAnimation.gd")
	register("heal", heal_anim_script.new())

	var buff_anim_script: GDScript = load("res://scripts/animations/BuffAnimation.gd")
	register("buff", buff_anim_script.new())

	var guardian_anim_script: GDScript = load("res://scripts/animations/GuardianInterceptAnimation.gd")
	register("guardian_intercept", guardian_anim_script.new())

	var lethal_save_anim_script: GDScript = load("res://scripts/animations/LethalSaveAnimation.gd")
	register("lethal_save", lethal_save_anim_script.new())

	var combat_effect_anim_script: GDScript = load("res://scripts/animations/CombatEffectAnimation.gd")
	register("status_effect", combat_effect_anim_script.new())

	var kamikaze_anim_script: GDScript = load("res://scripts/animations/KamikazeAnimation.gd")
	register("kamikaze", kamikaze_anim_script.new())

	var transform_anim_script: GDScript = load("res://scripts/animations/TransformAnimation.gd")
	register("transform", transform_anim_script.new())

	var discard_eject_script: GDScript = load("res://scripts/animations/DiscardEjectAnimation.gd")
	register("discard_eject", discard_eject_script.new())

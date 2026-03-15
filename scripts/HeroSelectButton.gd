# res://scripts/HeroSelectButton.gd
class_name HeroSelectButton
extends Control

const InputUtils = preload("res://scripts/InputUtils.gd")

## Clickable hero sprite button for the loadout scene.
## Displays hero at 2x scale with shader outline selection feedback (like battle lineup).

signal hero_selected(hero_def: GachaBallDefinition)

const SPRITE_SIZE: int = 128 # 2x scale of 64px base

@onready var hero_sprite: TextureRect = %HeroSprite
@onready var lock_overlay: ColorRect = %LockOverlay

var _hero_def: GachaBallDefinition
var _is_selected: bool = false
var _is_locked: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	lock_overlay.visible = false
	
	# Ensure sprite has shader material for outline
	_setup_shader_material()


func _setup_shader_material() -> void:
	# Load and apply the outline shader
	var shader = load("res://assets/shaders/sprite_outline.gdshader")
	if shader and is_instance_valid(hero_sprite):
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		shader_mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
		shader_mat.set_shader_parameter("outline_width", 3.0)
		shader_mat.set_shader_parameter("outline_enabled", false)
		hero_sprite.material = shader_mat


func populate(hero_def: GachaBallDefinition, is_locked: bool = false) -> void:
	_hero_def = hero_def
	_is_locked = is_locked
	
	if hero_def.icon:
		hero_sprite.texture = hero_def.icon
	
	# Apply locked state
	if _is_locked:
		lock_overlay.visible = true
		# Grayscale effect
		hero_sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		lock_overlay.visible = false
		hero_sprite.modulate = Color.WHITE


func set_selected(selected: bool) -> void:
	_is_selected = selected
	
	# Toggle shader outline
	var mat = hero_sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_enabled", selected)
	
	if selected and not _is_locked:
		_play_selection_bounce()


func _play_selection_bounce() -> void:
	if not is_instance_valid(hero_sprite): return
	
	# AUDIO HOOK: Play selection sound
	Audio.play_sfx("ui_select")
	
	hero_sprite.pivot_offset = hero_sprite.size / 2.0
	var original_scale := hero_sprite.scale
	
	var tween := create_tween()
	tween.tween_property(hero_sprite, "scale", Vector2(1.15, 0.85), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hero_sprite, "scale", Vector2(0.9, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hero_sprite, "scale", Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hero_sprite, "scale", original_scale, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if _is_locked:
		return
	
	if InputUtils.is_primary_pointer_press(event):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_click")
		hero_selected.emit(_hero_def)


func get_hero_def() -> GachaBallDefinition:
	return _hero_def

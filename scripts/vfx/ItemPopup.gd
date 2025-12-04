class_name ItemPopup
extends Node2D

signal animation_finished

@onready var icon: Sprite2D = $Icon
@onready var label: Label = $Label

func setup(text: String, icon_texture: Texture2D = null, color: Color = Color.WHITE) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	if icon_texture:
		icon.texture = icon_texture
	else:
		icon.visible = false
	
	scale = Vector2.ZERO
	modulate.a = 0.0

func play() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pop up and scale
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_property(self, "position:y", position.y - 80, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Hover briefly
	tween.chain().tween_interval(0.5)
	
	# Fade out and move up further
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(self, "position:y", position.y - 120, 0.3)
	
	await tween.finished
	animation_finished.emit()
	queue_free()

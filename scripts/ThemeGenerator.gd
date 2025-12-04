@tool
extends SceneTree

func _init():
	var theme = Theme.new()
	
	# Load Fonts
	var font_regular = load("res://assets/fonts/static/NotoSansJP-Regular.ttf")
	var font_bold = load("res://assets/fonts/static/NotoSansJP-Bold.ttf")
	
	# Default Font
	theme.default_font = font_regular
	theme.default_font_size = 32
	
	# Label
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", font_bold)
	theme.set_font_size("font_size", "HeaderLabel", 48)
	
	theme.set_type_variation("StatLabel", "Label")
	theme.set_font("font", "StatLabel", font_bold)
	theme.set_font_size("font_size", "StatLabel", 32)
	theme.set_constant("outline_size", "StatLabel", 4)
	theme.set_color("font_outline_color", "StatLabel", Color.BLACK)
	
	# Button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("2c3e50") # Dark Blue
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.content_margin_left = 16
	style_normal.content_margin_right = 16
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("34495e") # Lighter
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color("1abc9c") # Greenish
	
	theme.set_stylebox("normal", "Button", style_normal)
	theme.set_stylebox("hover", "Button", style_hover)
	theme.set_stylebox("pressed", "Button", style_pressed)
	theme.set_font("font", "Button", font_bold)
	
	# PanelContainer (Minimalist)
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_panel.border_width_left = 2
	style_panel.border_width_top = 2
	style_panel.border_width_right = 2
	style_panel.border_width_bottom = 2
	style_panel.border_color = Color(0.3, 0.3, 0.3)
	style_panel.corner_radius_top_left = 8
	style_panel.corner_radius_top_right = 8
	style_panel.corner_radius_bottom_right = 8
	style_panel.corner_radius_bottom_left = 8
	
	theme.set_stylebox("panel", "PanelContainer", style_panel)
	
	# Save
	var err = ResourceSaver.save(theme, "res://resources/GameTheme.tres")
	if err == OK:
		print("Theme saved successfully to res://resources/GameTheme.tres")
	else:
		print("Failed to save theme: ", err)
	
	quit()

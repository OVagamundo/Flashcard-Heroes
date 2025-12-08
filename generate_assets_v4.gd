@tool
extends SceneTree

# Palette: "Antique RPG" (Desaturated, Cohesive)
# Wood
const C_WOOD_BASE = Color("5d4037")
const C_WOOD_SHADOW = Color("3e2723")
const C_WOOD_LIGHT = Color("8d6e63")
const C_WOOD_GRAIN = Color("4e342e") # For texture

# Parchment
const C_PAPER_BASE = Color("d7ccc8")
const C_PAPER_SHADOW = Color("a1887f")
const C_PAPER_NOISE = Color("bcaaa4")

# Gold / Brass
const C_GOLD_BASE = Color("ffb300")
const C_GOLD_SHADOW = Color("c6a700")
const C_GOLD_LIGHT = Color("ffca28")

# Bars
const C_RED_BASE = Color("c62828")
const C_RED_DARK = Color("8e0000")
const C_BLUE_BASE = Color("1565c0")
const C_BLUE_DARK = Color("003c8f")

# Input
const C_INPUT_BG = Color("2d2420") # Very dark wood

func _init():
	print("Starting V4 Asset Generation (High Fidelity)...")
	var path = "res://assets/ui/textures/"
	var dir = DirAccess.open(path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(path)

	# 1. Main Panel (Chamfered Wood Frame + Parchment Body)
	generate_panel_v4("panel_v4.png")

	# 2. Buttons (Chamfered Inputs)
	generate_button_v4("button_v4_normal.png", C_WOOD_BASE, C_GOLD_SHADOW)
	generate_button_v4("button_v4_hover.png", C_WOOD_LIGHT, C_GOLD_BASE)
	generate_button_v4("button_v4_pressed.png", C_WOOD_SHADOW, C_GOLD_SHADOW, true)
	generate_button_v4("button_v4_disabled.png", Color("555555"), Color("333333"))

	# 3. Sliders
	generate_track_v4("slider_v4_track.png")
	generate_grabber_v4("slider_v4_grabber.png")

	# 4. Progress Bars
	generate_bar_frame_v4("bar_v4_bg.png")
	generate_bar_fill_v4("bar_v4_health.png", C_RED_BASE, C_RED_DARK)
	generate_bar_fill_v4("bar_v4_power.png", C_BLUE_BASE, C_BLUE_DARK)

	# 5. Input
	generate_input_v4("input_v4.png")

	# 6. Tabs
	generate_tab_v4("tab_v4_active.png", C_WOOD_BASE)
	generate_tab_v4("tab_v4_inactive.png", C_WOOD_SHADOW)

	# 7. Checkbox
	generate_chk_v4("checkbox_v4_checked.png", true)
	generate_chk_v4("checkbox_v4_unchecked.png", false)

	print("V4 Asset Generation Complete.")
	quit()

# --- Core Generators ---

func generate_panel_v4(filename):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# 1. Draw Chamfered Frame
	draw_chamfered_rect(img, 0, 0, w, h, C_WOOD_BASE)
	
	# 2. Add Wood Grain Texture to Frame
	apply_noise(img, C_WOOD_GRAIN, 0.15)
	
	# 3. Inner Parchment Area (Inset 4px)
	draw_chamfered_rect(img, 4, 4, w - 8, h - 8, C_PAPER_BASE)
	# Parchment noise
	apply_noise_region(img, 4, 4, w - 8, h - 8, C_PAPER_NOISE, 0.1)

	# 4. Bevel Lighting on Frame
	draw_chamfered_bevel(img, 0, 0, w, h, C_WOOD_LIGHT, C_WOOD_SHADOW)
	
	# 5. Inner Shadow on Parchment
	draw_inner_shadow(img, 4, 4, w - 8, h - 8, C_PAPER_SHADOW)

	# 6. Gold Corner Brackets
	draw_corner_bracket(img, 0, 0) # TL
	draw_corner_bracket(img, w - 4, 0) # TR
	draw_corner_bracket(img, 0, h - 4) # BL
	draw_corner_bracket(img, w - 4, h - 4) # BR

	save_image(img, filename)

func generate_button_v4(filename, base_col, border_col, pressed = false):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Chamfered Body
	draw_chamfered_rect(img, 0, 0, w, h, base_col)
	
	# Texture matches wood usually
	if base_col == C_WOOD_BASE or base_col == C_WOOD_LIGHT or base_col == C_WOOD_SHADOW:
		apply_noise(img, base_col.darkened(0.2), 0.1)

	# Border
	draw_chamfered_outline(img, 0, 0, w, h, border_col)
	
	# Bevel
	if pressed:
		# Inset look: Dark top/left, Light bottom/right
		draw_chamfered_bevel(img, 0, 0, w, h, base_col.darkened(0.3), base_col.lightened(0.1))
	else:
		# Pop look: Light top/left, Dark bottom/right
		draw_chamfered_bevel(img, 0, 0, w, h, base_col.lightened(0.2), base_col.darkened(0.3))

	save_image(img, filename)

func generate_track_v4(filename):
	var w = 32; var h = 10
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Dark recessed track
	draw_chamfered_rect(img, 0, 2, w, 6, C_INPUT_BG)
	draw_chamfered_outline(img, 0, 2, w, 6, C_WOOD_SHADOW)
	save_image(img, filename)

func generate_grabber_v4(filename):
	var w = 14; var h = 18
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Gold block
	draw_chamfered_rect(img, 1, 1, w - 2, h - 2, C_GOLD_BASE)
	draw_chamfered_bevel(img, 1, 1, w - 2, h - 2, C_GOLD_LIGHT, C_GOLD_SHADOW)
	draw_chamfered_outline(img, 1, 1, w - 2, h - 2, C_WOOD_SHADOW) # Dark outline
	
	# Grip lines
	img.set_pixel(w / 2, h / 2 - 2, C_GOLD_SHADOW)
	img.set_pixel(w / 2, h / 2, C_GOLD_SHADOW)
	img.set_pixel(w / 2, h / 2 + 2, C_GOLD_SHADOW)
	
	save_image(img, filename)

func generate_bar_frame_v4(filename):
	var w = 32; var h = 12
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	draw_chamfered_rect(img, 0, 0, w, h, C_INPUT_BG)
	draw_chamfered_outline(img, 0, 0, w, h, C_WOOD_LIGHT)
	save_image(img, filename)

func generate_bar_fill_v4(filename, col_base, col_dark):
	var w = 32; var h = 12
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Fill with inset
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if y < h / 2: img.set_pixel(x, y, col_base)
			else: img.set_pixel(x, y, col_dark)
			
	# Shine
	for x in range(2, w - 2):
		img.set_pixel(x, 2, col_base.lightened(0.4))
		
	save_image(img, filename)

func generate_input_v4(filename):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	draw_chamfered_rect(img, 0, 0, w, h, C_INPUT_BG)
	draw_chamfered_outline(img, 0, 0, w, h, C_WOOD_SHADOW)
	# Inner shadow
	draw_inner_shadow(img, 1, 1, w - 2, h - 2, Color(0, 0, 0, 0.5))
	
	save_image(img, filename)

func generate_tab_v4(filename, col):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Chamfered top only
	for x in range(w):
		for y in range(h):
			if (x < 3 and y < 3) or (x > w - 4 and y < 3): continue # Chamfer top corners
			if x == 0 or x == w - 1 or y == 0: # Border
				img.set_pixel(x, y, C_WOOD_SHADOW)
			else:
				img.set_pixel(x, y, col)
	
	# Highlight top
	for x in range(1, w - 1):
		if img.get_pixel(x, 1) == col: img.set_pixel(x, 1, C_WOOD_LIGHT)
		
	save_image(img, filename)

func generate_chk_v4(filename, checked):
	var w = 24; var h = 24
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	draw_chamfered_rect(img, 0, 0, w, h, C_INPUT_BG)
	draw_chamfered_outline(img, 0, 0, w, h, C_GOLD_BASE)
	
	if checked:
		# Gold Check
		for i in range(4, 20):
			img.set_pixel(i, i, C_GOLD_LIGHT)
			img.set_pixel(i, 23 - i, C_GOLD_LIGHT)
			
	save_image(img, filename)

# --- Drawing Primitives ---

func draw_chamfered_rect(img, x, y, w, h, col):
	for i in range(w):
		for j in range(h):
			if is_corner(i, j, w, h): continue
			img.set_pixel(x + i, y + j, col)

func draw_chamfered_outline(img, x, y, w, h, col):
	for i in range(w):
		for j in range(h):
			if is_corner(i, j, w, h): continue
			# If border pixel
			if is_border(i, j, w, h):
				img.set_pixel(x + i, y + j, col)

func draw_chamfered_bevel(img, x, y, w, h, col_light, col_dark):
	# Top/Left lines
	for i in range(1, w - 1):
		if not is_corner(i, 0, w, h): img.set_pixel(x + i, y, col_light)
	for j in range(1, h - 1):
		if not is_corner(0, j, w, h): img.set_pixel(x, y + j, col_light)
		
	# Bottom/Right lines
	for i in range(1, w - 1):
		if not is_corner(i, h - 1, w, h): img.set_pixel(x + i, y + h - 1, col_dark)
	for j in range(1, h - 1):
		if not is_corner(w - 1, j, w, h): img.set_pixel(x + w - 1, y + j, col_dark)

func draw_inner_shadow(img, x, y, w, h, col):
	for i in range(w): img.set_pixel(x + i, y, col)
	for j in range(h): img.set_pixel(x, y + j, col)

func draw_corner_bracket(img, x, y):
	# 4x4 gold L-shape
	img.set_pixel(x + 0, y + 0, C_WOOD_SHADOW) # Dark anchor
	img.set_pixel(x + 1, y + 0, C_GOLD_BASE)
	img.set_pixel(x + 2, y + 0, C_GOLD_BASE)
	img.set_pixel(x + 0, y + 1, C_GOLD_BASE)
	img.set_pixel(x + 0, y + 2, C_GOLD_BASE)
	img.set_pixel(x + 1, y + 1, C_GOLD_LIGHT)

func apply_noise(img, col, factor):
	# Horizontal streaks for wood
	var w = img.get_width()
	var h = img.get_height()
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	for j in range(h):
		if rng.randf() < 0.3: # 30% chance of grain line
			for i in range(w):
				if img.get_pixel(i, j).a > 0:
					var c = img.get_pixel(i, j)
					img.set_pixel(i, j, c.lerp(col, factor))
		else:
			# Random pixel noise
			for i in range(w):
				if img.get_pixel(i, j).a > 0 and rng.randf() < 0.05:
					var c = img.get_pixel(i, j)
					img.set_pixel(i, j, c.lerp(col, factor))

func apply_noise_region(img, x, y, w, h, col, factor):
	var rng = RandomNumberGenerator.new()
	for i in range(w):
		for j in range(h):
			if rng.randf() < 0.2:
				var c = img.get_pixel(x + i, y + j)
				img.set_pixel(x + i, y + j, c.lerp(col, factor))

func is_corner(x, y, w, h) -> bool:
	# Chamfer size 3
	var c = 3
	if (x + y < c): return true # TL
	if ((w - 1 - x) + y < c): return true # TR
	if (x + (h - 1 - y) < c): return true # BL
	if ((w - 1 - x) + (h - 1 - y) < c): return true # BR
	return false

func is_border(x, y, w, h) -> bool:
	if x == 0 or y == 0 or x == w - 1 or y == h - 1: return true
	# Also check chamfer diagonal edges
	# This is basic, for advanced we would check diagonals too but rect outline covers most
	return false

func save_image(img: Image, filename: String):
	var path = "res://assets/ui/textures/" + filename
	img.save_png(path)
	print("Generated: " + path)
